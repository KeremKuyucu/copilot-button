#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <shellapi.h>
#include <functional>

static constexpr UINT WM_USER_TRAY_ICON = WM_USER + 100;
static constexpr UINT IDM_TRAY_SETTINGS  = 40001;
static constexpr UINT IDM_TRAY_EXIT      = 40002;
static constexpr UINT IDI_APP_ICON       = 101;

class TrayManager {
public:
    TrayManager() = default;
    ~TrayManager();

    bool Install(HWND hWnd, std::function<void()> onSettings, std::function<void()> onExit);
    void Uninstall();
    void Reinstall();
    void HandleMessage(LPARAM lParam);

private:
    void ShowContextMenu();

    HWND                  m_hWnd      = nullptr;
    NOTIFYICONDATAW       m_nid       = {};
    bool                  m_installed = false;
    std::function<void()> m_onSettings;
    std::function<void()> m_onExit;
};
