#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <string>

// ─────────────────────────────────────────────
//  Eylem listesi
// ─────────────────────────────────────────────
enum class Action : int {
    None = 0,
    MicMute,
    MasterMute,
    ToggleDeafen,
    PlayPause,
    NextTrack,
    PrevTrack,
    LockScreen,
    CustomApp,
    PushToTalk
};

// ─────────────────────────────────────────────
//  Yapılandırma — tüm ayarlar burada sabit olarak tanımlıdır
// ─────────────────────────────────────────────
struct Config {
    // Tıklama ve basılı tutma eylemleri
    Action       action1           = Action::MicMute;
    Action       action2           = Action::PlayPause;
    Action       action3           = Action::NextTrack;
    Action       action4           = Action::None;
    Action       holdAction        = Action::CustomApp;
    std::wstring customAppPath     = L"C:\\Users\\kerem\\AppData\\Local\\Programs\\antigravity\\Antigravity.exe";
    bool         windowsHelloLight = true;

    // Tıklama ve basılı tutma zamanlamaları (milisaniye)
    DWORD        doubleTapMs        = 250;
    DWORD        holdMs             = 250;

    // Sistem ve ses davranışları
    bool         autoStart          = true;   // Taşınabilir mod dışında Windows başlangıcında otomatik çalışır
    bool         soundFxEnabled     = true;   // Mikrofon susturma/açma ses efektleri

    // Medya ve bildirim OSD ayarları
    bool         mediaTrackOsd      = true;   // Medya parça değişiminde OSD göster
    bool         mediaOsdPersistent = true;   // Sürekli medya OSD kartı (tam ekranda gizlenir)
    std::wstring mediaOsdPosition   = L"BottomLeft";       // BottomLeft, BottomRight, TopLeft, TopRight, Center
    std::wstring osdPosition        = L"TopLeft";          // TopLeft, TopRight, BottomLeft, BottomRight, Center
    COLORREF     osdColor           = RGB(0, 229, 255);    // #00E5FF
    int          osdFontSize        = 10;
    DWORD        osdDurationMs      = 1500;
    bool         osdFadeEnabled     = true;
};
