// main.cpp – CopilotButton C++ arka plan motoru (Headless Engine Daemon)
// Konsol penceresi açılmaz (-mwindows / SUBSYSTEM:WINDOWS)
// requireAdministrator yetkisi app.manifest ile sağlanır.

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

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "advapi32.lib")

// ─────────────────────────────────────────────
//  Özel mesajlar (Thread-safe dahili bildirimler)
// ─────────────────────────────────────────────
static constexpr UINT WM_USER_MIC_STATE_CHANGED = WM_USER + 101;
static constexpr UINT WM_USER_TRACK_CHANGED     = WM_USER + 102;
static constexpr UINT WM_USER_CONFIG_CHANGED    = WM_USER + 103;

static const wchar_t* ENGINE_WND_CLASS   = L"CopilotButtonEngineHost";
static const wchar_t* ENGINE_MUTEX_NAME  = L"Global\\CopilotButton_Engine_v2";
static const wchar_t* ENGINE_STOP_EVENT = L"Global\\CopilotButton_Engine_Stop_Event";

static MicOverlay*     g_pMicOverlay     = nullptr;
static SpotifyTracker* g_pSpotifyTracker = nullptr;
static ConfigManager*  g_pCfgMgr         = nullptr;
static KeyHook*        g_pHook           = nullptr;
static HWND            g_hWnd            = nullptr;

static LRESULT CALLBACK HostWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
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

        case WM_USER_CONFIG_CHANGED:
            if (g_pCfgMgr) {
                Config cfg = g_pCfgMgr->GetConfig();
                if (g_pHook) {
                    g_pHook->UpdateConfig(cfg);
                }
                OsdManager::Instance().UpdateConfig(cfg);
            }
            return 0;

        case WM_CLOSE:
            DestroyWindow(hwnd);
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
//  Eski veya askıda kalan CopilotButtonEngine örneklerini sonlandır
// ─────────────────────────────────────────────
static void TerminateOldEngineInstances() {
    DWORD currentPid = GetCurrentProcessId();
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;

    PROCESSENTRY32W entry = {};
    entry.dwSize = sizeof(entry);

    if (Process32FirstW(snap, &entry)) {
        do {
            if (_wcsicmp(entry.szExeFile, L"CopilotButtonEngine.exe") == 0 &&
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
static HANDLE g_hEngineMutex = nullptr;

static bool EnsureSingleEngineInstance() {
    TerminateOldEngineInstances();
    Sleep(50);
    g_hEngineMutex = CreateMutexW(nullptr, TRUE, ENGINE_MUTEX_NAME);
    return (GetLastError() != ERROR_ALREADY_EXISTS);
}

// ─────────────────────────────────────────────
//  WinMain – Motor giriş noktası
// ─────────────────────────────────────────────
int WINAPI WinMain(HINSTANCE hInst, HINSTANCE, LPSTR, int) {
    if (!EnsureSingleEngineInstance()) return 1;

    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

    // ── Gizli bildirim ve mesaj penceresi ─────────────────────────────
    WNDCLASSEXW wc     = {};
    wc.cbSize          = sizeof(wc);
    wc.hInstance       = hInst;
    wc.lpfnWndProc     = HostWndProc;
    wc.lpszClassName   = ENGINE_WND_CLASS;
    RegisterClassExW(&wc);

    HWND hWnd = CreateWindowExW(0, ENGINE_WND_CLASS, ENGINE_WND_CLASS,
                                WS_POPUP, 0, 0, 0, 0,
                                nullptr, nullptr, hInst, nullptr);
    // Düşük yetkili süreçlerin de WM_CLOSE iletebilmesi için UIPI filtresini aç
    ChangeWindowMessageFilter(WM_CLOSE, MSGFLT_ADD);

    // ── GUI'den gelen kapatma sinyali (Global Stop Event) ─────────────
    SECURITY_DESCRIPTOR sd = {};
    InitializeSecurityDescriptor(&sd, SECURITY_DESCRIPTOR_REVISION);
    SetSecurityDescriptorDacl(&sd, TRUE, nullptr, FALSE);
    SECURITY_ATTRIBUTES sa = { sizeof(sa), &sd, FALSE };

    HANDLE hStopEvent = CreateEventW(&sa, TRUE, FALSE, ENGINE_STOP_EVENT);
    ResetEvent(hStopEvent);

    HANDLE hStopWaitThread = CreateThread(nullptr, 0, [](LPVOID param) -> DWORD {
        HWND hTargetWnd = reinterpret_cast<HWND>(param);
        HANDLE hEvt = OpenEventW(SYNCHRONIZE, FALSE, ENGINE_STOP_EVENT);
        if (hEvt) {
            WaitForSingleObject(hEvt, INFINITE);
            CloseHandle(hEvt);
            if (hTargetWnd && IsWindow(hTargetWnd)) {
                PostMessageW(hTargetWnd, WM_CLOSE, 0, 0);
            }
        }
        return 0;
    }, hWnd, 0, nullptr);

    // ── Config yükle + INI dosyasındaki değişiklikleri dinamik izle ───
    // INI dosyasında değişiklik algılandığında onChange callback'i tetiklenir
    // ve pencereye WM_USER_CONFIG_CHANGED mesajı gönderilerek ayarlar anında yenilenir.
    ConfigManager cfgMgr(GetIniPath(), [hWnd](const Config&) {
        if (hWnd && IsWindow(hWnd)) {
            PostMessageW(hWnd, WM_USER_CONFIG_CHANGED, 0, 0);
        }
    });
    cfgMgr.Start();
    g_pCfgMgr = &cfgMgr;

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
        if (hWnd && IsWindow(hWnd)) {
            PostMessageW(hWnd, WM_USER_MIC_STATE_CHANGED, isMuted ? 1 : 0, 0);
        }
    });

    // ── Spotify Şarkı Takibi ──────────────────────────────────────────
    SpotifyTracker spotifyTracker;
    g_pSpotifyTracker = &spotifyTracker;
    spotifyTracker.Start([hWnd](const TrackInfo&) {
        if (hWnd && IsWindow(hWnd)) {
            PostMessageW(hWnd, WM_USER_TRACK_CHANGED, 0, 0);
        }
    });

    // ── Keyboard hook – HWND mesaj penceresiyle kur ───────────────────
    KeyHook hook;
    g_pHook = &hook;
    {
        Config cfg = cfgMgr.GetConfig();
        hook.UpdateConfig(cfg);
    }

    bool installed = hook.Install(
        [&](Action act) {
            Config cfg = cfgMgr.GetConfig();
            hook.UpdateConfig(cfg);
            OsdManager::Instance().UpdateConfig(cfg);
            DispatchAction(act, cfg.customAppPath, cfg.soundFxEnabled, cfg.language);

            // Mikrofon eylemi sonrasında durumu rozette hemen güncelle
            bool m = GetMicMuteState();
            PostMessageW(hWnd, WM_USER_MIC_STATE_CHANGED, m ? 1 : 0, 0);
        },
        hWnd
    );

    if (!installed) {
        spotifyTracker.Stop();
        g_pSpotifyTracker = nullptr;
        UnregisterMicNotification();
        micOverlay.Destroy();
        g_pMicOverlay = nullptr;
        OsdManager::Instance().Destroy();
        CoUninitialize();
        if (hStopEvent) CloseHandle(hStopEvent);
        if (hStopWaitThread) CloseHandle(hStopWaitThread);
        if (g_hEngineMutex) CloseHandle(g_hEngineMutex);
        return 2;
    }

    // ── Mesaj döngüsü ─────────────────────────────────────────────────
    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    hook.Uninstall();
    g_pHook = nullptr;
    spotifyTracker.Stop();
    g_pSpotifyTracker = nullptr;
    UnregisterMicNotification();
    micOverlay.Destroy();
    g_pMicOverlay = nullptr;
    OsdManager::Instance().Destroy();

    if (hStopEvent) CloseHandle(hStopEvent);
    if (hStopWaitThread) {
        WaitForSingleObject(hStopWaitThread, 300);
        CloseHandle(hStopWaitThread);
    }

    CoUninitialize();
    if (g_hEngineMutex) CloseHandle(g_hEngineMutex);
    return 0;
}
