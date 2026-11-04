#include "Tray.hpp"
#include <windowsx.h>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "user32.lib")

#ifndef NIN_SELECT
#  define NIN_SELECT (WM_USER + 0)
#endif
#ifndef NIN_KEYSELECT
#  define NIN_KEYSELECT (WM_USER + 1)
#endif

#ifndef GET_X_LPARAM
#  define GET_X_LPARAM(lp) ((int)(short)LOWORD(lp))
#endif
#ifndef GET_Y_LPARAM
#  define GET_Y_LPARAM(lp) ((int)(short)HIWORD(lp))
#endif

TrayManager::~TrayManager() {
    Uninstall();
}

bool TrayManager::Install(HWND hWnd, std::function<void()> onSettings, std::function<void()> onExit) {
    m_hWnd       = hWnd;
    m_onSettings = std::move(onSettings);
    m_onExit     = std::move(onExit);

    Reinstall();
    return m_installed;
}

void TrayManager::Uninstall() {
    if (m_installed) {
        Shell_NotifyIconW(NIM_DELETE, &m_nid);
        m_installed = false;
    }
    if (m_hIcon) {
        DestroyIcon(m_hIcon);
        m_hIcon = nullptr;
    }
    m_nid.hIcon = nullptr;
}

void TrayManager::Reinstall() {
    if (!m_hWnd) return;

    if (!m_hIcon) {
        HINSTANCE hInst = GetModuleHandleW(nullptr);

        int cx = GetSystemMetrics(SM_CXSMICON);
        int cy = GetSystemMetrics(SM_CYSMICON);
        if (cx <= 0) cx = 16;
        if (cy <= 0) cy = 16;

        m_hIcon = (HICON)LoadImageW(hInst, MAKEINTRESOURCEW(IDI_APP_ICON),
                                    IMAGE_ICON, cx, cy, LR_DEFAULTCOLOR);
        if (!m_hIcon) {
            m_hIcon = LoadIconW(nullptr, MAKEINTRESOURCEW(32512));
        }
    }

    ZeroMemory(&m_nid, sizeof(m_nid));
    m_nid.cbSize           = sizeof(NOTIFYICONDATAW);
    m_nid.hWnd             = m_hWnd;
    m_nid.uID              = 1001;
    m_nid.uFlags           = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    m_nid.uCallbackMessage = WM_USER_TRAY_ICON;
    m_nid.hIcon            = m_hIcon;

    wcscpy_s(m_nid.szTip, L"Copilot Button");

    // Eski/askıda kalan simgeyi sil ve yenisini ekle
    Shell_NotifyIconW(NIM_DELETE, &m_nid);

    m_installed = (Shell_NotifyIconW(NIM_ADD, &m_nid) != FALSE);
    if (!m_installed) {
        for (int i = 0; i < 5 && !m_installed; ++i) {
            Sleep(100);
            m_installed = (Shell_NotifyIconW(NIM_ADD, &m_nid) != FALSE);
        }
    }

    if (m_installed) {
        m_nid.uVersion = NOTIFYICON_VERSION_4;
        Shell_NotifyIconW(NIM_SETVERSION, &m_nid);
    }
}

void TrayManager::HandleMessage(WPARAM wParam, LPARAM lParam) {
    UINT msg = LOWORD(lParam);
    if (msg == WM_RBUTTONUP || msg == WM_CONTEXTMENU) {
        int x = GET_X_LPARAM(wParam);
        int y = GET_Y_LPARAM(wParam);
        POINT pt = { x, y };
        if (x == 0 && y == 0) {
            GetCursorPos(&pt);
        }
        ShowContextMenu(pt);
    } else if (msg == WM_LBUTTONUP || msg == WM_LBUTTONDBLCLK ||
               msg == NIN_SELECT || msg == NIN_KEYSELECT) {
        if (m_onSettings) {
            m_onSettings();
        }
    }
}

void TrayManager::ShowContextMenu(POINT pt) {
    if (pt.x == 0 && pt.y == 0) {
        GetCursorPos(&pt);
    }

    HMENU hMenu = CreatePopupMenu();
    if (!hMenu) return;

    AppendMenuW(hMenu, MF_STRING, IDM_TRAY_SETTINGS, L"⚙️  Settings");
    AppendMenuW(hMenu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(hMenu, MF_STRING, IDM_TRAY_EXIT, L"❌  Exit");

    SetForegroundWindow(m_hWnd);
    int cmd = TrackPopupMenu(hMenu,
                            TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_BOTTOMALIGN,
                            pt.x, pt.y, 0, m_hWnd, nullptr);
    PostMessageW(m_hWnd, WM_NULL, 0, 0);
    DestroyMenu(hMenu);

    if (cmd == IDM_TRAY_SETTINGS) {
        if (m_onSettings) m_onSettings();
    } else if (cmd == IDM_TRAY_EXIT) {
        if (m_onExit) m_onExit();
    }
}
