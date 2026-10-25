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
    bool IsVisible() const { return m_visible; }

private:
    static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
    void OnPaint(HWND hwnd);

    HWND m_hwnd    = nullptr;
    bool m_visible = false;
};
