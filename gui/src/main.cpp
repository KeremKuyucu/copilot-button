// main.cpp – CopilotButton GUI ve Tepsi (Tray) Uygulaması
// Konsol penceresi açılmaz (-mwindows / SUBSYSTEM:WINDOWS)
// Tray simgesi, WebView2 Ayarlar Arayüzü ve Motor (Engine) yaşam döngüsü denetleyicisi

#include <windows.h>
#include <objbase.h>
#include <string>
#include <tlhelp32.h>

#include "Config.hpp"
#include "Tray.hpp"
#include "WebViewSettings.hpp"
#include "AppRegister.hpp"
#include "I18n.hpp"

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "advapi32.lib")

static constexpr UINT WM_USER_OPEN_SETTINGS = WM_USER + 201;

static const wchar_t* GUI_WND_CLASS      = L"CopilotButtonGUIHost";
static const wchar_t* GUI_MUTEX_NAME     = L"Global\\CopilotButton_GUI_Mutex";
static const wchar_t* ENGINE_EXE_NAME    = L"CopilotButtonEngine.exe";
static const wchar_t* ENGINE_MUTEX_NAME  = L"Global\\CopilotButton_Engine_v2";
static const wchar_t* ENGINE_STOP_EVENT = L"Global\\CopilotButton_Engine_Stop_Event";
static const wchar_t* ENGINE_WND_CLASS   = L"CopilotButtonEngineHost";

static TrayManager* g_pTray           = nullptr;
static UINT         g_uTaskbarRestart = 0;
static HANDLE       g_hGuiMutex       = nullptr;

// ─────────────────────────────────────────────
//  Motor Sürecini Başlat (Çalışmıyorsa)
// ─────────────────────────────────────────────
static void StartEngine() {
    // 1. Motor zaten çalışıyor mu kontrol et
    HANDLE hMutex = OpenMutexW(SYNCHRONIZE, FALSE, ENGINE_MUTEX_NAME);
    if (hMutex) {
        CloseHandle(hMutex);
        return; // Motor zaten aktif
    }

    // 2. CopilotButtonEngine.exe dosya yolunu belirle
    wchar_t curExe[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, curExe, MAX_PATH);
    wchar_t* lastSlash = wcsrchr(curExe, L'\\');
    if (lastSlash) *lastSlash = L'\0';

    std::wstring engineExe = std::wstring(curExe) + L"\\" + ENGINE_EXE_NAME;
    static constexpr UINT IDR_ENGINE_EXE = 104;

    auto ExtractResourceToFile = [](int resourceId, const std::wstring& destPath) -> bool {
        HINSTANCE hInst = GetModuleHandleW(nullptr);
        HRSRC hRsrc = FindResourceW(hInst, MAKEINTRESOURCEW(resourceId), MAKEINTRESOURCEW(10));
        if (!hRsrc) return false;

        HGLOBAL hGlobal = LoadResource(hInst, hRsrc);
        if (!hGlobal) return false;

        DWORD size = SizeofResource(hInst, hRsrc);
        const void* pData = LockResource(hGlobal);
        if (!pData || size == 0) return false;

        HANDLE hFile = CreateFileW(destPath.c_str(), GENERIC_WRITE, FILE_SHARE_READ,
                                   nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (hFile == INVALID_HANDLE_VALUE) return false;

        DWORD written = 0;
        BOOL ok = WriteFile(hFile, pData, size, &written, nullptr);
        CloseHandle(hFile);
        return (ok && written == size);
    };

    if (GetFileAttributesW(engineExe.c_str()) == INVALID_FILE_ATTRIBUTES) {
        // Geliştirici veya alt klasör durumunu kontrol et
        std::wstring alt1 = std::wstring(curExe) + L"\\engine\\" + ENGINE_EXE_NAME;
        std::wstring alt2 = std::wstring(curExe) + L"\\..\\" + ENGINE_EXE_NAME;
        if (GetFileAttributesW(alt1.c_str()) != INVALID_FILE_ATTRIBUTES) {
            engineExe = alt1;
        } else if (GetFileAttributesW(alt2.c_str()) != INVALID_FILE_ATTRIBUTES) {
            engineExe = alt2;
        } else {
            // Disk üzerinde yoksa gömülü kaynaktan exe dizinine veya %LOCALAPPDATA%'ya çıkart
            if (!ExtractResourceToFile(IDR_ENGINE_EXE, engineExe)) {
                wchar_t localApp[MAX_PATH] = {};
                if (GetEnvironmentVariableW(L"LOCALAPPDATA", localApp, MAX_PATH)) {
                    std::wstring appDataRoot = std::wstring(localApp) + L"\\CopilotButton";
                    CreateDirectoryW(appDataRoot.c_str(), nullptr);
                    std::wstring appDataEngine = appDataRoot + L"\\" + ENGINE_EXE_NAME;
                    if (ExtractResourceToFile(IDR_ENGINE_EXE, appDataEngine)) {
                        engineExe = appDataEngine;
                    }
                }
            }
        }
    }

    if (GetFileAttributesW(engineExe.c_str()) != INVALID_FILE_ATTRIBUTES) {
        STARTUPINFOW si = { sizeof(si) };
        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_HIDE;
        PROCESS_INFORMATION pi = {};
        if (CreateProcessW(engineExe.c_str(), nullptr, nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, curExe, &si, &pi)) {
            CloseHandle(pi.hProcess);
            CloseHandle(pi.hThread);
        }
    }
}

// ─────────────────────────────────────────────
//  Motor Sürecini Kapat (Temiz ve Güvenli Sonlandırma)
// ─────────────────────────────────────────────
static void StopEngine() {
    // 1. Stop Event'i tetikle
    HANDLE hStopEvent = OpenEventW(EVENT_MODIFY_STATE, FALSE, ENGINE_STOP_EVENT);
    if (hStopEvent) {
        SetEvent(hStopEvent);
        CloseHandle(hStopEvent);
    }

    // 2. Motor host penceresine WM_CLOSE gönder
    HWND hEngineWnd = FindWindowW(ENGINE_WND_CLASS, ENGINE_WND_CLASS);
    if (hEngineWnd) {
        PostMessageW(hEngineWnd, WM_CLOSE, 0, 0);
    }

    // 3. Motorun kapanmasını 500ms bekle
    for (int i = 0; i < 10; ++i) {
        HANDLE hMutex = OpenMutexW(SYNCHRONIZE, FALSE, ENGINE_MUTEX_NAME);
        if (!hMutex) {
            break; // Kapanmış
        }
        CloseHandle(hMutex);
        Sleep(50);
    }

    // 4. Eğer hala askıda kalmış motor süreci varsa zorla sonlandır
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap != INVALID_HANDLE_VALUE) {
        PROCESSENTRY32W pe = { sizeof(pe) };
        if (Process32FirstW(snap, &pe)) {
            do {
                if (_wcsicmp(pe.szExeFile, ENGINE_EXE_NAME) == 0) {
                    HANDLE hProc = OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
                    if (hProc) {
                        TerminateProcess(hProc, 0);
                        CloseHandle(hProc);
                    }
                }
            } while (Process32NextW(snap, &pe));
        }
        CloseHandle(snap);
    }
}

// ─────────────────────────────────────────────
//  Eski veya askıda kalan CopilotButton GUI örneklerini sonlandır
// ─────────────────────────────────────────────
static void TerminateOldGuiInstances() {
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
//  Tek örnek denetimi
// ─────────────────────────────────────────────
static bool EnsureSingleGuiInstance() {
    TerminateOldGuiInstances();
    Sleep(50);
    g_hGuiMutex = CreateMutexW(nullptr, TRUE, GUI_MUTEX_NAME);
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        // Zaten çalışan GUI varsa penceresine ayarları aç mesajı yolla
        HWND hExisting = FindWindowW(GUI_WND_CLASS, GUI_WND_CLASS);
        if (hExisting) {
            PostMessageW(hExisting, WM_USER_OPEN_SETTINGS, 0, 0);
        }
        if (g_hGuiMutex) {
            CloseHandle(g_hGuiMutex);
            g_hGuiMutex = nullptr;
        }
        return false;
    }
    return true;
}

// ─────────────────────────────────────────────
//  Pencere Prosedürü
// ─────────────────────────────────────────────
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

        case WM_USER_OPEN_SETTINGS:
            WebViewSettingsWindow::Instance().Open(GetIniPath());
            return 0;

        case WM_CLOSE:
            StopEngine();
            if (g_pTray) {
                g_pTray->Uninstall();
            }
            WebViewSettingsWindow::Instance().Close();
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
//  WinMain – GUI Giriş Noktası
// ─────────────────────────────────────────────
int WINAPI WinMain(HINSTANCE hInst, HINSTANCE, LPSTR, int) {
    // ── Kendi kendini %LOCALAPPDATA%\CopilotButton klasörüne taşıma denetimi ──
    if (CheckAndPerformSelfRelocate()) {
        return 0; // Taşındı ve kalıcı konumdaki exe başlatıldı
    }

    // Eğer --delete-source ile başlatıldıysak eski geçici dosyayı temizle
    CleanupOldSourceIfRequested();

    if (!EnsureSingleGuiInstance()) return 0;

    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

    // ── Uygulamayı Windows'a resmi uygulama olarak tanıt (AUMID + Kısayol + Registry) ──
    RegisterAppWithWindows();

    // ── Motoru (Engine) başlat (çalışmıyorsa) ─────────────────────────
    StartEngine();

    g_uTaskbarRestart = RegisterWindowMessageW(L"TaskbarCreated");

    // ── Gizli mesaj ve tray host penceresi ─────────────────────────────
    WNDCLASSEXW wc     = {};
    wc.cbSize          = sizeof(wc);
    wc.hInstance       = hInst;
    wc.lpfnWndProc     = HostWndProc;
    wc.lpszClassName   = GUI_WND_CLASS;
    RegisterClassExW(&wc);

    HWND hWnd = CreateWindowExW(0, GUI_WND_CLASS, GUI_WND_CLASS,
                                WS_POPUP, 0, 0, 0, 0,
                                nullptr, nullptr, hInst, nullptr);

    ChangeWindowMessageFilter(WM_CLOSE, MSGFLT_ADD);
    ChangeWindowMessageFilter(WM_USER_OPEN_SETTINGS, MSGFLT_ADD);

    // ── Sistem Tepsisi (Tray Icon) ───────────────────────────────────
    TrayManager tray;
    g_pTray = &tray;
    tray.Install(
        hWnd,
        []() {
            WebViewSettingsWindow::Instance().Open(GetIniPath());
        },
        [hWnd]() {
            // Exit'a basıldığında motoru kapat ve GUI'den çık
            StopEngine();
            PostMessageW(hWnd, WM_CLOSE, 0, 0);
        },
        []() {
            wchar_t lbuf[32] = {};
            GetPrivateProfileStringW(L"Settings", L"Language", L"tr", lbuf, 32, GetIniPath().c_str());
            return std::wstring(lbuf);
        }
    );

    // ── Mesaj döngüsü ─────────────────────────────────────────────────
    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    StopEngine();
    tray.Uninstall();
    g_pTray = nullptr;
    WebViewSettingsWindow::Instance().Close();

    CoUninitialize();
    if (g_hGuiMutex) CloseHandle(g_hGuiMutex);
    return 0;
}
