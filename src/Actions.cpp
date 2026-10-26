// Actions.cpp – Eylem dağıtıcı ve anlık OSD gösterimi
#include "Actions.hpp"
#include "Config.hpp"
#include "Audio.hpp"
#include "Osd.hpp"
#include <windows.h>
#include <shellapi.h>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")

static std::wstring GetAppName(const std::wstring& path) {
    if (path.find(L"Gemini") != std::wstring::npos) return L"Gemini";
    if (path.find(L"spotify:") != std::wstring::npos) return L"Spotify";
    size_t lastSlash = path.find_last_of(L"\\/");
    std::wstring name = (lastSlash != std::wstring::npos) ? path.substr(lastSlash + 1) : path;
    if (name.length() > 4 && name.substr(name.length() - 4) == L".exe") {
        name = name.substr(0, name.length() - 4);
    }
    return name.empty() ? L"Application" : name;
}

static void LaunchCustomApp(const std::wstring& path) {
    if (path.empty()) {
        OsdManager::Instance().ShowTip(L"⚠️ Custom app path not set");
        return;
    }
    std::wstring name = GetAppName(path);
    OsdManager::Instance().ShowTip(L"🚀 Launching " + name);
    ShellExecuteW(nullptr, L"open", path.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
}

void DispatchAction(Action act, const std::wstring& customAppPath, bool soundFx) {
    auto& osd = OsdManager::Instance();

    switch (act) {
        case Action::MicMute: {
            ToggleMicMute();
            bool isMuted = GetMicMuteState();
            if (soundFx) PlayMicSound(isMuted);
            osd.ShowTip(isMuted ? L"🎙️ Mic Muted" : L"🎙️ Mic Unmuted");
            break;
        }

        case Action::MasterMute: {
            ToggleMasterMute();
            bool isMuted = GetMasterMuteState();
            osd.ShowTip(isMuted ? L"🔇 Sound Muted" : L"🔊 Sound Unmuted");
            break;
        }

        case Action::ToggleDeafen: {
            ToggleDeafen();
            bool mic = GetMicMuteState();
            bool master = GetMasterMuteState();
            if (soundFx) PlayMicSound(mic);
            if (mic && master)
                osd.ShowTip(L"🔕 Deafened");
            else if (!mic && !master)
                osd.ShowTip(L"🔔 Undeafened");
            else
                osd.ShowTip(L"🔕 Sound & Mic Updated");
            break;
        }

        case Action::PlayPause:
            SendMediaKey(VK_MEDIA_PLAY_PAUSE);
            osd.ShowTip(L"⏯️ Play / Pause");
            break;

        case Action::NextTrack:
            SendMediaKey(VK_MEDIA_NEXT_TRACK);
            osd.ShowTip(L"⏭️ Next Track");
            break;

        case Action::PrevTrack:
            SendMediaKey(VK_MEDIA_PREV_TRACK);
            osd.ShowTip(L"⏮️ Prev Track");
            break;

        case Action::LockScreen:
            osd.ShowTip(L"🔒 Lock Screen", 1200);
            Sleep(200);
            LockWorkStation();
            break;

        case Action::CustomApp:
            LaunchCustomApp(customAppPath);
            break;

        case Action::None:
        default:
            break;
    }
}
