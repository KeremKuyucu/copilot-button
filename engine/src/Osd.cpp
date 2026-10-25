// Osd.cpp – Eylem ve Spotify ekran bildirimleri (OSD)
#include "Osd.hpp"
#include <dwmapi.h>
#include <algorithm>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "dwmapi.lib")

// ─────────────────────────────────────────────
//  DWM Sabitleri
// ─────────────────────────────────────────────
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#  define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWCP_ROUND
#  define DWMWCP_ROUND 2
#endif

// ─────────────────────────────────────────────
//  Timer ID'leri
// ─────────────────────────────────────────────
static constexpr UINT_PTR TIMER_ID_TIP_FADE_IN  = 301;
static constexpr UINT_PTR TIMER_ID_TIP_HOLD     = 302;
static constexpr UINT_PTR TIMER_ID_TIP_FADE_OUT = 303;

static constexpr UINT_PTR TIMER_ID_SPOT_FADE_IN  = 304;
static constexpr UINT_PTR TIMER_ID_SPOT_HOLD     = 305;
static constexpr UINT_PTR TIMER_ID_SPOT_FADE_OUT = 306;

static const wchar_t* TIP_CLASS_NAME  = L"CopilotTipOsdClass";
static const wchar_t* SPOT_CLASS_NAME = L"CopilotSpotOsdClass";

OsdManager& OsdManager::Instance() {
    static OsdManager s_inst;
    return s_inst;
}

OsdManager::~OsdManager() {
    Destroy();
}

void OsdManager::Init(HWND hostWnd) {
    m_hostWnd = hostWnd;
}

void OsdManager::UpdateConfig(const Config& cfg) {
    m_cfg = cfg;
}

void OsdManager::Destroy() {
    if (m_tipHwnd) {
        DestroyWindow(m_tipHwnd);
        m_tipHwnd = nullptr;
    }
    if (m_spotHwnd) {
        DestroyWindow(m_spotHwnd);
        m_spotHwnd = nullptr;
    }
}

// ─────────────────────────────────────────────
//  Aksiyon Bildirimi (ShowTip)
// ─────────────────────────────────────────────
bool OsdManager::CreateTipWindow() {
    if (m_tipHwnd) return true;

    HINSTANCE hInst = GetModuleHandleW(nullptr);

    static bool s_tipClassRegistered = false;
    if (!s_tipClassRegistered) {
        WNDCLASSEXW wc   = {};
        wc.cbSize        = sizeof(wc);
        wc.hInstance     = hInst;
        wc.lpfnWndProc   = TipWndProc;
        wc.lpszClassName = TIP_CLASS_NAME;
        wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
        if (RegisterClassExW(&wc) || GetLastError() == ERROR_CLASS_ALREADY_EXISTS) {
            s_tipClassRegistered = true;
        }
    }

    m_tipHwnd = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_NOACTIVATE,
        TIP_CLASS_NAME,
        L"CopilotTipOSD",
        WS_POPUP,
        20, 55, 200, 36,
        nullptr, nullptr, hInst, this
    );

    if (!m_tipHwnd) return false;

    DWORD cornerPref = DWMWCP_ROUND;
    DwmSetWindowAttribute(m_tipHwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &cornerPref, sizeof(cornerPref));

    return true;
}

void OsdManager::PositionTipWindow(int textW, int textH) {
    int screenW = GetSystemMetrics(SM_CXSCREEN);
    int screenH = GetSystemMetrics(SM_CYSCREEN);

    int padX = 28;
    int padY = 14;
    m_tipWidth  = (std::max)(textW + padX, 140);
    m_tipHeight = (std::max)(textH + padY, 36);

    int x = 20;
    int y = 55;

    if (m_cfg.osdPosition == L"TopRight") {
        x = screenW - m_tipWidth - 24;
        y = 55;
    } else if (m_cfg.osdPosition == L"BottomLeft") {
        x = 24;
        y = screenH - m_tipHeight - 55;
    } else if (m_cfg.osdPosition == L"BottomRight") {
        x = screenW - m_tipWidth - 24;
        y = screenH - m_tipHeight - 55;
    } else if (m_cfg.osdPosition == L"Center") {
        x = (screenW - m_tipWidth) / 2;
        y = (screenH - m_tipHeight) / 2;
    } else {
        // TopLeft
        x = 20;
        y = 55;
    }

    SetWindowPos(m_tipHwnd, HWND_TOPMOST, x, y, m_tipWidth, m_tipHeight,
                 SWP_NOACTIVATE);

    // Pencere bölgesini yuvarlak köşeyle kırp (köşe artıklarını engeller)
    HRGN hRgn = CreateRoundRectRgn(0, 0, m_tipWidth + 1, m_tipHeight + 1, 10, 10);
    if (hRgn) SetWindowRgn(m_tipHwnd, hRgn, TRUE);
}

void OsdManager::ShowTip(const std::wstring& msg, DWORD durationMs) {
    if (msg.empty()) return;
    if (!m_tipHwnd) CreateTipWindow();
    if (!m_tipHwnd) return;

    m_tipText = msg;
    m_tipDuration = (durationMs > 0) ? durationMs : m_cfg.osdDurationMs;

    // Metin boyutunu hesapla
    HDC hdc = GetDC(m_tipHwnd);
    HFONT font = CreateFontW(
        -MulDiv(m_cfg.osdFontSize, GetDeviceCaps(hdc, LOGPIXELSY), 72),
        0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );
    HGDIOBJ oldFont = SelectObject(hdc, font);

    RECT calcRc = { 0, 0, 0, 0 };
    DrawTextW(hdc, m_tipText.c_str(), -1, &calcRc, DT_CALCRECT | DT_SINGLELINE);

    SelectObject(hdc, oldFont);
    DeleteObject(font);
    ReleaseDC(m_tipHwnd, hdc);

    PositionTipWindow(calcRc.right - calcRc.left, calcRc.bottom - calcRc.top);

    // Önceki zamanlayıcıları temizle
    KillTimer(m_tipHwnd, TIMER_ID_TIP_FADE_IN);
    KillTimer(m_tipHwnd, TIMER_ID_TIP_HOLD);
    KillTimer(m_tipHwnd, TIMER_ID_TIP_FADE_OUT);

    InvalidateRect(m_tipHwnd, nullptr, TRUE);
    ShowWindow(m_tipHwnd, SW_SHOWNOACTIVATE);
    UpdateWindow(m_tipHwnd);

    if (m_cfg.osdFadeEnabled) {
        m_tipAlpha = 0;
        SetLayeredWindowAttributes(m_tipHwnd, 0, 0, LWA_ALPHA);
        SetTimer(m_tipHwnd, TIMER_ID_TIP_FADE_IN, 15, nullptr);
    } else {
        m_tipAlpha = 240;
        SetLayeredWindowAttributes(m_tipHwnd, 0, 240, LWA_ALPHA);
        SetTimer(m_tipHwnd, TIMER_ID_TIP_HOLD, m_tipDuration, nullptr);
    }
}

void OsdManager::OnPaintTip(HWND hwnd) {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);

    RECT rc;
    GetClientRect(hwnd, &rc);
    int w = rc.right - rc.left;
    int h = rc.bottom - rc.top;

    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBmp = CreateCompatibleBitmap(hdc, w, h);
    HGDIOBJ oldBmp = SelectObject(memDC, memBmp);

    // Koyu modern arka plan (#121824) ve zarif kenarlık (#1E293B)
    HBRUSH bgBrush = CreateSolidBrush(RGB(18, 24, 36));
    HPEN borderPen = CreatePen(PS_SOLID, 1, RGB(30, 41, 59));
    HGDIOBJ oldBrush = SelectObject(memDC, bgBrush);
    HGDIOBJ oldPen   = SelectObject(memDC, borderPen);

    RoundRect(memDC, 0, 0, w, h, 10, 10);

    // Metin çizimi
    HFONT font = CreateFontW(
        -MulDiv(m_cfg.osdFontSize, GetDeviceCaps(memDC, LOGPIXELSY), 72),
        0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );
    HGDIOBJ oldFont = SelectObject(memDC, font);
    SetBkMode(memDC, TRANSPARENT);
    SetTextColor(memDC, m_cfg.osdColor);

    RECT textRc = { 14, 0, w - 14, h };
    DrawTextW(memDC, m_tipText.c_str(), -1, &textRc,
              DT_SINGLELINE | DT_VCENTER | DT_CENTER);

    BitBlt(hdc, 0, 0, w, h, memDC, 0, 0, SRCCOPY);

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

LRESULT CALLBACK OsdManager::TipWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    OsdManager* mgr = nullptr;
    if (msg == WM_NCCREATE) {
        auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
        mgr = static_cast<OsdManager*>(cs->lpCreateParams);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(mgr));
    } else {
        mgr = reinterpret_cast<OsdManager*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    }

    switch (msg) {
        case WM_PAINT:
            if (mgr) {
                mgr->OnPaintTip(hwnd);
                return 0;
            }
            break;

        case WM_ERASEBKGND:
            return 1;

        case WM_TIMER:
            if (mgr) {
                if (wParam == TIMER_ID_TIP_FADE_IN) {
                    mgr->m_tipAlpha += 35;
                    if (mgr->m_tipAlpha >= 240) {
                        mgr->m_tipAlpha = 240;
                        KillTimer(hwnd, TIMER_ID_TIP_FADE_IN);
                        SetTimer(hwnd, TIMER_ID_TIP_HOLD, mgr->m_tipDuration, nullptr);
                    }
                    SetLayeredWindowAttributes(hwnd, 0, static_cast<BYTE>(mgr->m_tipAlpha), LWA_ALPHA);
                    return 0;
                } else if (wParam == TIMER_ID_TIP_HOLD) {
                    KillTimer(hwnd, TIMER_ID_TIP_HOLD);
                    if (mgr->m_cfg.osdFadeEnabled) {
                        SetTimer(hwnd, TIMER_ID_TIP_FADE_OUT, 15, nullptr);
                    } else {
                        ShowWindow(hwnd, SW_HIDE);
                    }
                    return 0;
                } else if (wParam == TIMER_ID_TIP_FADE_OUT) {
                    mgr->m_tipAlpha -= 30;
                    if (mgr->m_tipAlpha <= 0) {
                        mgr->m_tipAlpha = 0;
                        KillTimer(hwnd, TIMER_ID_TIP_FADE_OUT);
                        ShowWindow(hwnd, SW_HIDE);
                    }
                    SetLayeredWindowAttributes(hwnd, 0, static_cast<BYTE>(mgr->m_tipAlpha), LWA_ALPHA);
                    return 0;
                }
            }
            break;

        default:
            break;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

// ─────────────────────────────────────────────
//  Spotify Şarkı Değişim Bildirimi
// ─────────────────────────────────────────────
bool OsdManager::CreateSpotWindow() {
    if (m_spotHwnd) return true;

    HINSTANCE hInst = GetModuleHandleW(nullptr);

    static bool s_spotClassRegistered = false;
    if (!s_spotClassRegistered) {
        WNDCLASSEXW wc   = {};
        wc.cbSize        = sizeof(wc);
        wc.hInstance     = hInst;
        wc.lpfnWndProc   = SpotWndProc;
        wc.lpszClassName = SPOT_CLASS_NAME;
        wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
        if (RegisterClassExW(&wc) || GetLastError() == ERROR_CLASS_ALREADY_EXISTS) {
            s_spotClassRegistered = true;
        }
    }

    int w = 360;
    int h = 74;

    m_spotHwnd = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_NOACTIVATE,
        SPOT_CLASS_NAME,
        L"CopilotSpotOSD",
        WS_POPUP,
        24, 55, w, h,
        nullptr, nullptr, hInst, this
    );

    if (!m_spotHwnd) return false;

    DWORD cornerPref = DWMWCP_ROUND;
    DwmSetWindowAttribute(m_spotHwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &cornerPref, sizeof(cornerPref));

    HRGN hRgn = CreateRoundRectRgn(0, 0, w + 1, h + 1, 10, 10);
    if (hRgn) SetWindowRgn(m_spotHwnd, hRgn, TRUE);

    return true;
}

void OsdManager::PositionSpotWindow() {
    int screenW = GetSystemMetrics(SM_CXSCREEN);
    int screenH = GetSystemMetrics(SM_CYSCREEN);

    int w = 360;
    int h = 74;
    int x = 24;
    int y = 55;

    if (m_cfg.osdPosition == L"TopRight") {
        x = screenW - w - 24;
        y = 55;
    } else if (m_cfg.osdPosition == L"BottomLeft") {
        x = 24;
        y = screenH - h - 55;
    } else if (m_cfg.osdPosition == L"BottomRight") {
        x = screenW - w - 24;
        y = screenH - h - 55;
    } else if (m_cfg.osdPosition == L"Center") {
        x = (screenW - w) / 2;
        y = (screenH - h) / 2;
    } else {
        // TopLeft
        x = 24;
        y = 55;
    }

    SetWindowPos(m_spotHwnd, HWND_TOPMOST, x, y, w, h, SWP_NOACTIVATE);
}

void OsdManager::ShowSpotifyTrack(const std::wstring& songTitle,
                                  const std::wstring& artistName,
                                  DWORD durationMs) {
    if (!m_spotHwnd) CreateSpotWindow();
    if (!m_spotHwnd) return;

    // Şarkı adını kısalt (max 34 karakter)
    std::wstring title = (!songTitle.empty()) ? songTitle : L"Bilinmeyen Parça";
    if (title.length() > 34) {
        title = title.substr(0, 32) + L"...";
    }
    m_spotTitle = title;

    // Sanatçı adını kısalt (max 42 karakter)
    std::wstring artist = (!artistName.empty()) ? artistName : L"Spotify";
    if (artist.length() > 42) {
        artist = artist.substr(0, 40) + L"...";
    }
    m_spotArtist = artist;

    m_spotDuration = (durationMs > 0) ? durationMs : (std::max)(m_cfg.osdDurationMs, static_cast<DWORD>(2800));

    PositionSpotWindow();

    KillTimer(m_spotHwnd, TIMER_ID_SPOT_FADE_IN);
    KillTimer(m_spotHwnd, TIMER_ID_SPOT_HOLD);
    KillTimer(m_spotHwnd, TIMER_ID_SPOT_FADE_OUT);

    InvalidateRect(m_spotHwnd, nullptr, TRUE);
    ShowWindow(m_spotHwnd, SW_SHOWNOACTIVATE);
    UpdateWindow(m_spotHwnd);

    if (m_cfg.osdFadeEnabled) {
        m_spotAlpha = 0;
        SetLayeredWindowAttributes(m_spotHwnd, 0, 0, LWA_ALPHA);
        SetTimer(m_spotHwnd, TIMER_ID_SPOT_FADE_IN, 15, nullptr);
    } else {
        m_spotAlpha = 245;
        SetLayeredWindowAttributes(m_spotHwnd, 0, 245, LWA_ALPHA);
        SetTimer(m_spotHwnd, TIMER_ID_SPOT_HOLD, m_spotDuration, nullptr);
    }
}

void OsdManager::OnPaintSpot(HWND hwnd) {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);

    RECT rc;
    GetClientRect(hwnd, &rc);
    int w = rc.right - rc.left;
    int h = rc.bottom - rc.top;

    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBmp = CreateCompatibleBitmap(hdc, w, h);
    HGDIOBJ oldBmp = SelectObject(memDC, memBmp);

    // Koyu modern arka plan (#0E131F) ve kenarlık (#1E293B)
    HBRUSH bgBrush = CreateSolidBrush(RGB(14, 19, 31));
    HPEN borderPen = CreatePen(PS_SOLID, 1, RGB(30, 41, 59));
    HGDIOBJ oldBrush = SelectObject(memDC, bgBrush);
    HGDIOBJ oldPen   = SelectObject(memDC, borderPen);

    RoundRect(memDC, 0, 0, w, h, 10, 10);

    // Sol kenar Spotify yeşili vurgu şeridi (#1DB954)
    HBRUSH greenBrush = CreateSolidBrush(RGB(29, 185, 84));
    RECT barRc = { 0, 0, 4, h };
    FillRect(memDC, &barRc, greenBrush);
    DeleteObject(greenBrush);

    SetBkMode(memDC, TRANSPARENT);

    // İkon: 🎧
    HFONT iconFont = CreateFontW(
        22, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI Emoji"
    );
    HGDIOBJ oldFont = SelectObject(memDC, iconFont);
    SetTextColor(memDC, RGB(29, 185, 84));
    RECT iconRc = { 14, 18, 46, 56 };
    DrawTextW(memDC, L"🎧", -1, &iconRc, DT_SINGLELINE | DT_CENTER | DT_VCENTER);
    SelectObject(memDC, oldFont);
    DeleteObject(iconFont);

    // Rozet Başlığı: SPOTIFY • ŞİMDİ ÇALIYOR
    HFONT badgeFont = CreateFontW(
        11, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );
    oldFont = SelectObject(memDC, badgeFont);
    SetTextColor(memDC, RGB(29, 185, 84));
    RECT badgeRc = { 54, 10, w - 10, 24 };
    DrawTextW(memDC, L"SPOTIFY  •  ŞİMDİ ÇALIYOR", -1, &badgeRc, DT_SINGLELINE | DT_LEFT);
    SelectObject(memDC, oldFont);
    DeleteObject(badgeFont);

    // Şarkı Adı (Bold, Beyaz)
    HFONT titleFont = CreateFontW(
        15, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );
    oldFont = SelectObject(memDC, titleFont);
    SetTextColor(memDC, RGB(255, 255, 255));
    RECT titleRc = { 54, 26, w - 12, 48 };
    DrawTextW(memDC, m_spotTitle.c_str(), -1, &titleRc, DT_SINGLELINE | DT_LEFT | DT_VCENTER);
    SelectObject(memDC, oldFont);
    DeleteObject(titleFont);

    // Sanatçı Adı (#94A3B8 Slate 400)
    HFONT artistFont = CreateFontW(
        13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );
    oldFont = SelectObject(memDC, artistFont);
    SetTextColor(memDC, RGB(148, 163, 184));
    RECT artistRc = { 54, 49, w - 12, 68 };
    DrawTextW(memDC, m_spotArtist.c_str(), -1, &artistRc, DT_SINGLELINE | DT_LEFT | DT_VCENTER);
    SelectObject(memDC, oldFont);
    DeleteObject(artistFont);

    BitBlt(hdc, 0, 0, w, h, memDC, 0, 0, SRCCOPY);

    SelectObject(memDC, oldPen);
    DeleteObject(borderPen);
    SelectObject(memDC, oldBrush);
    DeleteObject(bgBrush);
    SelectObject(memDC, oldBmp);
    DeleteObject(memBmp);
    DeleteDC(memDC);

    EndPaint(hwnd, &ps);
}

LRESULT CALLBACK OsdManager::SpotWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    OsdManager* mgr = nullptr;
    if (msg == WM_NCCREATE) {
        auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
        mgr = static_cast<OsdManager*>(cs->lpCreateParams);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(mgr));
    } else {
        mgr = reinterpret_cast<OsdManager*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    }

    switch (msg) {
        case WM_PAINT:
            if (mgr) {
                mgr->OnPaintSpot(hwnd);
                return 0;
            }
            break;

        case WM_ERASEBKGND:
            return 1;

        case WM_TIMER:
            if (mgr) {
                if (wParam == TIMER_ID_SPOT_FADE_IN) {
                    mgr->m_spotAlpha += 35;
                    if (mgr->m_spotAlpha >= 245) {
                        mgr->m_spotAlpha = 245;
                        KillTimer(hwnd, TIMER_ID_SPOT_FADE_IN);
                        SetTimer(hwnd, TIMER_ID_SPOT_HOLD, mgr->m_spotDuration, nullptr);
                    }
                    SetLayeredWindowAttributes(hwnd, 0, static_cast<BYTE>(mgr->m_spotAlpha), LWA_ALPHA);
                    return 0;
                } else if (wParam == TIMER_ID_SPOT_HOLD) {
                    KillTimer(hwnd, TIMER_ID_SPOT_HOLD);
                    if (mgr->m_cfg.osdFadeEnabled) {
                        SetTimer(hwnd, TIMER_ID_SPOT_FADE_OUT, 15, nullptr);
                    } else {
                        ShowWindow(hwnd, SW_HIDE);
                    }
                    return 0;
                } else if (wParam == TIMER_ID_SPOT_FADE_OUT) {
                    mgr->m_spotAlpha -= 25;
                    if (mgr->m_spotAlpha <= 0) {
                        mgr->m_spotAlpha = 0;
                        KillTimer(hwnd, TIMER_ID_SPOT_FADE_OUT);
                        ShowWindow(hwnd, SW_HIDE);
                    }
                    SetLayeredWindowAttributes(hwnd, 0, static_cast<BYTE>(mgr->m_spotAlpha), LWA_ALPHA);
                    return 0;
                }
            }
            break;

        default:
            break;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}
