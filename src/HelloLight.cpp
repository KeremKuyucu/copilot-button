#include "HelloLight.hpp"
#include <string>
#include <cwctype>

HelloLight* HelloLight::s_instance = nullptr;

static const wchar_t* HELLO_OVERLAY_CLASS = L"CopilotButtonHelloWhiteOverlayClass";

HelloLight::~HelloLight() {
    Destroy();
}

void HelloLight::Init(HINSTANCE hInstance) {
    m_hInstance = hInstance;
    s_instance = this;
}

void HelloLight::SetEnabled(bool enabled) {
    if (enabled == m_enabled) {
        return;
    }

    if (enabled) {
        Enable();
    } else {
        Disable();
    }
}

void HelloLight::Enable() {
    if (m_enabled) return;
    if (!m_hInstance) {
        m_hInstance = GetModuleHandleW(nullptr);
    }

    if (!m_classRegistered) {
        WNDCLASSEXW wc = {};
        wc.cbSize        = sizeof(wc);
        wc.lpfnWndProc   = OverlayWndProc;
        wc.hInstance     = m_hInstance;
        wc.lpszClassName = HELLO_OVERLAY_CLASS;
        wc.hbrBackground = static_cast<HBRUSH>(GetStockObject(WHITE_BRUSH));

        if (!RegisterClassExW(&wc)) {
            if (GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
                return;
            }
        }
        m_classRegistered = true;
    }

    if (!m_overlayHwnd) {
        // WS_EX_TOOLWINDOW: Alt+Tab ve görev çubuğunda görünmez
        // WS_EX_NOACTIVATE: Tıklansa veya açılsa bile odak çalmaz
        // WS_EX_TRANSPARENT: Tıklamaları altındaki pencerelere geçirir
        m_overlayHwnd = CreateWindowExW(
            WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_TRANSPARENT,
            HELLO_OVERLAY_CLASS,
            L"",
            WS_POPUP,
            0, 0, 100, 100,
            nullptr,
            nullptr,
            m_hInstance,
            nullptr
        );
        if (!m_overlayHwnd) {
            return;
        }
    }

    if (!m_foregroundHook) {
        m_foregroundHook = SetWinEventHook(
            EVENT_SYSTEM_FOREGROUND,
            EVENT_SYSTEM_FOREGROUND,
            nullptr,
            WinEventProc,
            0,
            0,
            WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS
        );
        if (!m_foregroundHook) {
            DestroyWindow(m_overlayHwnd);
            m_overlayHwnd = nullptr;
            return;
        }
    }

    m_enabled = true;
}

void HelloLight::Disable() {
    HideOverlay();

    if (m_foregroundHook) {
        UnhookWinEvent(m_foregroundHook);
        m_foregroundHook = nullptr;
    }

    if (m_overlayHwnd) {
        DestroyWindow(m_overlayHwnd);
        m_overlayHwnd = nullptr;
    }

    m_enabled = false;
}

void HelloLight::Destroy() {
    Disable();
    if (m_classRegistered && m_hInstance) {
        UnregisterClassW(HELLO_OVERLAY_CLASS, m_hInstance);
        m_classRegistered = false;
    }
    if (s_instance == this) {
        s_instance = nullptr;
    }
}

// Süreç adının CredentialUIBroker.exe olup olmadığını kontrol eder.
// Korumalı sistem süreçlerini okuyabilmek için PROCESS_QUERY_LIMITED_INFORMATION şarttır.
bool HelloLight::IsCredentialUIBroker(HWND hwnd) {
    if (!hwnd || !IsWindow(hwnd)) return false;

    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid == 0) return false;

    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!hProcess) return false;

    wchar_t path[MAX_PATH] = {};
    DWORD size = MAX_PATH;
    bool isBroker = false;

    if (QueryFullProcessImageNameW(hProcess, 0, path, &size)) {
        std::wstring fullPath(path);
        size_t pos = fullPath.find_last_of(L"\\/");
        std::wstring exeName = (pos != std::wstring::npos) ? fullPath.substr(pos + 1) : fullPath;

        for (auto& ch : exeName) {
            ch = static_cast<wchar_t>(std::towlower(ch));
        }

        if (exeName == L"credentialuibroker.exe") {
            isBroker = true;
        }
    }

    CloseHandle(hProcess);
    return isBroker;
}

void HelloLight::ShowOverlayForWindow(HWND targetHwnd) {
    if (!m_overlayHwnd) return;

    m_helloHwnd = targetHwnd;

    // Yalnızca Windows Hello penceresinin bulunduğu monitörü kapla
    HMONITOR hMon = MonitorFromWindow(targetHwnd, MONITOR_DEFAULTTONEAREST);
    MONITORINFO mi = {};
    mi.cbSize = sizeof(mi);

    int x = 0, y = 0, w = GetSystemMetrics(SM_CXSCREEN), h = GetSystemMetrics(SM_CYSCREEN);
    if (GetMonitorInfoW(hMon, &mi)) {
        x = mi.rcMonitor.left;
        y = mi.rcMonitor.top;
        w = mi.rcMonitor.right - mi.rcMonitor.left;
        h = mi.rcMonitor.bottom - mi.rcMonitor.top;
    }

    // HWND_TOPMOST + SWP_NOACTIVATE: Normal pencerelerin üstünde,
    // sistem katmanındaki CredentialUIBroker'ın arkasında, odak çalmadan göster.
    SetWindowPos(
        m_overlayHwnd,
        HWND_TOPMOST,
        x, y, w, h,
        SWP_NOACTIVATE | SWP_SHOWWINDOW
    );

    // Hello penceresi kapandığında yakalayamazsak diye güvenlik zamanlayıcısı başlat
    SetTimer(m_overlayHwnd, WATCHDOG_TIMER_ID, WATCHDOG_INTERVAL_MS, nullptr);
}

void HelloLight::HideOverlay() {
    if (!m_overlayHwnd) {
        m_helloHwnd = nullptr;
        return;
    }

    KillTimer(m_overlayHwnd, WATCHDOG_TIMER_ID);
    m_helloHwnd = nullptr;
    ShowWindow(m_overlayHwnd, SW_HIDE);
}

void CALLBACK HelloLight::WinEventProc(
    HWINEVENTHOOK /*hWinEventHook*/,
    DWORD event,
    HWND hwnd,
    LONG idObject,
    LONG /*idChild*/,
    DWORD /*dwEventThread*/,
    DWORD /*dwmsEventTime*/
) {
    if (!s_instance || !s_instance->m_enabled) {
        return;
    }

    if (event != EVENT_SYSTEM_FOREGROUND || idObject != OBJID_WINDOW) {
        return;
    }

    if (hwnd == s_instance->m_overlayHwnd) {
        return;
    }

    if (IsCredentialUIBroker(hwnd)) {
        s_instance->ShowOverlayForWindow(hwnd);
    } else if (s_instance->m_helloHwnd != nullptr) {
        s_instance->HideOverlay();
    }
}

LRESULT CALLBACK HelloLight::OverlayWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
        case WM_ERASEBKGND: {
            HDC hdc = reinterpret_cast<HDC>(wParam);
            RECT rc;
            GetClientRect(hwnd, &rc);
            FillRect(hdc, &rc, static_cast<HBRUSH>(GetStockObject(WHITE_BRUSH)));
            return 1;
        }
        case WM_TIMER: {
            if (wParam == WATCHDOG_TIMER_ID && s_instance) {
                // Hello penceresi kapandıysa, gizlendiyse veya odağı kaybettiyse katmanı kapat
                if (!s_instance->m_helloHwnd || !IsWindow(s_instance->m_helloHwnd) ||
                    !IsWindowVisible(s_instance->m_helloHwnd) ||
                    GetForegroundWindow() != s_instance->m_helloHwnd) {
                    s_instance->HideOverlay();
                }
            }
            return 0;
        }
        case WM_DESTROY: {
            if (s_instance) {
                KillTimer(hwnd, WATCHDOG_TIMER_ID);
                s_instance->m_helloHwnd = nullptr;
            }
            return 0;
        }
        default:
            return DefWindowProcW(hwnd, msg, wParam, lParam);
    }
}
