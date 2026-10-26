#pragma once
#include <string>

inline bool IsEnglish(const std::wstring& lang) {
    return lang == L"en" || lang == L"EN" || lang == L"en-US" || lang == L"en-GB";
}

namespace I18n {
    inline std::wstring MicMuted(const std::wstring& lang) {
        return IsEnglish(lang) ? L"🎙️ Microphone Muted (MUTE)" : L"🎙️ Mikrofon Susturuldu (MUTE)";
    }
    inline std::wstring MicUnmuted(const std::wstring& lang) {
        return IsEnglish(lang) ? L"🎙️ Microphone Unmuted (UNMUTE)" : L"🎙️ Mikrofon Açıldı (UNMUTE)";
    }
    inline std::wstring MasterMuted(const std::wstring& lang) {
        return IsEnglish(lang) ? L"🔇 System Sound Muted (MUTE)" : L"🔇 Sistem Sesi Kapatıldı (MUTE)";
    }
    inline std::wstring MasterUnmuted(const std::wstring& lang) {
        return IsEnglish(lang) ? L"🔊 System Sound Unmuted (UNMUTE)" : L"🔊 Sistem Sesi Açıldı (UNMUTE)";
    }
    inline std::wstring Deafened(const std::wstring& lang) {
        return IsEnglish(lang) ? L"🔕 Deafened (Audio & Mic Muted)" : L"🔕 Sağırlaştırıldı (Ses & Mic Kapalı)";
    }
    inline std::wstring Undeafened(const std::wstring& lang) {
        return IsEnglish(lang) ? L"🔔 Undeafened (Audio & Mic Unmuted)" : L"🔔 Sağırlaştırma Kaldırıldı (Ses & Mic Açık)";
    }
    inline std::wstring DeafenUpdated(const std::wstring& lang) {
        return IsEnglish(lang) ? L"🔕 Sound & Mic Updated" : L"🔕 Ses & Mikrofon Güncellendi";
    }
    inline std::wstring PlayPause(const std::wstring& lang) {
        return IsEnglish(lang) ? L"⏯️ Play / Pause" : L"⏯️ Oynat / Duraklat";
    }
    inline std::wstring NextTrack(const std::wstring& lang) {
        return IsEnglish(lang) ? L"⏭️ Next Track" : L"⏭️ Sonraki Parça";
    }
    inline std::wstring PrevTrack(const std::wstring& lang) {
        return IsEnglish(lang) ? L"⏮️ Previous Track" : L"⏮️ Önceki Parça";
    }
    inline std::wstring LockScreen(const std::wstring& lang) {
        return IsEnglish(lang) ? L"🔒 Locking PC..." : L"🔒 Bilgisayar Kilitleniyor...";
    }
    inline std::wstring CustomAppNotSet(const std::wstring& lang) {
        return IsEnglish(lang) ? L"⚠️ Custom application path not set!" : L"⚠️ Özel uygulama yolu ayarlanmamış!";
    }
    inline std::wstring LaunchingApp(const std::wstring& lang, const std::wstring& appName) {
        return IsEnglish(lang) ? (L"🚀 Launching " + appName + L"...") : (L"🚀 " + appName + L" açılıyor...");
    }
    inline std::wstring DefaultAppName(const std::wstring& lang) {
        return IsEnglish(lang) ? L"Application" : L"Uygulama";
    }
    inline std::wstring PttActive(const std::wstring& lang) {
        return IsEnglish(lang) ? L"🎙️ PTT — Mic Active (speaking...)" : L"🎙️ PTT — Mikrofon Açık (konuş...)";
    }
    inline std::wstring PttMuted(const std::wstring& lang) {
        return IsEnglish(lang) ? L"🎙️ PTT — Mic Muted" : L"🎙️ PTT — Mikrofon Susturuldu";
    }
    inline std::wstring TrayTip(const std::wstring& lang) {
        return IsEnglish(lang) ? L"Copilot Button Controller" : L"Copilot Button Denetleyicisi";
    }
    inline std::wstring TraySettings(const std::wstring& lang) {
        return IsEnglish(lang) ? L"⚙️  Settings" : L"⚙️  Ayarlar";
    }
    inline std::wstring TrayExit(const std::wstring& lang) {
        return IsEnglish(lang) ? L"❌  Exit" : L"❌  Çıkış";
    }
    inline std::wstring UpdateFound(const std::wstring& lang, const std::wstring& ver) {
        return IsEnglish(lang) ? (L"New Version Available: " + ver) : (L"Yeni Sürüm Mevcut: " + ver);
    }
    inline const wchar_t* BrowseFilter(const std::wstring& lang) {
        return IsEnglish(lang)
            ? L"Applications (*.exe)\0*.exe\0All Files (*.*)\0*.*\0"
            : L"Programlar (*.exe)\0*.exe\0Tüm Dosyalar (*.*)\0*.*\0";
    }
}
