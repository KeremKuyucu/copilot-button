// Osd.cpp – Eylem ve Spotify ekran bildirimleri (OSD)
#include "Osd.hpp"
#include "Audio.hpp"
#include <dwmapi.h>
#include <shellapi.h>
#include <windowsx.h>
#include <shlwapi.h>
#include <objbase.h>
#include <oleauto.h>
#include <uiautomationclient.h>
#include <gdiplus.h>
#include <algorithm>
#include <chrono>
#include <climits>
#include <cwctype>
#include <memory>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "msimg32.lib")

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
static constexpr UINT_PTR TIMER_ID_TIP_FADE_IN   = 301;
static constexpr UINT_PTR TIMER_ID_TIP_HOLD      = 302;
static constexpr UINT_PTR TIMER_ID_TIP_FADE_OUT  = 303;

static constexpr UINT_PTR TIMER_ID_MEDIA_FADE_IN  = 304;
static constexpr UINT_PTR TIMER_ID_MEDIA_HOLD     = 305;
static constexpr UINT_PTR TIMER_ID_MEDIA_FADE_OUT = 306;

static const wchar_t* TIP_CLASS_NAME   = L"CopilotTipOsdClass";
static const wchar_t* MEDIA_CLASS_NAME = L"CopilotMediaOsdClass";
static constexpr COLORREF MEDIA_COLOR_KEY = RGB(12, 16, 20);
static constexpr UINT WM_USER_TASKBAR_LAYOUT_CHANGED = WM_USER + 106;

static HWINEVENTHOOK s_hForegroundHook = nullptr;
static HWINEVENTHOOK s_hTaskbarHook    = nullptr;
static HWINEVENTHOOK s_hMoveSizeHook   = nullptr;

static void CALLBACK ForegroundEventProc(HWINEVENTHOOK, DWORD, HWND, LONG, LONG, DWORD, DWORD) {
    OsdManager::Instance().CheckFullscreenAndTaskbarState();
    OsdManager::Instance().RefreshTaskbarLayout(80);
}

static void CALLBACK TaskbarEventProc(HWINEVENTHOOK, DWORD, HWND, LONG, LONG, DWORD, DWORD) {
    OsdManager::Instance().CheckFullscreenAndTaskbarState();
    OsdManager::Instance().RefreshTaskbarLayout(80);
}

static void CALLBACK MoveSizeEventProc(HWINEVENTHOOK, DWORD, HWND, LONG, LONG, DWORD, DWORD) {
    OsdManager::Instance().CheckFullscreenAndTaskbarState();
    OsdManager::Instance().RefreshTaskbarLayout(80);
}

static void HookTaskbarEvents() {
    if (s_hTaskbarHook) {
        UnhookWinEvent(s_hTaskbarHook);
        s_hTaskbarHook = nullptr;
    }

    HWND hTaskbar = FindWindowW(L"Shell_TrayWnd", nullptr);
    if (hTaskbar) {
        DWORD tbPid = 0;
        DWORD tbTid = GetWindowThreadProcessId(hTaskbar, &tbPid);
        if (tbPid && tbTid) {
            // Görev çubuğu thread'inden gelen create/destroy/show/hide/locationchange (0x8000 - 0x800B) olaylarını yakala
            s_hTaskbarHook = SetWinEventHook(
                EVENT_OBJECT_CREATE, EVENT_OBJECT_LOCATIONCHANGE,
                nullptr, TaskbarEventProc,
                tbPid, tbTid,
                WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS
            );
        }
    }
}

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

struct MediaMetrics {
    int thumbX;
    int thumbSize;
    int thumbRadius;
    int textGapL;
    int textGapR;
    int btnW;
    int btnH;
    int playW;
    int playH;
    int btnGap;
    int compactGap;
    int compactThumbGap;
    int padR;

    int FullChromeW() const {
        return thumbX + thumbSize + textGapL + textGapR + btnW + btnGap + playW + btnGap + btnW + padR;
    }
    int CompactControlsW() const {
        return thumbX + thumbSize + compactThumbGap + btnW + compactGap + playW + compactGap + btnW + padR;
    }
    int MiniPlayW() const {
        return thumbX + thumbSize + compactGap + playW + padR;
    }
};

static MediaMetrics GetMediaMetrics(UINT dpi) {
    MediaMetrics m{};
    m.thumbX          = ScaleDpi(6, dpi);
    m.thumbSize       = ScaleDpi(26, dpi);
    m.thumbRadius     = ScaleDpi(5, dpi);
    m.textGapL        = ScaleDpi(8, dpi);
    m.textGapR        = ScaleDpi(8, dpi);
    m.btnW            = ScaleDpi(22, dpi);
    m.btnH            = ScaleDpi(22, dpi);
    m.playW           = ScaleDpi(24, dpi);
    m.playH           = ScaleDpi(24, dpi);
    m.btnGap          = ScaleDpi(6, dpi);
    m.compactGap      = ScaleDpi(4, dpi);
    m.compactThumbGap = ScaleDpi(6, dpi);
    m.padR            = ScaleDpi(4, dpi);
    return m;
}

static HBITMAP DecodeThumbnail(const std::vector<uint8_t>& data, int targetW, int targetH) {
    if (data.empty()) return nullptr;

    IStream* pStream = SHCreateMemStream(data.data(), static_cast<UINT>(data.size()));
    if (!pStream) return nullptr;

    std::unique_ptr<Gdiplus::Bitmap> bmp(Gdiplus::Bitmap::FromStream(pStream));
    HBITMAP hResult = nullptr;
    if (bmp && bmp->GetLastStatus() == Gdiplus::Ok) {
        HDC hdcScreen = GetDC(nullptr);
        HDC hdcMem = CreateCompatibleDC(hdcScreen);
        hResult = CreateCompatibleBitmap(hdcScreen, targetW, targetH);
        HGDIOBJ oldBmp = SelectObject(hdcMem, hResult);

        Gdiplus::Graphics g(hdcMem);
        g.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
        g.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHalf);
        g.DrawImage(bmp.get(), 0, 0, targetW, targetH);

        SelectObject(hdcMem, oldBmp);
        DeleteDC(hdcMem);
        ReleaseDC(nullptr, hdcScreen);
    }
    bmp.reset();
    pStream->Release();
    return hResult;
}

OsdManager& OsdManager::Instance() {
    static OsdManager s_inst;
    return s_inst;
}

OsdManager::~OsdManager() {
    Destroy();
}

void OsdManager::Init(HWND hostWnd) {
    m_hostWnd = hostWnd;

    static ULONG_PTR s_gdiplusToken = 0;
    if (!s_gdiplusToken) {
        Gdiplus::GdiplusStartupInput gsi;
        Gdiplus::GdiplusStartup(&s_gdiplusToken, &gsi, nullptr);
    }

    if (!s_hForegroundHook) {
        s_hForegroundHook = SetWinEventHook(
            EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND,
            nullptr, ForegroundEventProc,
            0, 0, WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS
        );
    }

    if (!s_hMoveSizeHook) {
        s_hMoveSizeHook = SetWinEventHook(
            EVENT_SYSTEM_MOVESIZEEND, EVENT_SYSTEM_MOVESIZEEND,
            nullptr, MoveSizeEventProc,
            0, 0, WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS
        );
    }

    HookTaskbarEvents();

    if (m_hostWnd) {
        APPBARDATA abd = { sizeof(abd) };
        abd.hWnd = m_hostWnd;
        abd.uCallbackMessage = WM_USER + 104; // WM_USER_APPBAR_NOTIFY
        SHAppBarMessage(ABM_NEW, &abd);
    }

    StartTaskbarProbe();
    RefreshTaskbarLayout(0);
}

void OsdManager::OnTaskbarRecreated() {
    HookTaskbarEvents();
    RefreshTaskbarLayout(150);
    CheckFullscreenAndTaskbarState();
}

void OsdManager::UpdateConfig(const Config& cfg) {
    m_cfg = cfg;
    m_probeActive.store(m_hasActiveMedia && m_cfg.mediaOsdPersistent && !m_suppressedByFullscreen);
    if (m_mediaHwnd) {
        if (m_cfg.mediaOsdPersistent && m_hasActiveMedia) {
            CheckFullscreenAndTaskbarState();
        }
    }
}

void OsdManager::Destroy() {
    StopTaskbarProbe();
    if (m_hostWnd) {
        APPBARDATA abd = { sizeof(abd) };
        abd.hWnd = m_hostWnd;
        SHAppBarMessage(ABM_REMOVE, &abd);
    }
    if (s_hForegroundHook) {
        UnhookWinEvent(s_hForegroundHook);
        s_hForegroundHook = nullptr;
    }
    if (s_hMoveSizeHook) {
        UnhookWinEvent(s_hMoveSizeHook);
        s_hMoveSizeHook = nullptr;
    }
    if (s_hTaskbarHook) {
        UnhookWinEvent(s_hTaskbarHook);
        s_hTaskbarHook = nullptr;
    }
    if (m_tipHwnd) {
        DestroyWindow(m_tipHwnd);
        m_tipHwnd = nullptr;
    }
    if (m_mediaHwnd) {
        KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_IN);
        KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_HOLD);
        KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_OUT);
        DestroyWindow(m_mediaHwnd);
        m_mediaHwnd = nullptr;
    }
    if (m_mediaThumbBmp) {
        DeleteObject(m_mediaThumbBmp);
        m_mediaThumbBmp = nullptr;
    }
    m_mediaThumbSize = 0;
    m_mediaThumbData.clear();
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
    UINT dpi = GetEffectiveDpi(m_tipHwnd);

    RECT workArea = {};
    if (!SystemParametersInfoW(SPI_GETWORKAREA, 0, &workArea, 0)) {
        workArea.left   = 0;
        workArea.top    = 0;
        workArea.right  = GetSystemMetrics(SM_CXSCREEN);
        workArea.bottom = GetSystemMetrics(SM_CYSCREEN);
    }

    int workW = workArea.right - workArea.left;
    int workH = workArea.bottom - workArea.top;

    int padX = ScaleDpi(28, dpi);
    int padY = ScaleDpi(14, dpi);
    m_tipWidth  = (std::max)(textW + padX, ScaleDpi(140, dpi));
    m_tipHeight = (std::max)(textH + padY, ScaleDpi(36, dpi));

    int offXLeft  = ScaleDpi(20, dpi);
    int offXSide  = ScaleDpi(24, dpi);
    int offYTop   = ScaleDpi(55, dpi);
    int offYBot   = ScaleDpi(12, dpi);

    int x = workArea.left + offXLeft;
    int y = workArea.top + offYTop;

    if (m_cfg.osdPosition == L"TopRight") {
        x = workArea.right - m_tipWidth - offXSide;
        y = workArea.top + offYTop;
    } else if (m_cfg.osdPosition == L"BottomLeft") {
        x = workArea.left + offXSide;
        y = workArea.bottom - m_tipHeight - offYBot;
    } else if (m_cfg.osdPosition == L"BottomRight") {
        x = workArea.right - m_tipWidth - offXSide;
        y = workArea.bottom - m_tipHeight - offYBot;
    } else if (m_cfg.osdPosition == L"Center") {
        x = workArea.left + (workW - m_tipWidth) / 2;
        y = workArea.top + (workH - m_tipHeight) / 2;
    } else {
        // TopLeft
        x = workArea.left + offXLeft;
        y = workArea.top + offYTop;
    }

    SetWindowPos(m_tipHwnd, HWND_TOPMOST, x, y, m_tipWidth, m_tipHeight,
                 SWP_NOACTIVATE);

    // Pencere bölgesini yuvarlak köşeyle kırp (köşe artıklarını engeller)
    int radius = ScaleDpi(10, dpi);
    HRGN hRgn = CreateRoundRectRgn(0, 0, m_tipWidth + 1, m_tipHeight + 1, radius, radius);
    if (hRgn) SetWindowRgn(m_tipHwnd, hRgn, TRUE);
}

void OsdManager::ShowTip(const std::wstring& msg, DWORD durationMs) {
    if (msg.empty()) return;
    if (!m_tipHwnd) CreateTipWindow();
    if (!m_tipHwnd) return;

    m_tipText = msg;
    m_tipDuration = (durationMs > 0) ? durationMs : m_cfg.osdDurationMs;

    UINT dpi = GetEffectiveDpi(m_tipHwnd);

    // Metin boyutunu hesapla
    HDC hdc = GetDC(m_tipHwnd);
    HFONT font = CreateFontW(
        -MulDiv(m_cfg.osdFontSize, static_cast<int>(dpi), 72),
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

    UINT dpi = GetEffectiveDpi(hwnd);
    int radius = ScaleDpi(10, dpi);
    int insetX = ScaleDpi(14, dpi);

    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBmp = CreateCompatibleBitmap(hdc, w, h);
    HGDIOBJ oldBmp = SelectObject(memDC, memBmp);

    // Koyu modern arka plan (#121824) ve zarif kenarlık (#1E293B)
    HBRUSH bgBrush = CreateSolidBrush(RGB(18, 24, 36));
    HPEN borderPen = CreatePen(PS_SOLID, 1, RGB(30, 41, 59));
    HGDIOBJ oldBrush = SelectObject(memDC, bgBrush);
    HGDIOBJ oldPen   = SelectObject(memDC, borderPen);

    RoundRect(memDC, 0, 0, w, h, radius, radius);

    // Metin çizimi
    HFONT font = CreateFontW(
        -MulDiv(m_cfg.osdFontSize, static_cast<int>(dpi), 72),
        0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );
    HGDIOBJ oldFont = SelectObject(memDC, font);
    SetBkMode(memDC, TRANSPARENT);
    SetTextColor(memDC, m_cfg.osdColor);

    RECT textRc = { insetX, 0, w - insetX, h };
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
//  Medya Şarkı Kartı Bildirimi
// ─────────────────────────────────────────────
bool OsdManager::CreateMediaWindow() {
    if (m_mediaHwnd) return true;

    HINSTANCE hInst = GetModuleHandleW(nullptr);

    static bool s_mediaClassRegistered = false;
    if (!s_mediaClassRegistered) {
        WNDCLASSEXW wc   = {};
        wc.cbSize        = sizeof(wc);
        wc.hInstance     = hInst;
        wc.lpfnWndProc   = MediaWndProc;
        wc.lpszClassName = MEDIA_CLASS_NAME;
        wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
        if (RegisterClassExW(&wc) || GetLastError() == ERROR_CLASS_ALREADY_EXISTS) {
            s_mediaClassRegistered = true;
        }
    }

    int w = 220;
    int h = 34;

    HWND hTaskbar = FindWindowW(L"Shell_TrayWnd", nullptr);

    m_mediaHwnd = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_NOACTIVATE,
        MEDIA_CLASS_NAME,
        L"CopilotMediaOSD",
        WS_POPUP,
        20, 55, w, h,
        hTaskbar, nullptr, hInst, this
    );

    if (!m_mediaHwnd) return false;

    DWORD cornerPref = 1; // DWMWCP_DONOTROUND
    DwmSetWindowAttribute(m_mediaHwnd, 33 /* DWMWA_WINDOW_CORNER_PREFERENCE */, &cornerPref, sizeof(cornerPref));
    COLORREF borderNone = 0xFFFFFFFE; // DWMWA_COLOR_NONE
    DwmSetWindowAttribute(m_mediaHwnd, 34 /* DWMWA_BORDER_COLOR */, &borderNone, sizeof(borderNone));

    return true;
}

// ─────────────────────────────────────────────
//  Tam Ekran ve Görev Çubuğu Algılama
// ─────────────────────────────────────────────
bool OsdManager::IsFullscreenAppActive(HWND selfWnd) {
    HWND fg = GetForegroundWindow();
    if (!fg || fg == GetDesktopWindow() || fg == GetShellWindow() || fg == selfWnd) {
        return false;
    }

    // Windows Shell (Görev çubuğu, Başlat menüsü, Bildirimler vb.) süreç kontrolü
    DWORD fgPid = 0;
    GetWindowThreadProcessId(fg, &fgPid);

    DWORD shellPid = 0;
    HWND hShell = GetShellWindow();
    if (hShell) GetWindowThreadProcessId(hShell, &shellPid);
    else {
        HWND hTb = FindWindowW(L"Shell_TrayWnd", nullptr);
        if (hTb) GetWindowThreadProcessId(hTb, &shellPid);
    }

    if (fgPid != 0 && (fgPid == shellPid || fgPid == GetCurrentProcessId())) {
        return false;
    }

    // Masaüstü veya Windows kabuk pencerelerini tam ekran sayma
    wchar_t cls[64] = { 0 };
    if (GetClassNameW(fg, cls, 64)) {
        if (wcscmp(cls, L"Progman") == 0 ||
            wcscmp(cls, L"WorkerW") == 0 ||
            wcscmp(cls, L"Shell_TrayWnd") == 0 ||
            wcscmp(cls, L"Shell_SecondaryTrayWnd") == 0 ||
            wcscmp(cls, L"Windows.UI.Core.CoreWindow") == 0 ||
            wcscmp(cls, L"XamlExplorerHostIslandWindow") == 0) {
            return false;
        }
    }

    if (IsIconic(fg) || !IsWindowVisible(fg)) {
        return false;
    }

    RECT rcWnd = {};
    if (!GetWindowRect(fg, &rcWnd)) {
        return false;
    }

    HMONITOR hMon = MonitorFromWindow(fg, MONITOR_DEFAULTTONEAREST);
    if (!hMon) return false;

    MONITORINFO mi = { sizeof(mi) };
    if (!GetMonitorInfoW(hMon, &mi)) {
        return false;
    }

    // Çoklu monitör: Yalnızca OSD'nin yer aldığı monitördeki tam ekran uygulamaları baz al
    if (selfWnd && IsWindow(selfWnd)) {
        HMONITOR hOsdMon = MonitorFromWindow(selfWnd, MONITOR_DEFAULTTOPRIMARY);
        if (hOsdMon && hMon != hOsdMon) {
            return false;
        }
    }

    // Pencere monitörün tamamını veya fazlasını kaplıyorsa tam ekrandır
    bool covers = (rcWnd.left <= mi.rcMonitor.left &&
                   rcWnd.top <= mi.rcMonitor.top &&
                   rcWnd.right >= mi.rcMonitor.right &&
                   rcWnd.bottom >= mi.rcMonitor.bottom);

    return covers;
}

bool OsdManager::IsTaskbarVisible() {
    HWND hTaskbar = FindWindowW(L"Shell_TrayWnd", nullptr);
    if (!hTaskbar || !IsWindowVisible(hTaskbar)) {
        return false;
    }

    RECT rcTb = {};
    if (!GetWindowRect(hTaskbar, &rcTb)) {
        return false;
    }

    int h = rcTb.bottom - rcTb.top;
    int w = rcTb.right - rcTb.left;
    if (h <= 4 || w <= 4) {
        return false;
    }

    // Görev çubuğunun ekran alanı kontrolü (otomatik gizlenme durumunda ekran dışına taşar)
    HMONITOR hMon = MonitorFromWindow(hTaskbar, MONITOR_DEFAULTTONEAREST);
    if (hMon) {
        MONITORINFO mi = { sizeof(mi) };
        if (GetMonitorInfoW(hMon, &mi)) {
            if (rcTb.bottom <= mi.rcMonitor.top + 4 ||
                rcTb.top >= mi.rcMonitor.bottom - 4 ||
                rcTb.right <= mi.rcMonitor.left + 4 ||
                rcTb.left >= mi.rcMonitor.right - 4) {
                return false;
            }
        }
    }

    // Görev çubuğunun üzerinde başka bir pencere (örneğin tam ekran oyun/video) var mı?
    POINT pt = { (rcTb.left + rcTb.right) / 2, (rcTb.top + rcTb.bottom) / 2 };
    HWND hTop = WindowFromPoint(pt);
    if (hTop) {
        HWND root = GetAncestor(hTop, GA_ROOT);
        HWND effective = root ? root : hTop;
        if (effective != hTaskbar && effective != Instance().m_mediaHwnd && effective != Instance().m_tipHwnd) {
            wchar_t cls[64] = {};
            GetClassNameW(effective, cls, 64);
            if (wcscmp(cls, L"Shell_TrayWnd") != 0 && wcscmp(cls, L"Shell_SecondaryTrayWnd") != 0) {
                return false;
            }
        }
    }

    return true;
}

// ─────────────────────────────────────────────
//  Arka Plan Görev Çubuğu Alanı Ölçümü (IUIAutomation)
// ─────────────────────────────────────────────
static bool ContainsCaseInsensitive(const std::wstring& haystack, const wchar_t* needle) {
    if (!needle || !*needle) return true;
    size_t nLen = wcslen(needle);
    if (haystack.size() < nLen) return false;
    for (size_t i = 0; i <= haystack.size() - nLen; ++i) {
        bool match = true;
        for (size_t j = 0; j < nLen; ++j) {
            if (towlower(haystack[i + j]) != towlower(needle[j])) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

static bool StartsWith(const std::wstring& s, const wchar_t* prefix) {
    if (!prefix) return false;
    size_t nLen = wcslen(prefix);
    return s.size() >= nLen && s.compare(0, nLen, prefix) == 0;
}

struct TaskbarProbeItem {
    RECT rc{};
    bool isStart   = false;
    bool isWidgets = false;
    bool isTray    = false;
};

template <typename T>
struct TaskbarBoundsQueryHelper {
    static T Query(IUIAutomation* pUia, IUIAutomationCondition* pCond, IUIAutomationCacheRequest* pCacheReq) {
        T result{};

        HWND hTaskbar = FindWindowW(L"Shell_TrayWnd", nullptr);
        if (!hTaskbar || !IsWindowVisible(hTaskbar)) {
            return result;
        }

        RECT rcTb = {};
        if (!GetWindowRect(hTaskbar, &rcTb)) {
            return result;
        }

        int tbLeft  = rcTb.left;
        int tbRight = rcTb.right;
        int tbW     = tbRight - tbLeft;
        int tbH     = rcTb.bottom - rcTb.top;
        if (tbW <= tbH || tbW <= 200 || tbH <= 4) {
            return result;
        }

        UINT dpi = GetEffectiveDpi(hTaskbar);
        DWORD myPid = GetCurrentProcessId();

        int win32TrayLeft = INT_MAX;
        HWND hTrayNotify = FindWindowExW(hTaskbar, nullptr, L"TrayNotifyWnd", nullptr);
        if (hTrayNotify && IsWindowVisible(hTrayNotify)) {
            RECT rcTray = {};
            if (GetWindowRect(hTrayNotify, &rcTray) &&
                rcTray.left > tbLeft + tbW / 2 &&
                rcTray.right <= tbRight + 4) {
                win32TrayLeft = rcTray.left;
            }
        }

        std::vector<TaskbarProbeItem> items;
        bool hasStart = false;
        RECT startRect = {};
        int uiaTrayLeft = INT_MAX;

        IUIAutomationElement* pTbEl = nullptr;
        if (pUia && pCond && pCacheReq &&
            SUCCEEDED(pUia->ElementFromHandle(reinterpret_cast<UIA_HWND>(hTaskbar), &pTbEl)) && pTbEl) {
            IUIAutomationElementArray* pArr = nullptr;
            if (SUCCEEDED(pTbEl->FindAllBuildCache(TreeScope_Descendants, pCond, pCacheReq, &pArr)) && pArr) {
                int len = 0;
                if (SUCCEEDED(pArr->get_Length(&len)) && len > 0) {
                    items.reserve(static_cast<size_t>(len));
                    for (int i = 0; i < len; ++i) {
                        IUIAutomationElement* pEl = nullptr;
                        if (FAILED(pArr->GetElement(i, &pEl)) || !pEl) continue;

                        int pid = 0;
                        WINBOOL isOffscreen = FALSE;
                        RECT rc = {};
                        BSTR bstrAutoId = nullptr;
                        BSTR bstrCls    = nullptr;

                        pEl->get_CachedProcessId(&pid);
                        pEl->get_CachedIsOffscreen(&isOffscreen);
                        HRESULT hrRect = pEl->get_CachedBoundingRectangle(&rc);
                        pEl->get_CachedAutomationId(&bstrAutoId);
                        pEl->get_CachedClassName(&bstrCls);

                        std::wstring autoId = bstrAutoId ? bstrAutoId : L"";
                        std::wstring cls    = bstrCls ? bstrCls : L"";
                        if (bstrAutoId) SysFreeString(bstrAutoId);
                        if (bstrCls) SysFreeString(bstrCls);
                        pEl->Release();

                        if (pid == static_cast<int>(myPid)) continue;
                        if (isOffscreen == TRUE) continue;
                        if (FAILED(hrRect)) continue;
                        if (rc.right <= rc.left || rc.bottom <= rc.top) continue;
                        if (rc.left < tbLeft - 4 || rc.right > tbRight + 4) continue;
                        if (rc.bottom <= rcTb.top || rc.top >= rcTb.bottom) continue;
                        if ((rc.right - rc.left) > tbW / 2) continue;

                        TaskbarProbeItem item;
                        item.rc = rc;
                        item.isStart = (autoId == L"StartButton" || autoId == L"Start" || cls == L"Start");
                        item.isWidgets = (autoId == L"WidgetsButton" ||
                                          ContainsCaseInsensitive(autoId, L"widget") ||
                                          ContainsCaseInsensitive(cls, L"widget") ||
                                          ContainsCaseInsensitive(cls, L"augmentedentrypoint"));
                        item.isTray = (StartsWith(cls, L"SystemTray.") ||
                                       StartsWith(autoId, L"SystemTray") ||
                                       StartsWith(autoId, L"NotifyIcon") ||
                                       autoId == L"ShowDesktopButton" ||
                                       cls == L"TrayButton" ||
                                       cls == L"TrayClockWClass" ||
                                       cls == L"TrayShowDesktopButtonWClass");

                        if (item.isStart && !hasStart) {
                            hasStart = true;
                            startRect = rc;
                        }
                        if (item.isTray && rc.left > tbLeft + tbW / 2) {
                            uiaTrayLeft = (std::min)(uiaTrayLeft, static_cast<int>(rc.left));
                        }

                        items.push_back(std::move(item));
                    }
                }
                pArr->Release();
            }
            pTbEl->Release();
        }

        // Windows 10 için Win32 Start düğmesi yedeği
        if (!hasStart) {
            HWND hStart = FindWindowExW(hTaskbar, nullptr, L"Start", nullptr);
            if (hStart && IsWindowVisible(hStart) && GetWindowRect(hStart, &startRect)) {
                if (startRect.right > startRect.left && startRect.bottom > startRect.top) {
                    hasStart = true;
                }
            }
        }

        if (!hasStart) {
            return result;
        }

        int trayLeft = tbRight;
        if (uiaTrayLeft < INT_MAX && uiaTrayLeft > tbLeft + tbW / 2) {
            trayLeft = uiaTrayLeft;
        } else if (win32TrayLeft < INT_MAX) {
            trayLeft = win32TrayLeft;
        }

        bool isLeftAligned = (startRect.left <= tbLeft + ScaleDpi(80, dpi));

        int leftSlotLeft  = tbLeft;
        int leftSlotRight = startRect.left;
        int iconsRight    = startRect.right;

        for (const auto& item : items) {
            if (item.isTray) continue;
            const RECT& rc = item.rc;

            if (!isLeftAligned && rc.right <= startRect.left + 2) {
                if (item.isWidgets) {
                    leftSlotLeft = (std::max)(leftSlotLeft, static_cast<int>(rc.right));
                } else if (rc.left < tbLeft + ScaleDpi(200, dpi) &&
                           (startRect.left - rc.right) > ScaleDpi(16, dpi)) {
                    leftSlotLeft = (std::max)(leftSlotLeft, static_cast<int>(rc.right));
                } else {
                    leftSlotRight = (std::min)(leftSlotRight, static_cast<int>(rc.left));
                }
            } else if (rc.left >= startRect.left - 2 && rc.right <= trayLeft + 2) {
                iconsRight = (std::max)(iconsRight, static_cast<int>(rc.right));
            }
        }

        result.valid          = true;
        result.isLeftAligned  = isLeftAligned;
        result.tbRect         = rcTb;
        result.leftSlotLeft   = leftSlotLeft;
        result.leftSlotRight  = leftSlotRight;
        result.rightSlotLeft  = iconsRight;
        result.rightSlotRight = trayLeft;
        return result;
    }
};

void OsdManager::StartTaskbarProbe() {
    if (m_probeRunning.load()) return;
    {
        std::lock_guard<std::mutex> lk(m_probeWakeMutex);
        m_probeRequested  = false;
        m_probePending    = false;
        m_probeFirstReqMs = 0;
        m_probeRunAtMs    = 0;
    }
    m_probeRunning.store(true);
    m_probeThread = std::thread(&OsdManager::TaskbarProbeLoop, this);
}

void OsdManager::StopTaskbarProbe() {
    if (!m_probeRunning.exchange(false)) return;
    m_probeWakeCv.notify_all();
    if (m_probeThread.joinable()) {
        m_probeThread.join();
    }
    std::lock_guard<std::mutex> lk(m_tbBoundsMutex);
    m_tbBounds = {};
}

void OsdManager::RefreshTaskbarLayout(DWORD delayMs) {
    if (!m_probeRunning.load()) return;
    {
        std::lock_guard<std::mutex> lk(m_probeWakeMutex);
        ULONGLONG now = GetTickCount64();
        if (!m_probePending) {
            m_probePending    = true;
            m_probeFirstReqMs = now;
        }
        ULONGLONG target    = now + static_cast<ULONGLONG>(delayMs);
        ULONGLONG maxTarget = m_probeFirstReqMs + 250ULL;
        m_probeRunAtMs      = (std::min)(target, maxTarget);
        m_probeRequested    = true;
    }
    m_probeWakeCv.notify_one();
}

void OsdManager::TaskbarProbeLoop() {
    HRESULT hrCom = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    bool comInit = SUCCEEDED(hrCom);

    IUIAutomation* pUia = nullptr;
    IUIAutomationCondition* pCond = nullptr;
    IUIAutomationCacheRequest* pCacheReq = nullptr;

    if (SUCCEEDED(CoCreateInstance(__uuidof(CUIAutomation), nullptr, CLSCTX_INPROC_SERVER,
                                   __uuidof(IUIAutomation), reinterpret_cast<void**>(&pUia))) && pUia) {
        IUIAutomationCondition* pBtnCond = nullptr;
        IUIAutomationCondition* pEditCond = nullptr;

        VARIANT vBtn;
        VariantInit(&vBtn);
        vBtn.vt = VT_I4;
        vBtn.lVal = UIA_ButtonControlTypeId;
        if (SUCCEEDED(pUia->CreatePropertyCondition(UIA_ControlTypePropertyId, vBtn, &pBtnCond)) && pBtnCond) {
            VARIANT vEdit;
            VariantInit(&vEdit);
            vEdit.vt = VT_I4;
            vEdit.lVal = UIA_EditControlTypeId;
            if (SUCCEEDED(pUia->CreatePropertyCondition(UIA_ControlTypePropertyId, vEdit, &pEditCond)) && pEditCond) {
                if (FAILED(pUia->CreateOrCondition(pBtnCond, pEditCond, &pCond))) {
                    pCond = nullptr;
                }
            }
        }
        if (!pCond && pBtnCond) {
            pCond = pBtnCond;
            pCond->AddRef();
        }
        if (pBtnCond) pBtnCond->Release();
        if (pEditCond) pEditCond->Release();

        if (SUCCEEDED(pUia->CreateCacheRequest(&pCacheReq)) && pCacheReq) {
            pCacheReq->AddProperty(UIA_BoundingRectanglePropertyId);
            pCacheReq->AddProperty(UIA_AutomationIdPropertyId);
            pCacheReq->AddProperty(UIA_ClassNamePropertyId);
            pCacheReq->AddProperty(UIA_IsOffscreenPropertyId);
            pCacheReq->AddProperty(UIA_ProcessIdPropertyId);
        }
    }

    ULONGLONG expectedSettleAt = 0;

    while (m_probeRunning.load()) {
        bool shouldRunProbe = false;
        bool isSettlePass   = false;
        {
            std::unique_lock<std::mutex> lk(m_probeWakeMutex);
            for (;;) {
                if (!m_probeRunning.load()) break;

                if (m_probeRequested) {
                    ULONGLONG now = GetTickCount64();
                    if (now >= m_probeRunAtMs) {
                        isSettlePass = (expectedSettleAt != 0 && m_probeRunAtMs == expectedSettleAt);
                        expectedSettleAt = 0;
                        m_probeRequested = false;
                        m_probePending   = false;
                        shouldRunProbe   = true;
                        break;
                    }
                    ULONGLONG waitMs = m_probeRunAtMs - now;
                    m_probeWakeCv.wait_for(lk, std::chrono::milliseconds(waitMs));
                    continue;
                }

                if (m_probeActive.load()) {
                    auto status = m_probeWakeCv.wait_for(lk, std::chrono::milliseconds(1500));
                    if (!m_probeRunning.load()) break;
                    if (status == std::cv_status::timeout && !m_probeRequested && m_probeActive.load()) {
                        isSettlePass   = false;
                        shouldRunProbe = true;
                        break;
                    }
                } else {
                    m_probeWakeCv.wait(lk, [this]() {
                        return !m_probeRunning.load() || m_probeRequested || m_probeActive.load();
                    });
                }
            }
        }

        if (!m_probeRunning.load() || !shouldRunProbe) break;

        TaskbarFreeBounds fresh = TaskbarBoundsQueryHelper<TaskbarFreeBounds>::Query(pUia, pCond, pCacheReq);
        if (!m_probeRunning.load()) break;

        bool changed = false;
        {
            std::lock_guard<std::mutex> lk(m_tbBoundsMutex);
            if (fresh != m_tbBounds) {
                m_tbBounds = fresh;
                changed = true;
            }
        }

        if (changed) {
            if (m_hostWnd && IsWindow(m_hostWnd)) {
                PostMessageW(m_hostWnd, WM_USER_TASKBAR_LAYOUT_CHANGED, 0, 0);
            }
            if (!isSettlePass) {
                std::lock_guard<std::mutex> lk(m_probeWakeMutex);
                if (!m_probeRequested && m_probeRunning.load()) {
                    ULONGLONG now     = GetTickCount64();
                    m_probePending    = true;
                    m_probeFirstReqMs = now;
                    m_probeRunAtMs    = now + 260ULL;
                    m_probeRequested  = true;
                    expectedSettleAt  = m_probeRunAtMs;
                }
            }
        }
    }

    if (pCacheReq) pCacheReq->Release();
    if (pCond) pCond->Release();
    if (pUia) pUia->Release();
    if (comInit) CoUninitialize();
}

void OsdManager::OnTaskbarLayoutUpdated() {
    if (!m_mediaHwnd || !m_hasActiveMedia || m_mediaTitle.empty()) return;

    if (m_cfg.mediaOsdPersistent) {
        CheckFullscreenAndTaskbarState();
    } else if (IsWindowVisible(m_mediaHwnd)) {
        if (!PositionMediaWindow(m_mediaTextW, m_mediaHeight)) {
            KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_IN);
            KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_HOLD);
            KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_OUT);
            ShowWindow(m_mediaHwnd, SW_HIDE);
            m_mediaAlpha = 0;
            SetLayeredWindowAttributes(m_mediaHwnd, MEDIA_COLOR_KEY, 0, LWA_COLORKEY | LWA_ALPHA);
        }
    }
}

RECT OsdManager::GetNextBtnRect(int w, int h) const {
    if (m_mediaLayoutMode == MediaLayoutMode::MiniPlay) {
        return { 0, 0, 0, 0 };
    }
    MediaMetrics m = GetMediaMetrics(GetEffectiveDpi(m_mediaHwnd));
    int rightX = w - m.padR - m.btnW;
    int y      = (h - m.btnH) / 2;
    return { rightX, y, rightX + m.btnW, y + m.btnH };
}

RECT OsdManager::GetPlayBtnRect(int w, int h) const {
    MediaMetrics m = GetMediaMetrics(GetEffectiveDpi(m_mediaHwnd));
    int rightX = 0;
    if (m_mediaLayoutMode == MediaLayoutMode::MiniPlay) {
        rightX = w - m.padR - m.playW;
    } else {
        int gap = (m_mediaLayoutMode == MediaLayoutMode::CompactControls) ? m.compactGap : m.btnGap;
        rightX = w - m.padR - m.btnW - gap - m.playW;
    }
    int y = (h - m.playH) / 2;
    return { rightX, y, rightX + m.playW, y + m.playH };
}

RECT OsdManager::GetPrevBtnRect(int w, int h) const {
    if (m_mediaLayoutMode == MediaLayoutMode::MiniPlay) {
        return { 0, 0, 0, 0 };
    }
    MediaMetrics m = GetMediaMetrics(GetEffectiveDpi(m_mediaHwnd));
    int gap    = (m_mediaLayoutMode == MediaLayoutMode::CompactControls) ? m.compactGap : m.btnGap;
    int rightX = w - m.padR - m.btnW - gap - m.playW - gap - m.btnW;
    int y      = (h - m.btnH) / 2;
    return { rightX, y, rightX + m.btnW, y + m.btnH };
}

MediaCardButton OsdManager::HitTestMediaButton(int x, int y, int w, int h) const {
    POINT pt = { x, y };
    RECT rPlay = GetPlayBtnRect(w, h);
    if (PtInRect(&rPlay, pt)) return MediaCardButton::PlayPause;
    RECT rNext = GetNextBtnRect(w, h);
    if (PtInRect(&rNext, pt)) return MediaCardButton::Next;
    RECT rPrev = GetPrevBtnRect(w, h);
    if (PtInRect(&rPrev, pt)) return MediaCardButton::Prev;
    return MediaCardButton::None;
}

bool OsdManager::PositionMediaWindow(int textW, int textH) {
    (void)textH;
    m_mediaTextW = textW;
    UINT dpi = GetEffectiveDpi(m_mediaHwnd);
    MediaMetrics m = GetMediaMetrics(dpi);

    // Görev çubuğunun gerçek ekran koordinatlarını al
    HWND hTaskbar = FindWindowW(L"Shell_TrayWnd", nullptr);
    RECT rcTb = {};
    bool hasTb = (hTaskbar && GetWindowRect(hTaskbar, &rcTb) && (rcTb.bottom > rcTb.top));

    RECT workArea = {};
    if (!SystemParametersInfoW(SPI_GETWORKAREA, 0, &workArea, 0)) {
        workArea.left   = 0;
        workArea.top    = 0;
        workArea.right  = GetSystemMetrics(SM_CXSCREEN);
        workArea.bottom = GetSystemMetrics(SM_CYSCREEN);
    }

    int workW = workArea.right - workArea.left;
    int workH = workArea.bottom - workArea.top;

    int tbH = hasTb ? (rcTb.bottom - rcTb.top) : ScaleDpi(48, dpi);
    bool isHorizTb = hasTb && ((rcTb.right - rcTb.left) > tbH);

    // 2 satır metin ve kare thumbnail için hafif küçültülmüş DPI duyarlı yükseklik
    int newH = (tbH >= ScaleDpi(42, dpi)) ? ScaleDpi(34, dpi) : ScaleDpi(30, dpi);

    int effTextW     = (std::clamp)(textW, ScaleDpi(48, dpi), ScaleDpi(190, dpi));
    int preferredW   = effTextW + m.FullChromeW();
    int minFullW     = (std::min)(preferredW, m.FullChromeW() + ScaleDpi(44, dpi));
    int compactCtrlW = m.CompactControlsW();
    int miniPlayW    = m.MiniPlayW();

    std::wstring pos = m_cfg.mediaOsdPosition;
    if (pos.empty()) {
        pos = m_cfg.mediaOsdPersistent ? L"BottomLeft" : m_cfg.osdPosition;
    }

    int offXEdge = ScaleDpi(10, dpi);
    int offXGap  = ScaleDpi(8, dpi);
    int offX20   = ScaleDpi(20, dpi);
    int offX24   = ScaleDpi(24, dpi);
    int offY8    = ScaleDpi(8, dpi);
    int offY55   = ScaleDpi(55, dpi);

    auto SelectTier = [&](int availW, int& outW, MediaLayoutMode& outMode) -> bool {
        if (availW >= preferredW) {
            outMode = MediaLayoutMode::Full;
            outW = preferredW;
            return true;
        }
        if (availW >= minFullW) {
            outMode = MediaLayoutMode::Full;
            outW = availW;
            return true;
        }
        if (availW >= compactCtrlW) {
            outMode = MediaLayoutMode::CompactControls;
            outW = compactCtrlW;
            return true;
        }
        if (availW >= miniPlayW) {
            outMode = MediaLayoutMode::MiniPlay;
            outW = miniPlayW;
            return true;
        }
        return false;
    };

    MediaLayoutMode newMode = MediaLayoutMode::Full;
    int newW = preferredW;
    int x = (hasTb ? rcTb.left : workArea.left) + offXEdge;
    int y = hasTb ? (rcTb.top + (tbH - newH) / 2) : (workArea.bottom - newH - offY8);

    if ((pos == L"BottomLeft" || pos == L"BottomRight") && isHorizTb) {
        y = rcTb.top + (tbH - newH) / 2;

        TaskbarFreeBounds bounds;
        {
            std::lock_guard<std::mutex> lk(m_tbBoundsMutex);
            bounds = m_tbBounds;
        }

        if (bounds.valid && bounds.tbRect.left == rcTb.left && bounds.tbRect.right == rcTb.right) {
            int slotLeft  = 0;
            int slotRight = 0;

            if (pos == L"BottomLeft") {
                if (!bounds.isLeftAligned) {
                    slotLeft  = bounds.leftSlotLeft + ((bounds.leftSlotLeft > rcTb.left) ? offXGap : offXEdge);
                    slotRight = bounds.leftSlotRight - offXGap;
                } else {
                    slotLeft  = bounds.rightSlotLeft + offXGap;
                    slotRight = bounds.rightSlotRight - offXGap;
                }
            } else {
                slotLeft  = bounds.rightSlotLeft + offXGap;
                slotRight = bounds.rightSlotRight - offXGap;
            }

            int availW = slotRight - slotLeft;
            if (!SelectTier(availW, newW, newMode)) {
                return false;
            }
            x = (pos == L"BottomRight") ? (slotRight - newW) : slotLeft;
        } else {
            int maxFallbackW = (std::max)(miniPlayW, static_cast<int>((rcTb.right - rcTb.left) / 3));
            SelectTier(maxFallbackW, newW, newMode);
            x = (pos == L"BottomRight") ? (rcTb.right - newW - offX24) : (rcTb.left + offXEdge);
        }
    } else if (pos == L"BottomLeft") {
        x = (hasTb ? rcTb.left : workArea.left) + offXEdge;
        y = hasTb ? (rcTb.top + (tbH - newH) / 2) : (workArea.bottom - newH - offY8);
    } else if (pos == L"BottomRight") {
        x = (hasTb ? rcTb.right : workArea.right) - newW - offX24;
        y = hasTb ? (rcTb.top + (tbH - newH) / 2) : (workArea.bottom - newH - offY8);
    } else if (pos == L"Center") {
        x = workArea.left + (workW - newW) / 2;
        y = workArea.top + (workH - newH) / 2;
    } else if (pos == L"TopLeft") {
        x = workArea.left + offX20;
        y = workArea.top + offY55;
    } else if (pos == L"TopRight") {
        x = workArea.right - newW - offX24;
        y = workArea.top + offY55;
    }

    bool geomChanged = (x != m_mediaX || y != m_mediaY || newW != m_mediaWidth || newH != m_mediaHeight);
    bool modeChanged = (newMode != m_mediaLayoutMode);

    m_mediaX = x;
    m_mediaY = y;
    m_mediaWidth = newW;
    m_mediaHeight = newH;
    m_mediaLayoutMode = newMode;

    if (modeChanged) {
        m_hoveredMediaBtn = MediaCardButton::None;
    }

    if (geomChanged || modeChanged || !IsWindowVisible(m_mediaHwnd)) {
        SetWindowPos(m_mediaHwnd, HWND_TOPMOST, m_mediaX, m_mediaY, m_mediaWidth, m_mediaHeight, SWP_NOACTIVATE);
        // Şeffaf pencere: Herhangi bir DWM bölgesi kesimi yapılmaz, böylece dışta çizgi kalmaz
        SetWindowRgn(m_mediaHwnd, nullptr, TRUE);
        if (IsWindowVisible(m_mediaHwnd)) {
            InvalidateRect(m_mediaHwnd, nullptr, FALSE);
            UpdateWindow(m_mediaHwnd);
        }
    }

    return true;
}

void OsdManager::CheckFullscreenAndTaskbarState() {
    if (!m_mediaHwnd) return;
    if (!m_cfg.mediaOsdPersistent) {
        m_probeActive.store(false);
        return;
    }

    // Şarkı başlığı yoksa gizle
    if (m_mediaTitle.empty()) {
        m_probeActive.store(false);
        if (IsWindowVisible(m_mediaHwnd)) {
            HideMediaTrack();
        }
        return;
    }

    bool isFs = IsFullscreenAppActive(m_mediaHwnd);
    bool isTb = IsTaskbarVisible();
    m_probeActive.store(m_hasActiveMedia && m_cfg.mediaOsdPersistent && !isFs);

    bool hasRoom = (!isFs && isTb) ? PositionMediaWindow(m_mediaTextW, m_mediaHeight) : false;
    bool shouldShow = (!isFs && isTb && hasRoom);

    if (shouldShow) {
        bool wasSuppressed = (m_suppressedByFullscreen || m_suppressedBySpace);
        m_suppressedByFullscreen = false;
        m_suppressedBySpace = false;

        if (!IsWindowVisible(m_mediaHwnd) || wasSuppressed) {
            InvalidateRect(m_mediaHwnd, nullptr, TRUE);
            ShowWindow(m_mediaHwnd, SW_SHOWNOACTIVATE);
            UpdateWindow(m_mediaHwnd);

            if (m_cfg.osdFadeEnabled) {
                m_mediaAlpha = 0;
                SetLayeredWindowAttributes(m_mediaHwnd, MEDIA_COLOR_KEY, 0, LWA_COLORKEY | LWA_ALPHA);
                SetTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_IN, 15, nullptr);
            } else {
                m_mediaAlpha = 255;
                SetLayeredWindowAttributes(m_mediaHwnd, MEDIA_COLOR_KEY, 255, LWA_COLORKEY | LWA_ALPHA);
            }
        } else {
            // Görev çubuğuna tıklandığında veya arka plana itildiğinde daima en üstte tut
            SetWindowPos(m_mediaHwnd, HWND_TOPMOST, 0, 0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
        }
    } else {
        m_suppressedByFullscreen = (isFs || !isTb);
        m_suppressedBySpace = (!isFs && isTb && !hasRoom);
        if (IsWindowVisible(m_mediaHwnd)) {
            KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_IN);
            KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_HOLD);
            KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_OUT);
            ShowWindow(m_mediaHwnd, SW_HIDE);
            m_mediaAlpha = 0;
            SetLayeredWindowAttributes(m_mediaHwnd, MEDIA_COLOR_KEY, 0, LWA_COLORKEY | LWA_ALPHA);
        }
    }
}

void OsdManager::HideMediaTrack() {
    m_hasActiveMedia = false;
    m_suppressedByFullscreen = false;
    m_suppressedBySpace = false;
    m_probeActive.store(false);
    if (!m_mediaHwnd || !IsWindowVisible(m_mediaHwnd)) return;

    KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_IN);
    KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_HOLD);

    if (m_cfg.osdFadeEnabled) {
        SetTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_OUT, 15, nullptr);
    } else {
        ShowWindow(m_mediaHwnd, SW_HIDE);
        m_mediaAlpha = 0;
        SetLayeredWindowAttributes(m_mediaHwnd, MEDIA_COLOR_KEY, 0, LWA_COLORKEY | LWA_ALPHA);
    }
}

void OsdManager::ShowMediaTrack(const std::wstring& songTitle,
                                const std::wstring& artistName,
                                bool isPlaying,
                                DWORD durationMs,
                                const std::vector<uint8_t>& thumbnailData) {
    if (!m_mediaHwnd) CreateMediaWindow();
    if (!m_mediaHwnd) return;

    std::wstring title = (!songTitle.empty()) ? songTitle : L"Bilinmeyen Parça";
    std::wstring artist = (!artistName.empty()) ? artistName : L"Media";

    bool trackChanged = (m_mediaTitle != title || m_mediaArtist != artist);
    bool playChanged = (m_isMediaPlaying != isPlaying);
    bool thumbChanged = (m_mediaThumbData != thumbnailData);

    m_mediaTitle = title;
    m_mediaArtist = artist;
    m_isMediaPlaying = isPlaying;
    m_hasActiveMedia = true;

    UINT dpi = GetEffectiveDpi(m_mediaHwnd);
    MediaMetrics m = GetMediaMetrics(dpi);
    int thumbSize = m.thumbSize;
    bool thumbResize = (!thumbnailData.empty() && m_mediaThumbSize != thumbSize);

    if (thumbChanged || thumbResize) {
        m_mediaThumbData = thumbnailData;
        if (m_mediaThumbBmp) {
            DeleteObject(m_mediaThumbBmp);
            m_mediaThumbBmp = nullptr;
        }
        m_mediaThumbSize = 0;
        if (!m_mediaThumbData.empty()) {
            m_mediaThumbBmp = DecodeThumbnail(m_mediaThumbData, thumbSize, thumbSize);
            if (m_mediaThumbBmp) {
                m_mediaThumbSize = thumbSize;
            }
        }
    }

    m_mediaDuration = (durationMs > 0) ? durationMs : (std::max)(m_cfg.osdDurationMs, static_cast<DWORD>(2500));

    // İki satır metin genişliğini ölç
    HDC hdc = GetDC(m_mediaHwnd);
    HFONT fontTitle = CreateFontW(
        -ScaleDpi(12, dpi), 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );
    HFONT fontArtist = CreateFontW(
        -ScaleDpi(10, dpi), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );

    RECT rcT = { 0, 0, 0, 0 };
    HGDIOBJ oldF = SelectObject(hdc, fontTitle);
    DrawTextW(hdc, m_mediaTitle.c_str(), -1, &rcT, DT_CALCRECT | DT_SINGLELINE);
    int titleW = rcT.right - rcT.left;

    RECT rcA = { 0, 0, 0, 0 };
    SelectObject(hdc, fontArtist);
    DrawTextW(hdc, m_mediaArtist.c_str(), -1, &rcA, DT_CALCRECT | DT_SINGLELINE);
    int artistW = rcA.right - rcA.left;

    SelectObject(hdc, oldF);
    DeleteObject(fontTitle);
    DeleteObject(fontArtist);
    ReleaseDC(m_mediaHwnd, hdc);

    bool boundsValid = false;
    {
        std::lock_guard<std::mutex> lk(m_tbBoundsMutex);
        boundsValid = m_tbBounds.valid;
    }
    if (!boundsValid) {
        RefreshTaskbarLayout(0);
    }

    int textW = (std::clamp)((std::max)(titleW, artistW), ScaleDpi(48, dpi), ScaleDpi(190, dpi));
    bool hasRoom = PositionMediaWindow(textW, m_mediaHeight);

    if (m_cfg.mediaOsdPersistent) {
        bool isFs = IsFullscreenAppActive(m_mediaHwnd);
        bool isTb = IsTaskbarVisible();
        m_probeActive.store(m_hasActiveMedia && m_cfg.mediaOsdPersistent && !isFs);

        if (isFs || !isTb || !hasRoom) {
            m_suppressedByFullscreen = (isFs || !isTb);
            m_suppressedBySpace = (!isFs && isTb && !hasRoom);
            if (IsWindowVisible(m_mediaHwnd)) {
                KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_IN);
                KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_HOLD);
                KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_OUT);
                ShowWindow(m_mediaHwnd, SW_HIDE);
                m_mediaAlpha = 0;
                SetLayeredWindowAttributes(m_mediaHwnd, MEDIA_COLOR_KEY, 0, LWA_COLORKEY | LWA_ALPHA);
            }
            return;
        }

        bool wasSuppressed = (m_suppressedByFullscreen || m_suppressedBySpace);
        m_suppressedByFullscreen = false;
        m_suppressedBySpace = false;

        if (IsWindowVisible(m_mediaHwnd) && !wasSuppressed && !trackChanged && !playChanged && !thumbChanged && !thumbResize) {
            return;
        }

        if (IsWindowVisible(m_mediaHwnd) && !wasSuppressed && (trackChanged || playChanged || thumbChanged || thumbResize)) {
            InvalidateRect(m_mediaHwnd, nullptr, TRUE);
            UpdateWindow(m_mediaHwnd);
            return;
        }

        KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_IN);
        KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_HOLD);
        KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_OUT);

        InvalidateRect(m_mediaHwnd, nullptr, TRUE);
        ShowWindow(m_mediaHwnd, SW_SHOWNOACTIVATE);
        UpdateWindow(m_mediaHwnd);

        if (m_cfg.osdFadeEnabled) {
            m_mediaAlpha = 0;
            SetLayeredWindowAttributes(m_mediaHwnd, MEDIA_COLOR_KEY, 0, LWA_COLORKEY | LWA_ALPHA);
            SetTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_IN, 15, nullptr);
        } else {
            m_mediaAlpha = 255;
            SetLayeredWindowAttributes(m_mediaHwnd, MEDIA_COLOR_KEY, 255, LWA_COLORKEY | LWA_ALPHA);
        }
    } else {
        m_probeActive.store(false);
        if (!hasRoom) {
            if (IsWindowVisible(m_mediaHwnd)) {
                KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_IN);
                KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_HOLD);
                KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_OUT);
                ShowWindow(m_mediaHwnd, SW_HIDE);
                m_mediaAlpha = 0;
                SetLayeredWindowAttributes(m_mediaHwnd, MEDIA_COLOR_KEY, 0, LWA_COLORKEY | LWA_ALPHA);
            }
            return;
        }

        KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_IN);
        KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_HOLD);
        KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_OUT);

        InvalidateRect(m_mediaHwnd, nullptr, TRUE);
        ShowWindow(m_mediaHwnd, SW_SHOWNOACTIVATE);
        UpdateWindow(m_mediaHwnd);

        if (m_cfg.osdFadeEnabled) {
            m_mediaAlpha = 0;
            SetLayeredWindowAttributes(m_mediaHwnd, MEDIA_COLOR_KEY, 0, LWA_COLORKEY | LWA_ALPHA);
            SetTimer(m_mediaHwnd, TIMER_ID_MEDIA_FADE_IN, 15, nullptr);
        } else {
            m_mediaAlpha = 240;
            SetLayeredWindowAttributes(m_mediaHwnd, MEDIA_COLOR_KEY, 240, LWA_COLORKEY | LWA_ALPHA);
            SetTimer(m_mediaHwnd, TIMER_ID_MEDIA_HOLD, m_mediaDuration, nullptr);
        }
    }
}

void OsdManager::OnPaintMedia(HWND hwnd) {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);

    RECT rc;
    GetClientRect(hwnd, &rc);
    int w = rc.right - rc.left;
    int h = rc.bottom - rc.top;

    UINT dpi = GetEffectiveDpi(hwnd);
    MediaMetrics m = GetMediaMetrics(dpi);

    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBmp = CreateCompatibleBitmap(hdc, w, h);
    HGDIOBJ oldBmp = SelectObject(memDC, memBmp);

    // 1. Arka plan: Tamamen şeffaf (MEDIA_COLOR_KEY ile boyanır, LWA_COLORKEY sayesinde görünmez)
    HBRUSH bgBrush = CreateSolidBrush(MEDIA_COLOR_KEY);
    FillRect(memDC, &rc, bgBrush);
    DeleteObject(bgBrush);

    // 2. Sol Küçük Kare Albüm / Medya Rozeti (4-5px hafif yuvarlatılmış kare)
    int thumbSize   = m.thumbSize;
    int thumbX      = m.thumbX;
    int thumbY      = (h - thumbSize) / 2;
    int thumbRadius = m.thumbRadius;

    HRGN clipRgn = CreateRoundRectRgn(thumbX, thumbY, thumbX + thumbSize + 1, thumbY + thumbSize + 1, thumbRadius, thumbRadius);

    if (m_mediaThumbBmp) {
        // Şarkının gerçek albüm kapağı resmi
        HDC bmpDC = CreateCompatibleDC(memDC);
        HGDIOBJ oldThumb = SelectObject(bmpDC, m_mediaThumbBmp);

        SelectClipRgn(memDC, clipRgn);
        if (m_mediaThumbSize > 0 && m_mediaThumbSize != thumbSize) {
            SetStretchBltMode(memDC, HALFTONE);
            StretchBlt(memDC, thumbX, thumbY, thumbSize, thumbSize,
                       bmpDC, 0, 0, m_mediaThumbSize, m_mediaThumbSize, SRCCOPY);
        } else {
            BitBlt(memDC, thumbX, thumbY, thumbSize, thumbSize, bmpDC, 0, 0, SRCCOPY);
        }
        SelectClipRgn(memDC, nullptr);

        SelectObject(bmpDC, oldThumb);
        DeleteDC(bmpDC);
    } else {
        // Albüm kapağı yoksa zarif koyu arduvaz arkaplan
        HBRUSH thumbBg = CreateSolidBrush(RGB(24, 32, 47));
        HPEN thumbPen  = CreatePen(PS_SOLID, 1, RGB(45, 58, 78));
        HGDIOBJ oldTbB = SelectObject(memDC, thumbBg);
        HGDIOBJ oldTbP = SelectObject(memDC, thumbPen);
        RoundRect(memDC, thumbX, thumbY, thumbX + thumbSize, thumbY + thumbSize, thumbRadius, thumbRadius);
        SelectObject(memDC, oldTbB);
        SelectObject(memDC, oldTbP);
        DeleteObject(thumbBg);
        DeleteObject(thumbPen);

        if (m_isMediaPlaying) {
            SetBkMode(memDC, TRANSPARENT);
            HFONT noteFont = CreateFontW(
                -ScaleDpi(11, dpi), 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
                DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
                L"Segoe UI"
            );
            HGDIOBJ oldFont = SelectObject(memDC, noteFont);
            SetTextColor(memDC, RGB(226, 232, 240));
            RECT noteRc = { thumbX, thumbY, thumbX + thumbSize, thumbY + thumbSize };
            DrawTextW(memDC, L"♪", -1, &noteRc, DT_SINGLELINE | DT_CENTER | DT_VCENTER);
            SelectObject(memDC, oldFont);
            DeleteObject(noteFont);
        }
    }

    // Eğer şarkı durmuş ise durdurma simgesi göster
    if (!m_isMediaPlaying) {
        // Duraklatıldığında: Resmin üzerine yarı saydam koyu filtre ve net beyaz duraklatma simgesi
        BLENDFUNCTION bf = {};
        bf.BlendOp = AC_SRC_OVER;
        bf.SourceConstantAlpha = 140; // ~55% yarı saydamlık
        HDC overlayDC = CreateCompatibleDC(memDC);
        HBITMAP overlayBmp = CreateCompatibleBitmap(memDC, thumbSize, thumbSize);
        HGDIOBJ oldObmp = SelectObject(overlayDC, overlayBmp);
        RECT rOver = { 0, 0, thumbSize, thumbSize };
        HBRUSH darkBrush = CreateSolidBrush(RGB(10, 15, 25));
        FillRect(overlayDC, &rOver, darkBrush);
        DeleteObject(darkBrush);

        SelectClipRgn(memDC, clipRgn);
        AlphaBlend(memDC, thumbX, thumbY, thumbSize, thumbSize, overlayDC, 0, 0, thumbSize, thumbSize, bf);
        SelectClipRgn(memDC, nullptr);

        SelectObject(overlayDC, oldObmp);
        DeleteObject(overlayBmp);
        DeleteDC(overlayDC);

        // Beyaz yuvarlatılmış duraklatma simgesi
        int tcx    = thumbX + thumbSize / 2;
        int tcy    = thumbY + thumbSize / 2;
        int barGap = (std::max)(1, ScaleDpi(1, dpi));
        int barW   = (std::max)(2, ScaleDpi(3, dpi));
        int barH   = ScaleDpi(6, dpi);
        int barRad = ScaleDpi(2, dpi);
        HBRUSH barBrush = CreateSolidBrush(RGB(255, 255, 255));
        HPEN barPen     = CreatePen(PS_SOLID, 1, RGB(255, 255, 255));
        HGDIOBJ oldBarB = SelectObject(memDC, barBrush);
        HGDIOBJ oldBarP = SelectObject(memDC, barPen);
        RoundRect(memDC, tcx - barGap - barW, tcy - barH, tcx - barGap, tcy + barH, barRad, barRad);
        RoundRect(memDC, tcx + barGap, tcy - barH, tcx + barGap + barW, tcy + barH, barRad, barRad);
        SelectObject(memDC, oldBarB);
        SelectObject(memDC, oldBarP);
        DeleteObject(barBrush);
        DeleteObject(barPen);
    }

    // Dış 1px ince çerçeve
    HPEN borderPen = CreatePen(PS_SOLID, 1, RGB(45, 58, 78));
    HGDIOBJ oldBp = SelectObject(memDC, borderPen);
    HGDIOBJ oldBb = SelectObject(memDC, GetStockObject(NULL_BRUSH));
    RoundRect(memDC, thumbX, thumbY, thumbX + thumbSize, thumbY + thumbSize, thumbRadius, thumbRadius);
    SelectObject(memDC, oldBp);
    SelectObject(memDC, oldBb);
    DeleteObject(borderPen);

    DeleteObject(clipRgn);

    // 3. Medya Kontrol Düğmeleri (Önceki |<, Oynat/Duraklat ▷ / ||, Sonraki >|)
    RECT rPrev = GetPrevBtnRect(w, h);
    RECT rPlay = GetPlayBtnRect(w, h);
    RECT rNext = GetNextBtnRect(w, h);

    COLORREF btnRestKey = RGB(13, 17, 21);
    int btnRad = ScaleDpi(5, dpi);
    int penW   = (std::max)(1, ScaleDpi(2, dpi));

    auto DrawBtnHoverOrHitbox = [&](const RECT& rBtn, bool isHovered) {
        if (isHovered) {
            HBRUSH hHov = CreateSolidBrush(RGB(51, 65, 85));
            HPEN hHovP  = CreatePen(PS_SOLID, 1, RGB(71, 85, 105));
            HGDIOBJ ob = SelectObject(memDC, hHov);
            HGDIOBJ op = SelectObject(memDC, hHovP);
            RoundRect(memDC, rBtn.left, rBtn.top, rBtn.right, rBtn.bottom, btnRad, btnRad);
            SelectObject(memDC, ob);
            SelectObject(memDC, op);
            DeleteObject(hHov);
            DeleteObject(hHovP);
        } else {
            HBRUSH hHit = CreateSolidBrush(btnRestKey);
            HPEN hHitP  = CreatePen(PS_SOLID, 1, btnRestKey);
            HGDIOBJ ob = SelectObject(memDC, hHit);
            HGDIOBJ op = SelectObject(memDC, hHitP);
            RoundRect(memDC, rBtn.left, rBtn.top, rBtn.right, rBtn.bottom, btnRad, btnRad);
            SelectObject(memDC, ob);
            SelectObject(memDC, op);
            DeleteObject(hHit);
            DeleteObject(hHitP);
        }
    };

    int d6 = ScaleDpi(6, dpi);
    int d5 = ScaleDpi(5, dpi);
    int d4 = ScaleDpi(4, dpi);
    int d3 = ScaleDpi(3, dpi);
    int d2 = ScaleDpi(2, dpi);
    HGDIOBJ oldNullB = SelectObject(memDC, GetStockObject(NULL_BRUSH)); // İçi boş (outline)

    // 3a. Prev Düğmesi (|<)
    if (m_mediaLayoutMode != MediaLayoutMode::MiniPlay) {
        bool prevHover = (m_hoveredMediaBtn == MediaCardButton::Prev);
        DrawBtnHoverOrHitbox(rPrev, prevHover);

        COLORREF prevColor = prevHover ? RGB(255, 255, 255) : RGB(226, 232, 240);
        HPEN prevPen = CreatePen(PS_SOLID, penW, prevColor);
        HGDIOBJ oldP = SelectObject(memDC, prevPen);

        int prevCx = (rPrev.left + rPrev.right) / 2;
        int prevCy = (rPrev.top + rPrev.bottom) / 2;
        MoveToEx(memDC, prevCx - d5, prevCy - d5, nullptr);
        LineTo(memDC, prevCx - d5, prevCy + d6);
        POINT prevTri[3] = { { prevCx + d4, prevCy - d5 }, { prevCx + d4, prevCy + d5 }, { prevCx - d3, prevCy } };
        Polygon(memDC, prevTri, 3);
        SelectObject(memDC, oldP);
        DeleteObject(prevPen);
    }

    // 3b. Play/Pause Düğmesi (▷ / ||)
    {
        bool playHover = (m_hoveredMediaBtn == MediaCardButton::PlayPause);
        DrawBtnHoverOrHitbox(rPlay, playHover);

        COLORREF playColor = playHover ? RGB(255, 255, 255) : RGB(241, 245, 249);
        HPEN playPen = CreatePen(PS_SOLID, penW, playColor);
        HGDIOBJ oldP = SelectObject(memDC, playPen);
        int playCx = (rPlay.left + rPlay.right) / 2;
        int playCy = (rPlay.top + rPlay.bottom) / 2;

        if (m_isMediaPlaying) {
            MoveToEx(memDC, playCx - d3, playCy - d5, nullptr);
            LineTo(memDC, playCx - d3, playCy + d6);
            MoveToEx(memDC, playCx + d2, playCy - d5, nullptr);
            LineTo(memDC, playCx + d2, playCy + d6);
        } else {
            POINT playTri[3] = { { playCx - d3, playCy - d5 }, { playCx - d3, playCy + d5 }, { playCx + d5, playCy } };
            Polygon(memDC, playTri, 3);
        }
        SelectObject(memDC, oldP);
        DeleteObject(playPen);
    }

    // 3c. Next Düğmesi (>|)
    if (m_mediaLayoutMode != MediaLayoutMode::MiniPlay) {
        bool nextHover = (m_hoveredMediaBtn == MediaCardButton::Next);
        DrawBtnHoverOrHitbox(rNext, nextHover);

        COLORREF nextColor = nextHover ? RGB(255, 255, 255) : RGB(226, 232, 240);
        HPEN nextPen = CreatePen(PS_SOLID, penW, nextColor);
        HGDIOBJ oldP = SelectObject(memDC, nextPen);
        int nextCx = (rNext.left + rNext.right) / 2;
        int nextCy = (rNext.top + rNext.bottom) / 2;
        POINT nextTri[3] = { { nextCx - d4, nextCy - d5 }, { nextCx - d4, nextCy + d5 }, { nextCx + d3, nextCy } };
        Polygon(memDC, nextTri, 3);
        MoveToEx(memDC, nextCx + d5, nextCy - d5, nullptr);
        LineTo(memDC, nextCx + d5, nextCy + d6);
        SelectObject(memDC, oldP);
        DeleteObject(nextPen);
    }
    SelectObject(memDC, oldNullB);

    // 4. Metin Alanı (İki satır alt alta - yalnızca Full modda)
    // 1. Satır: Şarkı Adı (Kalın, Beyaz)
    // 2. Satır: Sanatçı Adı (Normal, Gri)
    if (m_mediaLayoutMode == MediaLayoutMode::Full) {
        int textLeft     = thumbX + thumbSize + m.textGapL;
        int maxTextRight = rPrev.left - m.textGapR;

        if (maxTextRight > textLeft + ScaleDpi(12, dpi)) {
            SetBkMode(memDC, TRANSPARENT);

            HFONT titleFont = CreateFontW(
                -ScaleDpi(12, dpi), 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
                L"Segoe UI"
            );

            HFONT artistFont = CreateFontW(
                -ScaleDpi(10, dpi), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
                L"Segoe UI"
            );

            RECT rcLine1 = { textLeft, (h / 2) - ScaleDpi(15, dpi), maxTextRight, (h / 2) };
            HGDIOBJ oldF = SelectObject(memDC, titleFont);
            SetTextColor(memDC, RGB(255, 255, 255));
            DrawTextW(memDC, m_mediaTitle.c_str(), -1, &rcLine1, DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);

            RECT rcLine2 = { textLeft, (h / 2), maxTextRight, (h / 2) + ScaleDpi(14, dpi) };
            SelectObject(memDC, artistFont);
            SetTextColor(memDC, RGB(148, 163, 184));
            DrawTextW(memDC, m_mediaArtist.c_str(), -1, &rcLine2, DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);

            SelectObject(memDC, oldF);
            DeleteObject(titleFont);
            DeleteObject(artistFont);
        }
    }

    BitBlt(hdc, 0, 0, w, h, memDC, 0, 0, SRCCOPY);

    SelectObject(memDC, oldBmp);
    DeleteObject(memBmp);
    DeleteDC(memDC);

    EndPaint(hwnd, &ps);
}

LRESULT CALLBACK OsdManager::MediaWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    OsdManager* mgr = nullptr;
    if (msg == WM_NCCREATE) {
        auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
        mgr = static_cast<OsdManager*>(cs->lpCreateParams);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(mgr));
    } else {
        mgr = reinterpret_cast<OsdManager*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    }

    switch (msg) {
        case WM_WINDOWPOSCHANGING: {
            auto* pwp = reinterpret_cast<WINDOWPOS*>(lParam);
            if (pwp && !(pwp->flags & SWP_NOZORDER)) {
                pwp->hwndInsertAfter = HWND_TOPMOST;
            }
            break;
        }

        case WM_MOUSEACTIVATE:
            return MA_NOACTIVATE;

        case WM_SETCURSOR: {
            if (mgr) {
                POINT pt;
                GetCursorPos(&pt);
                ScreenToClient(hwnd, &pt);
                RECT rc;
                GetClientRect(hwnd, &rc);
                int w = rc.right - rc.left;
                int h = rc.bottom - rc.top;
                if (mgr->HitTestMediaButton(pt.x, pt.y, w, h) != MediaCardButton::None) {
                    SetCursor(LoadCursor(nullptr, IDC_HAND));
                    return TRUE;
                }
            }
            SetCursor(LoadCursor(nullptr, IDC_ARROW));
            return TRUE;
        }

        case WM_MOUSEMOVE: {
            if (mgr) {
                int x = GET_X_LPARAM(lParam);
                int y = GET_Y_LPARAM(lParam);
                RECT rc;
                GetClientRect(hwnd, &rc);
                int w = rc.right - rc.left;
                int h = rc.bottom - rc.top;

                MediaCardButton hovered = mgr->HitTestMediaButton(x, y, w, h);
                if (hovered != mgr->m_hoveredMediaBtn) {
                    mgr->m_hoveredMediaBtn = hovered;
                    InvalidateRect(hwnd, nullptr, FALSE);
                }

                if (!mgr->m_isTrackingMouse) {
                    TRACKMOUSEEVENT tme = { sizeof(tme) };
                    tme.cbSize = sizeof(tme);
                    tme.dwFlags = TME_LEAVE;
                    tme.hwndTrack = hwnd;
                    TrackMouseEvent(&tme);
                    mgr->m_isTrackingMouse = true;
                }
            }
            return 0;
        }

        case WM_MOUSELEAVE: {
            if (mgr) {
                mgr->m_isTrackingMouse = false;
                if (mgr->m_hoveredMediaBtn != MediaCardButton::None) {
                    mgr->m_hoveredMediaBtn = MediaCardButton::None;
                    InvalidateRect(hwnd, nullptr, FALSE);
                }
            }
            return 0;
        }

        case WM_LBUTTONDOWN: {
            if (mgr) {
                int x = GET_X_LPARAM(lParam);
                int y = GET_Y_LPARAM(lParam);
                RECT rc;
                GetClientRect(hwnd, &rc);
                int w = rc.right - rc.left;
                int h = rc.bottom - rc.top;

                MediaCardButton btn = mgr->HitTestMediaButton(x, y, w, h);
                if (btn == MediaCardButton::Prev) {
                    SendMediaKey(VK_MEDIA_PREV_TRACK);
                } else if (btn == MediaCardButton::PlayPause) {
                    SendMediaKey(VK_MEDIA_PLAY_PAUSE);
                    mgr->m_isMediaPlaying = !mgr->m_isMediaPlaying;
                    InvalidateRect(hwnd, nullptr, FALSE);
                } else if (btn == MediaCardButton::Next) {
                    SendMediaKey(VK_MEDIA_NEXT_TRACK);
                }
            }
            return 0;
        }

        case WM_RBUTTONDOWN:
            return 0;

        case WM_PAINT:
            if (mgr) {
                mgr->OnPaintMedia(hwnd);
                return 0;
            }
            break;

        case WM_ERASEBKGND:
            return 1;

        case WM_TIMER:
            if (mgr) {
                if (wParam == TIMER_ID_MEDIA_FADE_IN) {
                    mgr->m_mediaAlpha += 35;
                    if (mgr->m_mediaAlpha >= 255) {
                        mgr->m_mediaAlpha = 255;
                        KillTimer(hwnd, TIMER_ID_MEDIA_FADE_IN);
                        if (!mgr->m_cfg.mediaOsdPersistent) {
                            SetTimer(hwnd, TIMER_ID_MEDIA_HOLD, mgr->m_mediaDuration, nullptr);
                        }
                    }
                    SetLayeredWindowAttributes(hwnd, MEDIA_COLOR_KEY, static_cast<BYTE>(mgr->m_mediaAlpha), LWA_COLORKEY | LWA_ALPHA);
                    return 0;
                } else if (wParam == TIMER_ID_MEDIA_HOLD) {
                    KillTimer(hwnd, TIMER_ID_MEDIA_HOLD);
                    if (!mgr->m_cfg.mediaOsdPersistent) {
                        if (mgr->m_cfg.osdFadeEnabled) {
                            SetTimer(hwnd, TIMER_ID_MEDIA_FADE_OUT, 15, nullptr);
                        } else {
                            ShowWindow(hwnd, SW_HIDE);
                        }
                    }
                    return 0;
                } else if (wParam == TIMER_ID_MEDIA_FADE_OUT) {
                    mgr->m_mediaAlpha -= 25;
                    if (mgr->m_mediaAlpha <= 0) {
                        mgr->m_mediaAlpha = 0;
                        KillTimer(hwnd, TIMER_ID_MEDIA_FADE_OUT);
                        ShowWindow(hwnd, SW_HIDE);
                    }
                    SetLayeredWindowAttributes(hwnd, MEDIA_COLOR_KEY, static_cast<BYTE>(mgr->m_mediaAlpha), LWA_COLORKEY | LWA_ALPHA);
                    return 0;
                }
            }
            break;

        default:
            break;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}
