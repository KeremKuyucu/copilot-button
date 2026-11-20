#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

class MicOverlay {
public:
    MicOverlay() = default;
    ~MicOverlay();

    bool Create();
    void Destroy();

    void Show();
    void Hide();
    void SetMuted(bool isMuted);
    void RefreshPosition();

private:
    static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
    void UpdateLayout();
    void OnPaint(HWND hwnd);

    HWND m_hwnd    = nullptr;
    bool m_visible = false;
    int  m_x       = 20;
    int  m_y       = 15;
    int  m_w       = 220;
    int  m_h       = 32;
    UINT m_dpi     = 96;
};
