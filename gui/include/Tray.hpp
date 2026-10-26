#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <shellapi.h>
#include <functional>
#include <string>

static constexpr UINT WM_USER_TRAY_ICON = WM_USER + 100;
static constexpr UINT IDM_TRAY_SETTINGS  = 40001;
static constexpr UINT IDM_TRAY_EXIT      = 40002;
static constexpr UINT IDI_APP_ICON       = 101;

class TrayManager {
public:
    static TrayManager& Instance();

    TrayManager() = default;
    ~TrayManager();

    using LangGetter = std::function<std::wstring()>;
    bool Install(HWND hWnd, std::function<void()> onSettings, std::function<void()> onExit, LangGetter getLang = nullptr);
    void Uninstall();
    void Reinstall();
    void HandleMessage(LPARAM lParam);
    void ShowNotification(const std::wstring& title, const std::wstring& msg);

private:
    void ShowContextMenu();

    HWND                  m_hWnd      = nullptr;
    NOTIFYICONDATAW       m_nid       = {};
    bool                  m_installed = false;
    std::function<void()> m_onSettings;
    std::function<void()> m_onExit;
    LangGetter            m_getLang;
};
