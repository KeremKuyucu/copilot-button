#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

// ─────────────────────────────────────────────
//  HelloLight – Windows Hello açıldığında ekranı
//  beyaz ışık katmanıyla aydınlatır (varsayılan kapalı)
// ─────────────────────────────────────────────
class HelloLight {
public:
    HelloLight() = default;
    ~HelloLight();

    HelloLight(const HelloLight&) = delete;
    HelloLight& operator=(const HelloLight&) = delete;

    void Init(HINSTANCE hInstance);
    void SetEnabled(bool enabled);
    void Destroy();

    // Aktif Windows Hello oturumu varken ışığı sadece bu oturum için açıp kapatır
    bool IsSessionActive() const;
    void ToggleSessionOverlay();

private:
    void Enable();
    void Disable();
    void ShowOverlayForWindow(HWND targetHwnd);
    void HideOverlay();
    void ApplyRingRegion(int width, int height);

    static bool IsCredentialUIBroker(HWND hwnd);
    static void CALLBACK WinEventProc(
        HWINEVENTHOOK hWinEventHook,
        DWORD event,
        HWND hwnd,
        LONG idObject,
        LONG idChild,
        DWORD dwEventThread,
        DWORD dwmsEventTime
    );
    static LRESULT CALLBACK OverlayWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

    static constexpr UINT_PTR WATCHDOG_TIMER_ID    = 1;
    static constexpr UINT     WATCHDOG_INTERVAL_MS = 200;

    static HelloLight* s_instance;

    HINSTANCE     m_hInstance      = nullptr;
    HWND          m_overlayHwnd    = nullptr;
    HWND          m_helloHwnd      = nullptr;
    HWINEVENTHOOK m_foregroundHook  = nullptr;
    bool          m_enabled         = false;
    bool          m_sessionSuppressed = false;
    bool          m_classRegistered = false;
};
