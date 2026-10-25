#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <string>

class WebViewSettingsWindow {
public:
    static WebViewSettingsWindow& Instance();

    bool Open(const std::wstring& iniPath);
    void Close();
    bool IsOpen() const;

private:
    WebViewSettingsWindow() = default;
    ~WebViewSettingsWindow();

    static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
    void OnSize(int width, int height);
    void OnWebMessage(const std::wstring& jsonMsg);
    void SendCurrentConfig();
    void HandleSaveConfig(const std::string& jsonBody);
    void HandleBrowseApp();

    std::wstring m_iniPath;
    std::wstring m_htmlDir;
    HWND         m_hWnd       = nullptr;
    void*        m_env        = nullptr; // ICoreWebView2Environment*
    void*        m_controller = nullptr; // ICoreWebView2Controller*
    void*        m_webView    = nullptr; // ICoreWebView2*
    UINT32       m_browserPid = 0;
    bool         m_initialized = false;
};
