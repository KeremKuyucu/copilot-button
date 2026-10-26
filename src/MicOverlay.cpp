#include "MicOverlay.hpp"
#include <dwmapi.h>

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

static const wchar_t* OVERLAY_CLASS_NAME = L"CopilotMicOverlayClass";

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

    // Genişlik ~220px, yükseklik ~32px, sol üst köşe (x=20, y=15)
    int x = 20;
    int y = 15;
    int w = 220;
    int h = 32;

    m_hwnd = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_NOACTIVATE,
        OVERLAY_CLASS_NAME,
        L"CopilotMicOverlay",
        WS_POPUP,
        x, y, w, h,
        nullptr, nullptr, hInst, this
    );

    if (!m_hwnd) return false;

    // DWM & GDI köşe artıklarını önlemek için pencere bölgesini (Window Region)
    // yuvarlatılmış dikdörtgen olarak bağla (Windows hem pencereyi tam keser hem piksel sızdırmaz)
    HRGN hRgn = CreateRoundRectRgn(0, 0, w + 1, h + 1, 10, 10);
    if (hRgn) {
        SetWindowRgn(m_hwnd, hRgn, TRUE);
    }

    // Windows 11 DWM yuvarlatılmış köşe tercihi (DWMWCP_ROUND = 2)
    DWORD cornerPref = DWMWCP_ROUND;
    DwmSetWindowAttribute(m_hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &cornerPref, sizeof(cornerPref));

    // Saydamlık ayarı (240/255)
    SetLayeredWindowAttributes(m_hwnd, 0, 240, LWA_ALPHA);

    return true;
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
        // Ekran tazeleme: tüm pencere alanını geçersiz kıl
        InvalidateRect(m_hwnd, nullptr, TRUE);
        ShowWindow(m_hwnd, SW_SHOWNOACTIVATE);
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

void MicOverlay::OnPaint(HWND hwnd) {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);

    RECT rc;
    GetClientRect(hwnd, &rc);
    int w = rc.right - rc.left;
    int h = rc.bottom - rc.top;

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

    RoundRect(memDC, 0, 0, w, h, 10, 10);

    // Kırmızı canlı durum noktası (🔴)
    HBRUSH redDotBrush = CreateSolidBrush(RGB(239, 68, 68));
    SelectObject(memDC, redDotBrush);
    SelectObject(memDC, GetStockObject(NULL_PEN));
    Ellipse(memDC, 14, 10, 26, 22);
    DeleteObject(redDotBrush);

    // Metin çizimi
    HFONT font = CreateFontW(
        14, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );
    HGDIOBJ oldFont = SelectObject(memDC, font);
    SetBkMode(memDC, TRANSPARENT);
    SetTextColor(memDC, RGB(252, 165, 165));

    RECT textRc = { 34, 0, w - 8, h };
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
