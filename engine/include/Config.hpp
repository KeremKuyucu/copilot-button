#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <string>
#include <mutex>


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

Action ParseAction(const std::wstring& s);

// config.ini mevcut değilse varsayılan ayarlarla otomatik oluşturur
void EnsureConfigExists(const std::wstring& path);

// ─────────────────────────────────────────────
//  Yapılandırma yapısı
// ─────────────────────────────────────────────
struct Config {
    DWORD        doubleTapMs  = 250;
    DWORD        holdMs       = 250;
    Action       action1      = Action::MicMute;
    Action       action2      = Action::PlayPause;
    Action       action3      = Action::NextTrack;
    Action       action4      = Action::None;
    Action       holdAction   = Action::PushToTalk;
    std::wstring customAppPath;
    bool         soundFxEnabled  = true;
    bool         autoStart       = true;
    std::wstring language        = L"tr";

    // OSD Ayarları
    std::wstring osdPosition     = L"TopLeft";
    std::wstring osdColorHex     = L"B388FF";
    COLORREF     osdColor        = RGB(179, 136, 255);
    int          osdFontSize     = 10;
    DWORD        osdDurationMs   = 1500;
    bool         osdFadeEnabled  = true;
    bool         spotifyTrackOsd = true;
};

// ─────────────────────────────────────────────
//  ConfigManager – INI okuma + hot-reload
// ─────────────────────────────────────────────
class ConfigManager {
public:
    explicit ConfigManager(std::wstring iniPath);
    ~ConfigManager();

    void   Start();          // Yükleme + arka plan izleyicisi başlat
    Config GetConfig() const;

private:
    void Load();
    void WatcherThread();

    std::wstring       m_path;
    std::wstring       m_dir;
    mutable std::mutex m_mu;
    Config             m_cfg;
    HANDLE             m_stopEvent = INVALID_HANDLE_VALUE;
    HANDLE             m_thread    = INVALID_HANDLE_VALUE;
};
