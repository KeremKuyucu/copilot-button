// main.cpp – Copilot Button (Hafif, tek parça sistem tepsisi ve klavye denetleyicisi)
// Konsol penceresi açılmaz (-mwindows / SUBSYSTEM:WINDOWS)
// requireAdministrator yetkisi app.manifest ile sağlanır.

#include <windows.h>
#include <objbase.h>
#include <string>
#include <tlhelp32.h>
#include <shellapi.h>

#include "Config.hpp"
#include "KeyHook.hpp"
#include "Audio.hpp"
#include "Actions.hpp"
#include "MicOverlay.hpp"
#include "MediaTracker.hpp"
#include "Osd.hpp"
#include "Tray.hpp"
#include "AppRegister.hpp"

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
static constexpr UINT WM_USER_APPBAR_NOTIFY     = WM_USER + 104;

static const wchar_t* APP_WND_CLASS   = L"CopilotButtonHost";
static const wchar_t* APP_MUTEX_NAME  = L"Global\\CopilotButton_SingleInstance_Mutex";

static MicOverlay*     g_pMicOverlay     = nullptr;
static MediaTracker*   g_pMediaTracker   = nullptr;
static ConfigManager*  g_pCfgMgr         = nullptr;
static KeyHook*        g_pHook           = nullptr;
static TrayManager*    g_pTray           = nullptr;
static UINT            g_uTaskbarRestart = 0;
static HANDLE          g_hAppMutex       = nullptr;

static LRESULT CALLBACK HostWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == g_uTaskbarRestart) {
        if (g_pTray) {
            g_pTray->Reinstall();
        }
        OsdManager::Instance().OnTaskbarRecreated();
        return 0;
    }

    switch (msg) {
        case WM_USER_APPBAR_NOTIFY:
            OsdManager::Instance().CheckFullscreenAndTaskbarState();
            return 0;

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
            if (g_pMediaTracker && g_pCfgMgr) {
                Config cfg = g_pCfgMgr->GetConfig();
                OsdManager::Instance().UpdateConfig(cfg);
                if (cfg.mediaTrackOsd) {
                    TrackInfo track = g_pMediaTracker->GetCurrentTrack();
                    if (!track.title.empty()) {
                        if (cfg.mediaOsdPersistent || track.isPlaying) {
                            OsdManager::Instance().ShowMediaTrack(track.title, track.artist, track.isPlaying, 0, track.thumbnailData);
                        } else {
                            OsdManager::Instance().HideMediaTrack();
                        }
                    } else {
                        OsdManager::Instance().HideMediaTrack();
                    }
                } else {
                    OsdManager::Instance().HideMediaTrack();
                }
            }
            return 0;

        case WM_SETTINGCHANGE:
        case WM_DISPLAYCHANGE:
            if (g_pCfgMgr) {
                PostMessageW(hwnd, WM_USER_TRACK_CHANGED, 0, 0);
            }
            OsdManager::Instance().CheckFullscreenAndTaskbarState();
            return 0;

        case WM_USER_CONFIG_CHANGED:
            if (g_pCfgMgr) {
                Config cfg = g_pCfgMgr->GetConfig();
                if (g_pHook) {
                    g_pHook->UpdateConfig(cfg);
                }
                OsdManager::Instance().UpdateConfig(cfg);
                SetAutoStartRegistry(cfg.autoStart);
            }
            return 0;

        case WM_CLOSE:
            if (g_pTray) {
                g_pTray->Uninstall();
            }
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
            if ((_wcsicmp(entry.szExeFile, L"Copilot.exe") == 0 ||
                 _wcsicmp(entry.szExeFile, L"CopilotButton.exe") == 0 ||
                 _wcsicmp(entry.szExeFile, L"CopilotButtonEngine.exe") == 0) &&
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

static bool EnsureSingleInstance() {
    TerminateOldInstances();
    Sleep(50);
    g_hAppMutex = CreateMutexW(nullptr, TRUE, APP_MUTEX_NAME);
    return (GetLastError() != ERROR_ALREADY_EXISTS);
}

// ─────────────────────────────────────────────
//  WinMain – Giriş noktası
// ─────────────────────────────────────────────
int WINAPI WinMain(HINSTANCE hInst, HINSTANCE, LPSTR, int) {
    // ── Kaldırma (Uninstall) argümanı denetimi ────────────────────────
    const wchar_t* cmdLine = GetCommandLineW();
    if (wcsstr(cmdLine, L"--uninstall") || wcsstr(cmdLine, L"/uninstall")) {
        bool silent = (wcsstr(cmdLine, L"--silent") != nullptr ||
                       wcsstr(cmdLine, L"/quiet")   != nullptr ||
                       wcsstr(cmdLine, L"/qn")      != nullptr);
        UninstallApp(silent);
        return 0;
    }

    // ── Her zaman %LOCALAPPDATA%\CopilotButton klasörüne taşıma denetimi ──
    if (CheckAndPerformSelfRelocate()) {
        return 0;
    }

    CleanupOldSourceIfRequested();

    if (!EnsureSingleInstance()) return 0;

    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

    // ── Windows'a tanıt (AUMID + Başlat Menüsü Kısayolu + Ayarlar Listesi) ─
    RegisterAppWithWindows();

    g_uTaskbarRestart = RegisterWindowMessageW(L"TaskbarCreated");

    // ── Gizli bildirim ve tray host penceresi ─────────────────────────
    WNDCLASSEXW wc     = {};
    wc.cbSize          = sizeof(wc);
    wc.hInstance       = hInst;
    wc.lpfnWndProc     = HostWndProc;
    wc.lpszClassName   = APP_WND_CLASS;
    RegisterClassExW(&wc);

    HWND hWnd = CreateWindowExW(0, APP_WND_CLASS, APP_WND_CLASS,
                                WS_POPUP, 0, 0, 0, 0,
                                nullptr, nullptr, hInst, nullptr);

    ChangeWindowMessageFilter(WM_CLOSE, MSGFLT_ADD);

    // ── Config yükle + INI dosyasındaki değişiklikleri dinamik izle ───
    ConfigManager cfgMgr(GetIniPath(), [hWnd](const Config&) {
        if (hWnd && IsWindow(hWnd)) {
            PostMessageW(hWnd, WM_USER_CONFIG_CHANGED, 0, 0);
        }
    });
    cfgMgr.Start();
    g_pCfgMgr = &cfgMgr;

    Config initialCfg = cfgMgr.GetConfig();
    SetAutoStartRegistry(initialCfg.autoStart);

    // ── OSD Yöneticisi başlat ────────────────────────────────────────
    OsdManager::Instance().Init(hWnd);
    OsdManager::Instance().UpdateConfig(initialCfg);

    // ── Kalıcı Mikrofon Rozeti ────────────────────────────────────────
    MicOverlay micOverlay;
    g_pMicOverlay = &micOverlay;
    micOverlay.Create();

    bool initialMicMute = GetMicMuteState();
    micOverlay.SetMuted(initialMicMute);

    // ── Sistem Tepsisi (Tray Icon) ───────────────────────────────────
    TrayManager tray;
    g_pTray = &tray;
    tray.Install(
        hWnd,
        []() {
            // Ayarlar: doğrudan config.ini dosyasını varsayılan metin düzenleyicide aç
            ShellExecuteW(nullptr, L"open", GetIniPath().c_str(), nullptr, nullptr, SW_SHOWNORMAL);
        },
        [hWnd]() {
            // Çıkış
            PostMessageW(hWnd, WM_CLOSE, 0, 0);
        }
    );

    // ── Harici Mikrofon Senkronizasyonu (Core Audio Callback) ─────────
    RegisterMicNotification([hWnd](bool isMuted) {
        if (hWnd && IsWindow(hWnd)) {
            PostMessageW(hWnd, WM_USER_MIC_STATE_CHANGED, isMuted ? 1 : 0, 0);
        }
    });

    // ── Evrensel Medya Takibi ─────────────────────────────────────────
    MediaTracker mediaTracker;
    g_pMediaTracker = &mediaTracker;
    mediaTracker.Start([hWnd](const TrackInfo&) {
        if (hWnd && IsWindow(hWnd)) {
            PostMessageW(hWnd, WM_USER_TRACK_CHANGED, 0, 0);
        }
    });

    // Başlangıçta halihazırda çalan bir medya varsa hemen algıla
    PostMessageW(hWnd, WM_USER_TRACK_CHANGED, 0, 0);

    // ── Keyboard hook ─────────────────────────────────────────────────
    KeyHook hook;
    g_pHook = &hook;
    hook.UpdateConfig(initialCfg);

    bool installed = hook.Install(
        [&](Action act) {
            Config cfg = cfgMgr.GetConfig();
            hook.UpdateConfig(cfg);
            OsdManager::Instance().UpdateConfig(cfg);
            DispatchAction(act, cfg.customAppPath, cfg.soundFxEnabled);

            bool m = GetMicMuteState();
            PostMessageW(hWnd, WM_USER_MIC_STATE_CHANGED, m ? 1 : 0, 0);
        },
        hWnd
    );

    if (!installed) {
        mediaTracker.Stop();
        g_pMediaTracker = nullptr;
        UnregisterMicNotification();
        micOverlay.Destroy();
        g_pMicOverlay = nullptr;
        tray.Uninstall();
        g_pTray = nullptr;
        OsdManager::Instance().Destroy();
        CoUninitialize();
        if (g_hAppMutex) CloseHandle(g_hAppMutex);
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
    mediaTracker.Stop();
    g_pMediaTracker = nullptr;
    UnregisterMicNotification();
    micOverlay.Destroy();
    g_pMicOverlay = nullptr;
    tray.Uninstall();
    g_pTray = nullptr;
    OsdManager::Instance().Destroy();

    CoUninitialize();
    if (g_hAppMutex) CloseHandle(g_hAppMutex);
    return 0;
}
