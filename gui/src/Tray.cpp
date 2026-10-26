#include "Tray.hpp"
#include "I18n.hpp"

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "user32.lib")

TrayManager& TrayManager::Instance() {
    static TrayManager inst;
    return inst;
}

TrayManager::~TrayManager() {
    Uninstall();
}

bool TrayManager::Install(HWND hWnd, std::function<void()> onSettings, std::function<void()> onExit, LangGetter getLang) {
    if (m_installed) return true;

    m_hWnd       = hWnd;
    m_onSettings = std::move(onSettings);
    m_onExit     = std::move(onExit);
    m_getLang    = std::move(getLang);

    HINSTANCE hInst = GetModuleHandleW(nullptr);

    int cx = GetSystemMetrics(SM_CXSMICON);
    int cy = GetSystemMetrics(SM_CYSMICON);
    if (cx <= 0) cx = 16;
    if (cy <= 0) cy = 16;

    HICON hIcon = (HICON)LoadImageW(hInst, MAKEINTRESOURCEW(IDI_APP_ICON),
                                    IMAGE_ICON, cx, cy, LR_DEFAULTCOLOR);
    if (!hIcon) {
        hIcon = LoadIconW(nullptr, MAKEINTRESOURCEW(32512));
    }

    ZeroMemory(&m_nid, sizeof(m_nid));
    m_nid.cbSize           = sizeof(NOTIFYICONDATAW);
    m_nid.hWnd             = m_hWnd;
    m_nid.uID              = 1001;
    m_nid.uFlags           = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    m_nid.uCallbackMessage = WM_USER_TRAY_ICON;
    m_nid.hIcon            = hIcon;

    std::wstring lang = m_getLang ? m_getLang() : L"tr";
    wcscpy_s(m_nid.szTip, I18n::TrayTip(lang).c_str());

    m_installed = (Shell_NotifyIconW(NIM_ADD, &m_nid) != FALSE);
    return m_installed;
}

void TrayManager::Uninstall() {
    if (m_installed) {
        Shell_NotifyIconW(NIM_DELETE, &m_nid);
        if (m_nid.hIcon) {
            DestroyIcon(m_nid.hIcon);
            m_nid.hIcon = nullptr;
        }
        m_installed = false;
    }
}

void TrayManager::Reinstall() {
    if (m_installed && m_nid.hIcon) {
        Shell_NotifyIconW(NIM_ADD, &m_nid);
    }
}

void TrayManager::ShowNotification(const std::wstring& title, const std::wstring& msg) {
    if (!m_installed || !m_hWnd) return;

    NOTIFYICONDATAW nid = m_nid;
    nid.uFlags |= NIF_INFO;
    nid.dwInfoFlags = NIIF_INFO;
    wcscpy_s(nid.szInfoTitle, title.c_str());
    wcscpy_s(nid.szInfo, msg.c_str());
    Shell_NotifyIconW(NIM_MODIFY, &nid);
}

void TrayManager::HandleMessage(LPARAM lParam) {
    if (lParam == WM_RBUTTONUP || lParam == WM_CONTEXTMENU) {
        ShowContextMenu();
    } else if (lParam == WM_LBUTTONUP) {
        if (m_onSettings) {
            m_onSettings();
        }
    }
}

void TrayManager::ShowContextMenu() {
    POINT pt;
    GetCursorPos(&pt);

    std::wstring lang = m_getLang ? m_getLang() : L"tr";

    HMENU hMenu = CreatePopupMenu();
    AppendMenuW(hMenu, MF_STRING, IDM_TRAY_SETTINGS, I18n::TraySettings(lang).c_str());
    AppendMenuW(hMenu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(hMenu, MF_STRING, IDM_TRAY_EXIT, I18n::TrayExit(lang).c_str());

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
