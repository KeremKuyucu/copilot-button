// Actions.cpp – Eylem dağıtıcı ve anlık OSD gösterimi
#include "Actions.hpp"
#include "Config.hpp"
#include "Audio.hpp"
#include "Osd.hpp"
#include "I18n.hpp"
#include <windows.h>
#include <shellapi.h>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")

static void MediaKey(WORD vk) {
    INPUT in[2] = {};
    in[0].type   = in[1].type   = INPUT_KEYBOARD;
    in[0].ki.wVk = in[1].ki.wVk = vk;
    in[1].ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(2, in, sizeof(INPUT));
}

static std::wstring GetAppName(const std::wstring& path, const std::wstring& lang) {
    if (path.find(L"Gemini") != std::wstring::npos) return L"Gemini";
    if (path.find(L"spotify:") != std::wstring::npos) return L"Spotify";
    size_t lastSlash = path.find_last_of(L"\\/");
    std::wstring name = (lastSlash != std::wstring::npos) ? path.substr(lastSlash + 1) : path;
    if (name.length() > 4 && name.substr(name.length() - 4) == L".exe") {
        name = name.substr(0, name.length() - 4);
    }
    return name.empty() ? I18n::DefaultAppName(lang) : name;
}

static void LaunchCustomApp(const std::wstring& path, const std::wstring& lang) {
    if (path.empty()) {
        OsdManager::Instance().ShowTip(I18n::CustomAppNotSet(lang));
        return;
    }
    std::wstring name = GetAppName(path, lang);
    OsdManager::Instance().ShowTip(I18n::LaunchingApp(lang, name));
    ShellExecuteW(nullptr, L"open", path.c_str(),
                  nullptr, nullptr, SW_SHOWNORMAL);
}

void DispatchAction(Action act, const std::wstring& customAppPath, bool soundFx, const std::wstring& lang) {
    auto& osd = OsdManager::Instance();

    switch (act) {
        case Action::MicMute: {
            ToggleMicMute();
            bool isMuted = GetMicMuteState();
            if (soundFx) PlayMicSound(isMuted);
            osd.ShowTip(isMuted ? I18n::MicMuted(lang) : I18n::MicUnmuted(lang));
            break;
        }

        case Action::MasterMute: {
            ToggleMasterMute();
            bool isMuted = GetMasterMuteState();
            osd.ShowTip(isMuted ? I18n::MasterMuted(lang) : I18n::MasterUnmuted(lang));
            break;
        }

        case Action::ToggleDeafen: {
            ToggleDeafen();
            bool mic = GetMicMuteState();
            bool master = GetMasterMuteState();
            if (soundFx) PlayMicSound(mic);
            if (mic && master)
                osd.ShowTip(I18n::Deafened(lang));
            else if (!mic && !master)
                osd.ShowTip(I18n::Undeafened(lang));
            else
                osd.ShowTip(I18n::DeafenUpdated(lang));
            break;
        }

        case Action::PlayPause:
            MediaKey(VK_MEDIA_PLAY_PAUSE);
            osd.ShowTip(I18n::PlayPause(lang));
            break;

        case Action::NextTrack:
            MediaKey(VK_MEDIA_NEXT_TRACK);
            osd.ShowTip(I18n::NextTrack(lang));
            break;

        case Action::PrevTrack:
            MediaKey(VK_MEDIA_PREV_TRACK);
            osd.ShowTip(I18n::PrevTrack(lang));
            break;

        case Action::LockScreen:
            osd.ShowTip(I18n::LockScreen(lang), 1200);
            Sleep(200);
            LockWorkStation();
            break;

        case Action::CustomApp:
            LaunchCustomApp(customAppPath, lang);
            break;

        case Action::None:
        default:
            break;
    }
}
