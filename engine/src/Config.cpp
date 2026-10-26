#include "Config.hpp"
#include "AppRegister.hpp"
#include <algorithm>
#include <cctype>

// ─────────────────────────────────────────────
//  Yardımcı: INI'den DWORD oku
// ─────────────────────────────────────────────
static DWORD ReadInt(const wchar_t* path, const wchar_t* key, DWORD def) {
    return GetPrivateProfileIntW(L"Settings", key, static_cast<int>(def), path);
}

static std::wstring ReadStr(const wchar_t* path, const wchar_t* key,
                            const wchar_t* def = L"") {
    wchar_t buf[512] = {};
    GetPrivateProfileStringW(L"Settings", key, def, buf, 512, path);
    return buf;
}

// ─────────────────────────────────────────────
//  Action ayrıştırıcı
// ─────────────────────────────────────────────
Action ParseAction(const std::wstring& s) {
    if (s == L"MicMute")       return Action::MicMute;
    if (s == L"MasterMute")    return Action::MasterMute;
    if (s == L"ToggleDeafen")  return Action::ToggleDeafen;
    if (s == L"PlayPause")     return Action::PlayPause;
    if (s == L"NextTrack")     return Action::NextTrack;
    if (s == L"PrevTrack")     return Action::PrevTrack;
    if (s == L"LockScreen")    return Action::LockScreen;
    if (s == L"CustomApp")     return Action::CustomApp;
    if (s == L"PushToTalk")    return Action::PushToTalk;
    return Action::None;
}

static Action ParseHoldAction(const std::wstring& s) {
    if (s == L"PushToTalk") return Action::PushToTalk;
    if (s == L"CustomApp")  return Action::CustomApp;
    return Action::None;
}

// ─────────────────────────────────────────────
//  ConfigManager
// ─────────────────────────────────────────────
ConfigManager::ConfigManager(std::wstring iniPath)
    : m_path(std::move(iniPath))
{
    // Dizini çıkar
    auto pos = m_path.find_last_of(L"\\/");
    m_dir = (pos != std::wstring::npos) ? m_path.substr(0, pos) : L".";
}

ConfigManager::~ConfigManager() {
    if (m_stopEvent != INVALID_HANDLE_VALUE) {
        SetEvent(m_stopEvent);
        if (m_thread != INVALID_HANDLE_VALUE) {
            WaitForSingleObject(m_thread, 2000);
            CloseHandle(m_thread);
        }
        CloseHandle(m_stopEvent);
    }
}

static COLORREF HexToColor(const std::wstring& hex, COLORREF def) {
    if (hex.length() != 6) return def;
    try {
        unsigned long val = std::stoul(hex, nullptr, 16);
        BYTE r = static_cast<BYTE>((val >> 16) & 0xFF);
        BYTE g = static_cast<BYTE>((val >> 8)  & 0xFF);
        BYTE b = static_cast<BYTE>(val         & 0xFF);
        return RGB(r, g, b);
    } catch (...) {
        return def;
    }
}

void EnsureConfigExists(const std::wstring& path) {
    if (GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES) {
        return; // Dosya zaten mevcut
    }

    HANDLE hFile = CreateFileW(
        path.c_str(),
        GENERIC_WRITE,
        FILE_SHARE_READ,
        nullptr,
        CREATE_NEW,
        FILE_ATTRIBUTE_NORMAL,
        nullptr
    );

    if (hFile == INVALID_HANDLE_VALUE) {
        return;
    }

    static const char s_defaultConfig[] =
        "[Settings]\r\n"
        "\r\n"
        "; ── Donanım ve Tıklama Eylemleri ──\r\n"
        "; Tıklama için maksimum bekleme süresi (milisaniye)\r\n"
        "DoubleTapMs=250\r\n"
        "\r\n"
        "; Basılı tutma için minimum süre (milisaniye)\r\n"
        "HoldMs=250\r\n"
        "\r\n"
        "; 1 Tık Eylemi (MicMute, PlayPause, NextTrack, PrevTrack, MasterMute, ToggleDeafen, LockScreen, None)\r\n"
        "Action1=MicMute\r\n"
        "\r\n"
        "; 2 Tık Eylemi\r\n"
        "Action2=PlayPause\r\n"
        "\r\n"
        "; 3 Tık Eylemi\r\n"
        "Action3=NextTrack\r\n"
        "\r\n"
        "; 4 Tık Eylemi\r\n"
        "Action4=None\r\n"
        "\r\n"
        "; Basılı Tutma Eylemi (PushToTalk: bas-konuş, CustomApp: özel uygulama/URL)\r\n"
        "HoldAction=PushToTalk\r\n"
        "\r\n"
        "; CustomApp seçildiğinde açılacak uygulama yolu veya URL\r\n"
        "CustomAppPath=\r\n"
        "\r\n"
        "; ── Sistem ve Başlangıç ──\r\n"
        "; Dil / Language (tr = Türkçe, en = English)\r\n"
        "Language=tr\r\n"
        "\r\n"
        "; Windows başlangıcında otomatik çalıştır (1 = Açık, 0 = Kapalı)\r\n"
        "AutoStart=1\r\n"
        "\r\n"
        "; Ses Efektleri (Mikrofon susturulduğunda/açıldığında Windows sesini çal)\r\n"
        "SoundFxEnabled=1\r\n"
        "\r\n"
        "; ── Spotify ve OSD Ayarları ──\r\n"
        "; Spotify Şarkı Değişiminde OSD Göster (1 = Açık, 0 = Kapalı)\r\n"
        "SpotifyTrackOsd=1\r\n"
        "\r\n"
        "; OSD Konumu: TopLeft, TopRight, BottomLeft, BottomRight, Center\r\n"
        "OsdPosition=TopLeft\r\n"
        "\r\n"
        "; OSD Metin Rengi (hex, # olmadan)\r\n"
        "OsdColor=00E5FF\r\n"
        "\r\n"
        "; OSD Font Boyutu (varsayılan: 10)\r\n"
        "OsdFontSize=10\r\n"
        "\r\n"
        "; OSD Gösterim Süresi (milisaniye, varsayılan: 1500)\r\n"
        "OsdDurationMs=1500\r\n"
        "\r\n"
        "; OSD Fade Animasyonu (1 = Açık, 0 = Kapalı)\r\n"
        "OsdFadeEnabled=1\r\n";

    DWORD written = 0;
    WriteFile(hFile, s_defaultConfig, sizeof(s_defaultConfig) - 1, &written, nullptr);
    CloseHandle(hFile);
}

void ConfigManager::Load() {
    EnsureConfigExists(m_path);
    Config c;
    const wchar_t* p = m_path.c_str();

    c.doubleTapMs   = ReadInt(p, L"DoubleTapMs", 250);
    c.holdMs        = ReadInt(p, L"HoldMs",      250);

    c.action1       = ParseAction(ReadStr(p, L"Action1", L"MicMute"));
    c.action2       = ParseAction(ReadStr(p, L"Action2", L"PlayPause"));
    c.action3       = ParseAction(ReadStr(p, L"Action3", L"NextTrack"));
    c.action4       = ParseAction(ReadStr(p, L"Action4", L"None"));
    c.holdAction    = ParseHoldAction(ReadStr(p, L"HoldAction", L"PushToTalk"));
    c.customAppPath = ReadStr(p, L"CustomAppPath");
    c.soundFxEnabled = (ReadInt(p, L"SoundFxEnabled", 1) != 0);
    c.autoStart      = (ReadInt(p, L"AutoStart", 1) != 0);
    c.language       = ReadStr(p, L"Language", L"tr");
    SetAutoStartRegistry(c.autoStart);

    // OSD Ayarları
    c.osdPosition     = ReadStr(p, L"OsdPosition", L"TopLeft");
    c.osdColorHex     = ReadStr(p, L"OsdColor", L"B388FF");
    c.osdColor        = HexToColor(c.osdColorHex, RGB(179, 136, 255));
    c.osdFontSize     = static_cast<int>(ReadInt(p, L"OsdFontSize", 10));
    c.osdDurationMs   = ReadInt(p, L"OsdDurationMs", 1500);
    c.osdFadeEnabled  = (ReadInt(p, L"OsdFadeEnabled", 1) != 0);
    c.spotifyTrackOsd = (ReadInt(p, L"SpotifyTrackOsd", 1) != 0);

    {
        std::lock_guard<std::mutex> lk(m_mu);
        m_cfg = c;
    }
}

void ConfigManager::Start() {
    Load();

    m_stopEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);

    // Arka plan izleyici iş parçacığı
    m_thread = CreateThread(nullptr, 0, [](LPVOID ctx) -> DWORD {
        static_cast<ConfigManager*>(ctx)->WatcherThread();
        return 0;
    }, this, 0, nullptr);
}

Config ConfigManager::GetConfig() const {
    std::lock_guard<std::mutex> lk(m_mu);
    return m_cfg;
}

// ─────────────────────────────────────────────
//  Hot-reload: FindFirstChangeNotificationW
//  Disk polling YAPILMAZ.
// ─────────────────────────────────────────────
void ConfigManager::WatcherThread() {
    HANDLE hChange = FindFirstChangeNotificationW(
        m_dir.c_str(),
        FALSE,                           // Alt dizinleri izleme
        FILE_NOTIFY_CHANGE_LAST_WRITE);

    if (hChange == INVALID_HANDLE_VALUE)
        return;

    HANDLE handles[2] = { hChange, m_stopEvent };

    for (;;) {
        DWORD w = WaitForMultipleObjects(2, handles, FALSE, INFINITE);

        if (w == WAIT_OBJECT_0) {
            // config.ini değişti – küçük bir debounce bekle
            Sleep(80);
            Load();
            FindNextChangeNotification(hChange);
        } else {
            // WAIT_OBJECT_0 + 1 = durdurma olayı
            break;
        }
    }

    FindCloseChangeNotification(hChange);
}
