#include "MicOverlay.hpp"
#include <dwmapi.h>
#include <algorithm>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "dwmapi.lib")

// ─────────────────────────────────────────────
//  SDK Sabitleri ve Makro Güvenliği
// ─────────────────────────────────────────────
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#  define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWCP_ROUND
#  define DWMWCP_ROUND 2
#endif

#ifndef WM_DPICHANGED
#  define WM_DPICHANGED 0x02E0
#endif

static const wchar_t* OVERLAY_CLASS_NAME = L"CopilotMicOverlayClass";

static UINT GetEffectiveDpi(HWND hwnd) {
    using GetDpiForWindowFn = UINT(WINAPI*)(HWND);
    static auto pGetDpiForWindow = reinterpret_cast<GetDpiForWindowFn>(
        reinterpret_cast<INT_PTR>(GetProcAddress(GetModuleHandleW(L"user32.dll"), "GetDpiForWindow")));
    if (pGetDpiForWindow && hwnd) {
        UINT dpi = pGetDpiForWindow(hwnd);
        if (dpi > 0) return dpi;
    }
    HDC hdc = GetDC(hwnd);
    UINT dpi = 96;
    if (hdc) {
        int logY = GetDeviceCaps(hdc, LOGPIXELSY);
        if (logY > 0) dpi = static_cast<UINT>(logY);
        ReleaseDC(hwnd, hdc);
    }
    return dpi;
}

static int ScaleDpi(int px96, UINT dpi) {
    return MulDiv(px96, static_cast<int>(dpi), 96);
}

MicOverlay::~MicOverlay() {
    Destroy();
}

bool MicOverlay::Create() {
    if (m_hwnd) return true;

    HINSTANCE hInst = GetModuleHandleW(nullptr);

    // Sınıf kaydını tek seferlik yap (ERROR_CLASS_ALREADY_EXISTS engeli)
    static bool s_classRegistered = false;
    if (!s_classRegistered) {
        WNDCLASSEXW wc   = {};
        wc.cbSize        = sizeof(wc);
        wc.hInstance     = hInst;
        wc.lpfnWndProc   = WndProc;
        wc.lpszClassName = OVERLAY_CLASS_NAME;
        wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
        if (RegisterClassExW(&wc) || GetLastError() == ERROR_CLASS_ALREADY_EXISTS) {
            s_classRegistered = true;
        }
    }

    m_hwnd = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_NOACTIVATE,
        OVERLAY_CLASS_NAME,
        L"CopilotMicOverlay",
        WS_POPUP,
        m_x, m_y, m_w, m_h,
        nullptr, nullptr, hInst, this
    );

    if (!m_hwnd) return false;

    // Windows 11 DWM yuvarlatılmış köşe tercihi (DWMWCP_ROUND = 2)
    DWORD cornerPref = DWMWCP_ROUND;
    DwmSetWindowAttribute(m_hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &cornerPref, sizeof(cornerPref));

    // Saydamlık ayarı (240/255)
    SetLayeredWindowAttributes(m_hwnd, 0, 240, LWA_ALPHA);

    UpdateLayout();
    return true;
}

void MicOverlay::UpdateLayout() {
    if (!m_hwnd) return;

    m_dpi = GetEffectiveDpi(m_hwnd);

    RECT workArea = {};
    if (!SystemParametersInfoW(SPI_GETWORKAREA, 0, &workArea, 0)) {
        workArea.left   = 0;
        workArea.top    = 0;
        workArea.right  = GetSystemMetrics(SM_CXSCREEN);
        workArea.bottom = GetSystemMetrics(SM_CYSCREEN);
    }

    int textW = 140;
    HDC hdc = GetDC(m_hwnd);
    if (hdc) {
        HFONT font = CreateFontW(
            -MulDiv(9, static_cast<int>(m_dpi), 72),
            0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
            CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
            L"Segoe UI"
        );
        HGDIOBJ oldFont = SelectObject(hdc, font);
        RECT rcCalc = { 0, 0, 0, 0 };
        DrawTextW(hdc, L"MICROPHONE MUTED", -1, &rcCalc, DT_CALCRECT | DT_SINGLELINE);
        textW = rcCalc.right - rcCalc.left;
        SelectObject(hdc, oldFont);
        DeleteObject(font);
        ReleaseDC(m_hwnd, hdc);
    }

    m_h = ScaleDpi(32, m_dpi);
    m_w = (std::max)(ScaleDpi(34, m_dpi) + textW + ScaleDpi(16, m_dpi), ScaleDpi(180, m_dpi));
    m_x = workArea.left + ScaleDpi(20, m_dpi);
    m_y = workArea.top + ScaleDpi(15, m_dpi);

    SetWindowPos(m_hwnd, HWND_TOPMOST, m_x, m_y, m_w, m_h, SWP_NOACTIVATE);

    int radius = ScaleDpi(10, m_dpi);
    HRGN hRgn = CreateRoundRectRgn(0, 0, m_w + 1, m_h + 1, radius, radius);
    if (hRgn) {
        SetWindowRgn(m_hwnd, hRgn, TRUE);
    }
}

void MicOverlay::Destroy() {
    if (m_hwnd) {
        DestroyWindow(m_hwnd);
        m_hwnd = nullptr;
    }
    m_visible = false;
}

void MicOverlay::Show() {
    if (!m_hwnd) Create();
    if (m_hwnd) {
        UpdateLayout();
        SetLayeredWindowAttributes(m_hwnd, 0, 240, LWA_ALPHA);
        SetWindowPos(m_hwnd, HWND_TOPMOST, m_x, m_y, m_w, m_h,
                     SWP_NOACTIVATE | SWP_SHOWWINDOW);
        InvalidateRect(m_hwnd, nullptr, TRUE);
        UpdateWindow(m_hwnd);
        m_visible = true;
    }
}

void MicOverlay::Hide() {
    if (m_hwnd) {
        ShowWindow(m_hwnd, SW_HIDE);
        m_visible = false;
    }
}

void MicOverlay::SetMuted(bool isMuted) {
    if (isMuted) {
        Show();
    } else {
        Hide();
    }
}

void MicOverlay::RefreshPosition() {
    if (!m_hwnd) return;
    UpdateLayout();
    if (m_visible) {
        SetWindowPos(m_hwnd, HWND_TOPMOST, m_x, m_y, m_w, m_h,
                     SWP_NOACTIVATE | SWP_SHOWWINDOW);
        InvalidateRect(m_hwnd, nullptr, TRUE);
    }
}

void MicOverlay::OnPaint(HWND hwnd) {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);

    RECT rc;
    GetClientRect(hwnd, &rc);
    int w = rc.right - rc.left;
    int h = rc.bottom - rc.top;

    UINT dpi = GetEffectiveDpi(hwnd);
    int radius = ScaleDpi(10, dpi);

    // Çift tamponlama (Flicker-free)
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBmp = CreateCompatibleBitmap(hdc, w, h);
    HGDIOBJ oldBmp = SelectObject(memDC, memBmp);

    // Koyu modern arka plan (#0E131F) ve kırmızı kenarlık (#EF4444)
    COLORREF bgCol = RGB(14, 19, 31);
    HBRUSH bgBrush = CreateSolidBrush(bgCol);
    HPEN borderPen = CreatePen(PS_SOLID, 1, RGB(239, 68, 68));

    HGDIOBJ oldBrush = SelectObject(memDC, bgBrush);
    HGDIOBJ oldPen   = SelectObject(memDC, borderPen);

    RoundRect(memDC, 0, 0, w, h, radius, radius);

    // Kırmızı canlı durum noktası (önce eski GDI nesnelerini geri yükle, sonra sil)
    HBRUSH redDotBrush = CreateSolidBrush(RGB(239, 68, 68));
    HGDIOBJ prevDotBrush = SelectObject(memDC, redDotBrush);
    HGDIOBJ prevDotPen   = SelectObject(memDC, GetStockObject(NULL_PEN));
    int dotX    = ScaleDpi(14, dpi);
    int dotSize = ScaleDpi(12, dpi);
    int dotY    = (h - dotSize) / 2;
    Ellipse(memDC, dotX, dotY, dotX + dotSize, dotY + dotSize);
    SelectObject(memDC, prevDotBrush);
    SelectObject(memDC, prevDotPen);
    DeleteObject(redDotBrush);

    // Metin çizimi
    HFONT font = CreateFontW(
        -MulDiv(9, static_cast<int>(dpi), 72),
        0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );
    HGDIOBJ oldFont = SelectObject(memDC, font);
    SetBkMode(memDC, TRANSPARENT);
    SetTextColor(memDC, RGB(252, 165, 165));

    RECT textRc = { ScaleDpi(34, dpi), 0, w - ScaleDpi(8, dpi), h };
    DrawTextW(memDC, L"MICROPHONE MUTED", -1, &textRc,
              DT_SINGLELINE | DT_VCENTER | DT_LEFT);

    // Ekrana aktar
    BitBlt(hdc, 0, 0, w, h, memDC, 0, 0, SRCCOPY);

    // Temizle
    SelectObject(memDC, oldFont);
    DeleteObject(font);
    SelectObject(memDC, oldPen);
    DeleteObject(borderPen);
    SelectObject(memDC, oldBrush);
    DeleteObject(bgBrush);
    SelectObject(memDC, oldBmp);
    DeleteObject(memBmp);
    DeleteDC(memDC);

    EndPaint(hwnd, &ps);
}

LRESULT CALLBACK MicOverlay::WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    MicOverlay* pThis = nullptr;
    if (msg == WM_NCCREATE) {
        auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
        pThis = static_cast<MicOverlay*>(cs->lpCreateParams);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(pThis));
    } else {
        pThis = reinterpret_cast<MicOverlay*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    }

    switch (msg) {
        case WM_WINDOWPOSCHANGING: {
            auto* pwp = reinterpret_cast<WINDOWPOS*>(lParam);
            if (pwp && !(pwp->flags & SWP_NOZORDER)) {
                pwp->hwndInsertAfter = HWND_TOPMOST;
            }
            break;
        }

        case WM_DPICHANGED:
            if (pThis) {
                pThis->UpdateLayout();
                InvalidateRect(hwnd, nullptr, TRUE);
                return 0;
            }
            break;

        case WM_PAINT:
            if (pThis) {
                pThis->OnPaint(hwnd);
                return 0;
            }
            break;

        case WM_ERASEBKGND:
            return 1; // Flicker engelle

        default:
            break;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}
