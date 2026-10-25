// main.cpp – CopilotButton C++ motoru giriş noktası
// Konsol penceresi açılmaz (-mwindows / SUBSYSTEM:WINDOWS)
// requireAdministrator yetkisi app.manifest ile zorunlu tutulur.

#include <windows.h>
#include <objbase.h>
#include <string>
#include <tlhelp32.h>

#include "Config.hpp"
#include "KeyHook.hpp"
#include "Audio.hpp"
#include "Actions.hpp"
#include "MicOverlay.hpp"
#include "SpotifyTracker.hpp"
#include "Osd.hpp"
#include "Tray.hpp"
#include "WebViewSettings.hpp"
#include "AppRegister.hpp"

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "comdlg32.lib")
#pragma comment(lib, "advapi32.lib")

// ─────────────────────────────────────────────
//  Özel mesajlar (Thread-safe UI bildirimleri)
// ─────────────────────────────────────────────
static constexpr UINT WM_USER_MIC_STATE_CHANGED = WM_USER + 101;
static constexpr UINT WM_USER_TRACK_CHANGED     = WM_USER + 102;

static MicOverlay*     g_pMicOverlay     = nullptr;
static SpotifyTracker* g_pSpotifyTracker = nullptr;
static ConfigManager*  g_pCfgMgr         = nullptr;
static TrayManager*    g_pTray           = nullptr;
static UINT            g_uTaskbarRestart = 0;

static LRESULT CALLBACK HostWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == g_uTaskbarRestart && g_pTray) {
        g_pTray->Reinstall();
        return 0;
    }

    switch (msg) {
        case WM_USER_TRAY_ICON:
            if (g_pTray) {
                g_pTray->HandleMessage(lParam);
            }
            return 0;

        case WM_USER_MIC_STATE_CHANGED:
            if (g_pMicOverlay) {
                g_pMicOverlay->SetMuted(wParam != 0);
            }
            return 0;

        case WM_USER_TRACK_CHANGED:
            if (g_pSpotifyTracker && g_pCfgMgr) {
                Config cfg = g_pCfgMgr->GetConfig();
                OsdManager::Instance().UpdateConfig(cfg);
                if (cfg.spotifyTrackOsd) {
                    TrackInfo track = g_pSpotifyTracker->GetCurrentTrack();
                    if (track.isPlaying && !track.title.empty()) {
                        OsdManager::Instance().ShowSpotifyTrack(track.title, track.artist);
                    }
                }
            }
            return 0;

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        default:
            break;
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

// ─────────────────────────────────────────────
//  Eski veya askıda kalan CopilotButton örneklerini sonlandır
// ─────────────────────────────────────────────
static void TerminateOldInstances() {
    DWORD currentPid = GetCurrentProcessId();
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;

    PROCESSENTRY32W entry = {};
    entry.dwSize = sizeof(entry);

    if (Process32FirstW(snap, &entry)) {
        do {
            if (_wcsicmp(entry.szExeFile, L"CopilotButton.exe") == 0 &&
                entry.th32ProcessID != currentPid) {
                HANDLE hProc = OpenProcess(PROCESS_TERMINATE, FALSE, entry.th32ProcessID);
                if (hProc) {
                    TerminateProcess(hProc, 0);
                    CloseHandle(hProc);
                }
            }
        } while (Process32NextW(snap, &entry));
    }
    CloseHandle(snap);
}

// ─────────────────────────────────────────────
//  Tek örnek mutex (çift çalışmayı engelle)
// ─────────────────────────────────────────────
static HANDLE g_mutex = nullptr;

static bool EnsureSingleInstance() {
    TerminateOldInstances();
    Sleep(50);
    g_mutex = CreateMutexW(nullptr, TRUE,
                           L"Global\\CopilotButton_Engine_v2");
    return (GetLastError() != ERROR_ALREADY_EXISTS);
}

// ─────────────────────────────────────────────
//  Config.ini yolu: exe ile aynı dizinde veya bir üst dizinde ara
// ─────────────────────────────────────────────
static std::wstring GetIniPath() {
    wchar_t exePath[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);

    wchar_t* last = wcsrchr(exePath, L'\\');
    if (last) *last = L'\0'; // Exe dizini

    std::wstring directPath = std::wstring(exePath) + L"\\config.ini";
    if (GetFileAttributesW(directPath.c_str()) != INVALID_FILE_ATTRIBUTES) {
        return directPath;
    }

    // Bir üst dizini kontrol et (örneğin exe engine\ veya build\ altındaysa)
    wchar_t* prev = wcsrchr(exePath, L'\\');
    if (prev) *prev = L'\0';
    std::wstring parentPath = std::wstring(exePath) + L"\\config.ini";
    if (GetFileAttributesW(parentPath.c_str()) != INVALID_FILE_ATTRIBUTES) {
        return parentPath;
    }

    // Dosya hiçbir yerde yoksa doğrudan exe dizininde varsayılan ayarlarla oluştur
    EnsureConfigExists(directPath);
    return directPath;
}

// ─────────────────────────────────────────────
//  WinMain – mesaj penceresi + mesaj döngüsü
// ─────────────────────────────────────────────
int WINAPI WinMain(HINSTANCE hInst, HINSTANCE, LPSTR, int) {
    // ── Kendi kendini %LOCALAPPDATA%\CopilotButton klasörüne taşıma / güncelleme denetimi ──
    if (CheckAndPerformSelfRelocate()) {
        return 0; // Taşındı ve kalıcı konumdaki exe başlatıldı; geçici örneği kapat
    }

    // Eğer --delete-source ile başlatıldıysak eski geçici dosyayı temizle
    CleanupOldSourceIfRequested();

    if (!EnsureSingleInstance()) return 1;

    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

    // ── Uygulamayı Windows'a resmi uygulama olarak tanıt (AUMID + Kısayol + Registry) ──
    RegisterAppWithWindows();

    // ── Config yükle + hot-reload başlat ──────────────────────────────
    ConfigManager cfgMgr(GetIniPath());
    cfgMgr.Start();
    g_pCfgMgr = &cfgMgr;

    g_uTaskbarRestart = RegisterWindowMessageW(L"TaskbarCreated");

    // ── Gizli mesaj ve bildirim penceresi ─────────────────────────────
    WNDCLASSEXW wc     = {};
    wc.cbSize          = sizeof(wc);
    wc.hInstance       = hInst;
    wc.lpfnWndProc     = HostWndProc;
    wc.lpszClassName   = L"CopilotButtonHost";
    RegisterClassExW(&wc);

    HWND hWnd = CreateWindowExW(0, L"CopilotButtonHost", L"CopilotButtonHost",
                                WS_POPUP, 0, 0, 0, 0,
                                nullptr, nullptr, hInst, nullptr);

    // ── Sistem Tepsisi (Tray Icon) ───────────────────────────────────
    TrayManager tray;
    g_pTray = &tray;
    tray.Install(
        hWnd,
        []() {
            WebViewSettingsWindow::Instance().Open(GetIniPath());
        },
        [hWnd]() {
            PostMessageW(hWnd, WM_CLOSE, 0, 0);
        }
    );

    // ── OSD Yöneticisi başlat ────────────────────────────────────────
    OsdManager::Instance().Init(hWnd);
    OsdManager::Instance().UpdateConfig(cfgMgr.GetConfig());

    // ── Kalıcı Mikrofon Rozeti ────────────────────────────────────────
    MicOverlay micOverlay;
    g_pMicOverlay = &micOverlay;
    micOverlay.Create();

    // Başlangıç mikrofon durumunu senkronize et
    bool initialMicMute = GetMicMuteState();
    micOverlay.SetMuted(initialMicMute);

    // ── Harici Mikrofon Senkronizasyonu (Core Audio Callback) ─────────
    RegisterMicNotification([hWnd](bool isMuted) {
        PostMessageW(hWnd, WM_USER_MIC_STATE_CHANGED, isMuted ? 1 : 0, 0);
    });

    // ── Spotify Şarkı Takibi ──────────────────────────────────────────
    SpotifyTracker spotifyTracker;
    g_pSpotifyTracker = &spotifyTracker;
    spotifyTracker.Start([hWnd](const TrackInfo& track) {
        // Şarkı değişti! Ana pencereye bildir
        PostMessageW(hWnd, WM_USER_TRACK_CHANGED, 0, 0);
    });

    // ── Keyboard hook – HWND mesaj penceresiyle kur ───────────────────
    KeyHook hook;
    {
        Config cfg = cfgMgr.GetConfig();
        hook.UpdateConfig(cfg);
    }

    bool installed = hook.Install(
        [&](Action act) {
            Config cfg = cfgMgr.GetConfig();
            hook.UpdateConfig(cfg);
            OsdManager::Instance().UpdateConfig(cfg);
            DispatchAction(act, cfg.customAppPath, cfg.soundFxEnabled);

            // Mikrofon eylemi sonrasında durumu rozette hemen güncelle
            bool m = GetMicMuteState();
            PostMessageW(hWnd, WM_USER_MIC_STATE_CHANGED, m ? 1 : 0, 0);
        },
        hWnd
    );

    if (!installed) {
        tray.Uninstall();
        g_pTray = nullptr;
        WebViewSettingsWindow::Instance().Close();
        spotifyTracker.Stop();
        g_pSpotifyTracker = nullptr;
        UnregisterMicNotification();
        micOverlay.Destroy();
        g_pMicOverlay = nullptr;
        OsdManager::Instance().Destroy();
        CoUninitialize();
        return 2;
    }

    // ── Mesaj döngüsü ─────────────────────────────────────────────────
    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    hook.Uninstall();
    tray.Uninstall();
    g_pTray = nullptr;
    WebViewSettingsWindow::Instance().Close();
    spotifyTracker.Stop();
    g_pSpotifyTracker = nullptr;
    UnregisterMicNotification();
    micOverlay.Destroy();
    g_pMicOverlay = nullptr;
    OsdManager::Instance().Destroy();

    CoUninitialize();
    if (g_mutex) CloseHandle(g_mutex);
    return 0;
}
