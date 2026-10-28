// Osd.cpp – Eylem ve Spotify ekran bildirimleri (OSD)
#include "Osd.hpp"
#include "Audio.hpp"
#include <dwmapi.h>
#include <shellapi.h>
#include <windowsx.h>
#include <shlwapi.h>
#include <gdiplus.h>
#include <algorithm>

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
static constexpr UINT_PTR TIMER_ID_MEDIA_MONITOR  = 307;

static const wchar_t* TIP_CLASS_NAME   = L"CopilotTipOsdClass";
static const wchar_t* MEDIA_CLASS_NAME = L"CopilotMediaOsdClass";
static constexpr COLORREF MEDIA_COLOR_KEY = RGB(12, 16, 20);

static HWINEVENTHOOK s_hForegroundHook = nullptr;

static void CALLBACK ForegroundEventProc(HWINEVENTHOOK, DWORD, HWND, LONG, LONG, DWORD, DWORD) {
    OsdManager::Instance().CheckFullscreenAndTaskbarState();
}

static HBITMAP DecodeThumbnail(const std::vector<uint8_t>& data, int targetW, int targetH) {
    if (data.empty()) return nullptr;

    IStream* pStream = SHCreateMemStream(data.data(), static_cast<UINT>(data.size()));
    if (!pStream) return nullptr;

    Gdiplus::Bitmap* bmp = Gdiplus::Bitmap::FromStream(pStream);
    HBITMAP hResult = nullptr;
    if (bmp && bmp->GetLastStatus() == Gdiplus::Ok) {
        HDC hdcScreen = GetDC(nullptr);
        HDC hdcMem = CreateCompatibleDC(hdcScreen);
        hResult = CreateCompatibleBitmap(hdcScreen, targetW, targetH);
        HGDIOBJ oldBmp = SelectObject(hdcMem, hResult);

        Gdiplus::Graphics g(hdcMem);
        g.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
        g.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHalf);
        g.DrawImage(bmp, 0, 0, targetW, targetH);

        SelectObject(hdcMem, oldBmp);
        DeleteDC(hdcMem);
        ReleaseDC(nullptr, hdcScreen);

        delete bmp;
    }
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
}

void OsdManager::UpdateConfig(const Config& cfg) {
    m_cfg = cfg;
    if (m_mediaHwnd) {
        if (m_cfg.mediaOsdPersistent && m_hasActiveMedia) {
            SetTimer(m_mediaHwnd, TIMER_ID_MEDIA_MONITOR, 300, nullptr);
            CheckFullscreenAndTaskbarState();
        } else {
            KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_MONITOR);
        }
    }
}

void OsdManager::Destroy() {
    if (s_hForegroundHook) {
        UnhookWinEvent(s_hForegroundHook);
        s_hForegroundHook = nullptr;
    }
    if (m_tipHwnd) {
        DestroyWindow(m_tipHwnd);
        m_tipHwnd = nullptr;
    }
    if (m_mediaHwnd) {
        KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_MONITOR);
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
    RECT workArea = {};
    if (!SystemParametersInfoW(SPI_GETWORKAREA, 0, &workArea, 0)) {
        workArea.left   = 0;
        workArea.top    = 0;
        workArea.right  = GetSystemMetrics(SM_CXSCREEN);
        workArea.bottom = GetSystemMetrics(SM_CYSCREEN);
    }

    int workW = workArea.right - workArea.left;
    int workH = workArea.bottom - workArea.top;

    int padX = 28;
    int padY = 14;
    m_tipWidth  = (std::max)(textW + padX, 140);
    m_tipHeight = (std::max)(textH + padY, 36);

    int x = workArea.left + 20;
    int y = workArea.top + 55;

    if (m_cfg.osdPosition == L"TopRight") {
        x = workArea.right - m_tipWidth - 24;
        y = workArea.top + 55;
    } else if (m_cfg.osdPosition == L"BottomLeft") {
        x = workArea.left + 24;
        y = workArea.bottom - m_tipHeight - 12;
    } else if (m_cfg.osdPosition == L"BottomRight") {
        x = workArea.right - m_tipWidth - 24;
        y = workArea.bottom - m_tipHeight - 12;
    } else if (m_cfg.osdPosition == L"Center") {
        x = workArea.left + (workW - m_tipWidth) / 2;
        y = workArea.top + (workH - m_tipHeight) / 2;
    } else {
        // TopLeft
        x = workArea.left + 20;
        y = workArea.top + 55;
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

    int w = 260;
    int h = 32;

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

    APPBARDATA abd = { sizeof(abd) };
    abd.hWnd = hTaskbar;
    UINT_PTR state = SHAppBarMessage(ABM_GETSTATE, &abd);
    if (state & ABS_AUTOHIDE) {
        RECT rcTb = {};
        GetWindowRect(hTaskbar, &rcTb);
        int h = rcTb.bottom - rcTb.top;
        int w = rcTb.right - rcTb.left;
        if (h <= 4 || w <= 4) {
            return false;
        }
    }
    return true;
}

RECT OsdManager::GetNextBtnRect(int w, int h) const {
    int btnW = 24, btnH = 24;
    int rightX = w - 6 - btnW;
    int y = (h - btnH) / 2;
    return { rightX, y, rightX + btnW, y + btnH };
}

RECT OsdManager::GetPlayBtnRect(int w, int h) const {
    int btnW = 26, btnH = 26;
    int rightX = w - 6 - 24 - 8 - btnW;
    int y = (h - btnH) / 2;
    return { rightX, y, rightX + btnW, y + btnH };
}

RECT OsdManager::GetPrevBtnRect(int w, int h) const {
    int btnW = 24, btnH = 24;
    int rightX = w - 6 - 24 - 8 - 26 - 8 - btnW;
    int y = (h - btnH) / 2;
    return { rightX, y, rightX + btnW, y + btnH };
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

void OsdManager::PositionMediaWindow(int textW, int textH) {
    (void)textH;
    m_mediaTextW = textW;

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

    int tbH = hasTb ? (rcTb.bottom - rcTb.top) : 48;

    // Resim 2'deki gibi 2 satır metin ve 32x32 kare thumbnail için ideal yükseklik (36-40px)
    m_mediaHeight = (tbH >= 42) ? 38 : 34;
    // [Sol Thumbnail: 40px] + [Metin: textW] + [3 Buton: 96px] + kenar payı
    m_mediaWidth  = (std::clamp)(textW + 160, 220, 480);

    std::wstring pos = m_cfg.mediaOsdPosition;
    if (pos.empty()) {
        pos = m_cfg.mediaOsdPersistent ? L"BottomLeft" : m_cfg.osdPosition;
    }

    int x = 12;
    int y = hasTb ? (rcTb.top + (tbH - m_mediaHeight) / 2) : (workArea.bottom - m_mediaHeight - 8);

    if (pos == L"BottomLeft") {
        // Doğrudan görev çubuğunun sol tarafında, dikeyde ortalı
        x = hasTb ? (rcTb.left + 12) : (workArea.left + 12);
        y = hasTb ? (rcTb.top + (tbH - m_mediaHeight) / 2) : (workArea.bottom - m_mediaHeight - 8);
    } else if (pos == L"BottomRight") {
        x = (hasTb ? rcTb.right : workArea.right) - m_mediaWidth - 24;
        y = hasTb ? (rcTb.top + (tbH - m_mediaHeight) / 2) : (workArea.bottom - m_mediaHeight - 8);
    } else if (pos == L"Center") {
        x = workArea.left + (workW - m_mediaWidth) / 2;
        y = workArea.top + (workH - m_mediaHeight) / 2;
    } else if (pos == L"TopLeft") {
        x = workArea.left + 20;
        y = workArea.top + 55;
    } else if (pos == L"TopRight") {
        x = workArea.right - m_mediaWidth - 24;
        y = workArea.top + 55;
    }

    SetWindowPos(m_mediaHwnd, HWND_TOPMOST, x, y, m_mediaWidth, m_mediaHeight, SWP_NOACTIVATE);

    // Şeffaf pencere: Herhangi bir DWM bölgesi kesimi yapılmaz, böylece dışta çizgi kalmaz
    SetWindowRgn(m_mediaHwnd, nullptr, TRUE);
}

void OsdManager::CheckFullscreenAndTaskbarState() {
    if (!m_mediaHwnd) return;
    if (!m_cfg.mediaOsdPersistent) {
        KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_MONITOR);
        return;
    }

    // Şarkı başlığı yoksa gizle
    if (m_mediaTitle.empty()) {
        if (IsWindowVisible(m_mediaHwnd)) {
            HideMediaTrack();
        }
        return;
    }

    bool isFs = IsFullscreenAppActive(m_mediaHwnd);
    bool isTb = IsTaskbarVisible();
    bool shouldShow = (!isFs && isTb);

    if (shouldShow) {
        if (!IsWindowVisible(m_mediaHwnd) || m_suppressedByFullscreen) {
            m_suppressedByFullscreen = false;
            PositionMediaWindow(m_mediaTextW, m_mediaHeight);
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
        if (IsWindowVisible(m_mediaHwnd)) {
            m_suppressedByFullscreen = true;
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

    if (thumbChanged) {
        m_mediaThumbData = thumbnailData;
        if (m_mediaThumbBmp) {
            DeleteObject(m_mediaThumbBmp);
            m_mediaThumbBmp = nullptr;
        }
        if (!m_mediaThumbData.empty()) {
            m_mediaThumbBmp = DecodeThumbnail(m_mediaThumbData, 30, 30);
        }
    }

    m_mediaDuration = (durationMs > 0) ? durationMs : (std::max)(m_cfg.osdDurationMs, static_cast<DWORD>(2500));

    // İki satır metin genişliğini ölç
    HDC hdc = GetDC(m_mediaHwnd);
    HFONT fontTitle = CreateFontW(
        -13, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );
    HFONT fontArtist = CreateFontW(
        -11, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
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

    int textW = (std::clamp)((std::max)(titleW, artistW), 60, 240);
    PositionMediaWindow(textW, m_mediaHeight);

    if (m_cfg.mediaOsdPersistent) {
        SetTimer(m_mediaHwnd, TIMER_ID_MEDIA_MONITOR, 300, nullptr);

        bool isFs = IsFullscreenAppActive(m_mediaHwnd);
        bool isTb = IsTaskbarVisible();
        if (isFs || !isTb) {
            m_suppressedByFullscreen = true;
            ShowWindow(m_mediaHwnd, SW_HIDE);
            return;
        }

        m_suppressedByFullscreen = false;

        if (IsWindowVisible(m_mediaHwnd) && !trackChanged && !playChanged && !thumbChanged) {
            return;
        }

        if (IsWindowVisible(m_mediaHwnd) && (trackChanged || playChanged || thumbChanged)) {
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
        KillTimer(m_mediaHwnd, TIMER_ID_MEDIA_MONITOR);
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

    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBmp = CreateCompatibleBitmap(hdc, w, h);
    HGDIOBJ oldBmp = SelectObject(memDC, memBmp);

    // 1. Arka plan: Tamamen şeffaf (MEDIA_COLOR_KEY ile boyanır, LWA_COLORKEY sayesinde görünmez)
    HBRUSH bgBrush = CreateSolidBrush(MEDIA_COLOR_KEY);
    FillRect(memDC, &rc, bgBrush);
    DeleteObject(bgBrush);

    // 2. Sol Küçük Kare Albüm / Medya Rozeti (4-6px hafif yuvarlatılmış kare)
    int thumbSize = 30;
    int thumbX = 8;
    int thumbY = (h - thumbSize) / 2;

    HRGN clipRgn = CreateRoundRectRgn(thumbX, thumbY, thumbX + thumbSize + 1, thumbY + thumbSize + 1, 6, 6);

    if (m_mediaThumbBmp) {
        // Şarkının gerçek albüm kapağı resmi
        HDC bmpDC = CreateCompatibleDC(memDC);
        HGDIOBJ oldThumb = SelectObject(bmpDC, m_mediaThumbBmp);

        SelectClipRgn(memDC, clipRgn);
        BitBlt(memDC, thumbX, thumbY, thumbSize, thumbSize, bmpDC, 0, 0, SRCCOPY);
        SelectClipRgn(memDC, nullptr);

        SelectObject(bmpDC, oldThumb);
        DeleteDC(bmpDC);
    } else {
        // Albüm kapağı yoksa zarif koyu arduvaz arkaplan
        HBRUSH thumbBg = CreateSolidBrush(RGB(24, 32, 47));
        HPEN thumbPen  = CreatePen(PS_SOLID, 1, RGB(45, 58, 78));
        HGDIOBJ oldTbB = SelectObject(memDC, thumbBg);
        HGDIOBJ oldTbP = SelectObject(memDC, thumbPen);
        RoundRect(memDC, thumbX, thumbY, thumbX + thumbSize, thumbY + thumbSize, 6, 6);
        SelectObject(memDC, oldTbB);
        SelectObject(memDC, oldTbP);
        DeleteObject(thumbBg);
        DeleteObject(thumbPen);

        if (m_isMediaPlaying) {
            SetBkMode(memDC, TRANSPARENT);
            HFONT noteFont = CreateFontW(
                -12, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
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
        int tcx = thumbX + thumbSize / 2;
        int tcy = thumbY + thumbSize / 2;
        HBRUSH barBrush = CreateSolidBrush(RGB(255, 255, 255));
        HPEN barPen     = CreatePen(PS_SOLID, 1, RGB(255, 255, 255));
        HGDIOBJ oldBarB = SelectObject(memDC, barBrush);
        HGDIOBJ oldBarP = SelectObject(memDC, barPen);
        RoundRect(memDC, tcx - 5, tcy - 7, tcx - 1, tcy + 7, 3, 3);
        RoundRect(memDC, tcx + 1, tcy - 7, tcx + 5, tcy + 7, 3, 3);
        SelectObject(memDC, oldBarB);
        SelectObject(memDC, oldBarP);
        DeleteObject(barBrush);
        DeleteObject(barPen);
    }

    // Dış 1px ince çerçeve
    HPEN borderPen = CreatePen(PS_SOLID, 1, RGB(45, 58, 78));
    HGDIOBJ oldBp = SelectObject(memDC, borderPen);
    HGDIOBJ oldBb = SelectObject(memDC, GetStockObject(NULL_BRUSH));
    RoundRect(memDC, thumbX, thumbY, thumbX + thumbSize, thumbY + thumbSize, 6, 6);
    SelectObject(memDC, oldBp);
    SelectObject(memDC, oldBb);
    DeleteObject(borderPen);

    DeleteObject(clipRgn);

    // 3. Medya Kontrol Düğmeleri (Önceki |<, Oynat/Duraklat ▷ / ||, Sonraki >|)
    RECT rPrev = GetPrevBtnRect(w, h);
    RECT rPlay = GetPlayBtnRect(w, h);
    RECT rNext = GetNextBtnRect(w, h);

    COLORREF btnRestKey = RGB(13, 17, 21);

    auto DrawBtnHoverOrHitbox = [&](const RECT& rBtn, bool isHovered) {
        if (isHovered) {
            HBRUSH hHov = CreateSolidBrush(RGB(51, 65, 85));
            HPEN hHovP  = CreatePen(PS_SOLID, 1, RGB(71, 85, 105));
            HGDIOBJ ob = SelectObject(memDC, hHov);
            HGDIOBJ op = SelectObject(memDC, hHovP);
            RoundRect(memDC, rBtn.left, rBtn.top, rBtn.right, rBtn.bottom, 6, 6);
            SelectObject(memDC, ob);
            SelectObject(memDC, op);
            DeleteObject(hHov);
            DeleteObject(hHovP);
        } else {
            HBRUSH hHit = CreateSolidBrush(btnRestKey);
            HPEN hHitP  = CreatePen(PS_SOLID, 1, btnRestKey);
            HGDIOBJ ob = SelectObject(memDC, hHit);
            HGDIOBJ op = SelectObject(memDC, hHitP);
            RoundRect(memDC, rBtn.left, rBtn.top, rBtn.right, rBtn.bottom, 6, 6);
            SelectObject(memDC, ob);
            SelectObject(memDC, op);
            DeleteObject(hHit);
            DeleteObject(hHitP);
        }
    };

    // 3a. Prev Düğmesi (|<)
    bool prevHover = (m_hoveredMediaBtn == MediaCardButton::Prev);
    DrawBtnHoverOrHitbox(rPrev, prevHover);

    COLORREF prevColor = prevHover ? RGB(255, 255, 255) : RGB(226, 232, 240);
    HPEN prevPen = CreatePen(PS_SOLID, 2, prevColor);
    HGDIOBJ oldP = SelectObject(memDC, prevPen);
    HGDIOBJ oldNullB = SelectObject(memDC, GetStockObject(NULL_BRUSH)); // İçi boş (outline)

    int prevCx = (rPrev.left + rPrev.right) / 2;
    int prevCy = (rPrev.top + rPrev.bottom) / 2;
    MoveToEx(memDC, prevCx - 6, prevCy - 6, nullptr);
    LineTo(memDC, prevCx - 6, prevCy + 7);
    POINT prevTri[3] = { { prevCx + 5, prevCy - 6 }, { prevCx + 5, prevCy + 6 }, { prevCx - 4, prevCy } };
    Polygon(memDC, prevTri, 3);
    SelectObject(memDC, oldP);
    DeleteObject(prevPen);

    // 3b. Play/Pause Düğmesi (▷ / ||)
    bool playHover = (m_hoveredMediaBtn == MediaCardButton::PlayPause);
    DrawBtnHoverOrHitbox(rPlay, playHover);

    COLORREF playColor = playHover ? RGB(255, 255, 255) : RGB(241, 245, 249);
    HPEN playPen = CreatePen(PS_SOLID, 2, playColor);
    oldP = SelectObject(memDC, playPen);
    int playCx = (rPlay.left + rPlay.right) / 2;
    int playCy = (rPlay.top + rPlay.bottom) / 2;

    if (m_isMediaPlaying) {
        MoveToEx(memDC, playCx - 4, playCy - 6, nullptr);
        LineTo(memDC, playCx - 4, playCy + 7);
        MoveToEx(memDC, playCx + 3, playCy - 6, nullptr);
        LineTo(memDC, playCx + 3, playCy + 7);
    } else {
        POINT playTri[3] = { { playCx - 4, playCy - 6 }, { playCx - 4, playCy + 6 }, { playCx + 6, playCy } };
        Polygon(memDC, playTri, 3);
    }
    SelectObject(memDC, oldP);
    DeleteObject(playPen);

    // 3c. Next Düğmesi (>|)
    bool nextHover = (m_hoveredMediaBtn == MediaCardButton::Next);
    DrawBtnHoverOrHitbox(rNext, nextHover);

    COLORREF nextColor = nextHover ? RGB(255, 255, 255) : RGB(226, 232, 240);
    HPEN nextPen = CreatePen(PS_SOLID, 2, nextColor);
    oldP = SelectObject(memDC, nextPen);
    int nextCx = (rNext.left + rNext.right) / 2;
    int nextCy = (rNext.top + rNext.bottom) / 2;
    POINT nextTri[3] = { { nextCx - 5, nextCy - 6 }, { nextCx - 5, nextCy + 6 }, { nextCx + 4, nextCy } };
    Polygon(memDC, nextTri, 3);
    MoveToEx(memDC, nextCx + 6, nextCy - 6, nullptr);
    LineTo(memDC, nextCx + 6, nextCy + 7);
    SelectObject(memDC, oldP);
    DeleteObject(nextPen);
    SelectObject(memDC, oldNullB);

    // 4. Metin Alanı (İki satır alt alta)
    // 1. Satır: Şarkı Adı (Kalın, Beyaz)
    // 2. Satır: Sanatçı Adı (Normal, Gri)
    SetBkMode(memDC, TRANSPARENT);

    HFONT titleFont = CreateFontW(
        -13, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );

    HFONT artistFont = CreateFontW(
        -11, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe UI"
    );

    int textLeft = thumbX + thumbSize + 10;
    int maxTextRight = rPrev.left - 10;

    RECT rcLine1 = { textLeft, (h / 2) - 17, maxTextRight, (h / 2) + 1 };
    HGDIOBJ oldF = SelectObject(memDC, titleFont);
    SetTextColor(memDC, RGB(255, 255, 255));
    DrawTextW(memDC, m_mediaTitle.c_str(), -1, &rcLine1, DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);

    RECT rcLine2 = { textLeft, (h / 2) + 1, maxTextRight, (h / 2) + 16 };
    SelectObject(memDC, artistFont);
    SetTextColor(memDC, RGB(148, 163, 184));
    DrawTextW(memDC, m_mediaArtist.c_str(), -1, &rcLine2, DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);

    BitBlt(hdc, 0, 0, w, h, memDC, 0, 0, SRCCOPY);

    SelectObject(memDC, oldF);
    DeleteObject(titleFont);
    DeleteObject(artistFont);
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
                } else if (wParam == TIMER_ID_MEDIA_MONITOR) {
                    mgr->CheckFullscreenAndTaskbarState();
                    return 0;
                }
            }
            break;

        default:
            break;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}
