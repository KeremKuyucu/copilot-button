#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <string>
#include "Config.hpp"

class OsdManager {
public:
    static OsdManager& Instance();

    void Init(HWND hostWnd);
    void UpdateConfig(const Config& cfg);
    void Destroy();

    // Eylem bildirimi (ShowTip)
    void ShowTip(const std::wstring& msg, DWORD durationMs = 0);

    // Spotify parça değişim bildirimi (ShowSpotifyTrackOSD)
    void ShowSpotifyTrack(const std::wstring& songTitle,
                          const std::wstring& artistName = L"Spotify",
                          DWORD durationMs = 0);

private:
    OsdManager() = default;
    ~OsdManager();

    // ── Tip Penceresi (Aksiyon Bildirimi) ─────────────────────────────
    bool CreateTipWindow();
    void PositionTipWindow(int textW, int textH);
    void OnPaintTip(HWND hwnd);
    static LRESULT CALLBACK TipWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

    // ── Spotify Kart Penceresi ────────────────────────────────────────
    bool CreateSpotWindow();
    void PositionSpotWindow();
    void OnPaintSpot(HWND hwnd);
    static LRESULT CALLBACK SpotWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

    HWND         m_hostWnd       = nullptr;
    Config       m_cfg;

    // Tip penceresi durumu
    HWND         m_tipHwnd       = nullptr;
    std::wstring m_tipText;
    int          m_tipWidth      = 0;
    int          m_tipHeight     = 0;
    int          m_tipAlpha      = 0;
    DWORD        m_tipDuration   = 1500;

    // Spotify penceresi durumu
    HWND         m_spotHwnd      = nullptr;
    std::wstring m_spotTitle;
    std::wstring m_spotArtist;
    int          m_spotAlpha     = 0;
    DWORD        m_spotDuration  = 2800;
};
