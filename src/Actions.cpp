// Actions.cpp – Eylem dağıtıcı ve anlık OSD gösterimi
#include "Actions.hpp"
#include "Config.hpp"
#include "Audio.hpp"
#include "Osd.hpp"
#include <windows.h>
#include <shellapi.h>
#include <thread>
#include <chrono>

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

static std::wstring ResolveAgyDirectory(const std::wstring& configuredPath) {
    if (!configuredPath.empty()) {
        wchar_t expanded[MAX_PATH] = {};
        if (ExpandEnvironmentStringsW(configuredPath.c_str(), expanded, MAX_PATH)) {
            return expanded;
        }
        return configuredPath;
    }

    wchar_t tempPath[MAX_PATH] = {};
    if (GetTempPathW(MAX_PATH, tempPath)) {
        size_t len = wcslen(tempPath);
        if (len > 0 && (tempPath[len - 1] == L'\\' || tempPath[len - 1] == L'/')) {
            tempPath[len - 1] = L'\0';
        }
        return tempPath;
    }

    return L".";
}

static void ExecuteRunAgy(const std::wstring& path, const std::wstring& cmd, DWORD delayMs) {
    OsdManager::Instance().ShowTip(L"⚡ AGY Terminal Başlatılıyor...");
    std::wstring targetDir = ResolveAgyDirectory(path);

    std::thread([targetDir, cmd, delayMs]() {
        // Güvenli ve doğrudan PowerShell terminal penceresi aç:
        // Windows 11'de varsayılan terminal Windows Terminal ise otomatik olarak onda açılır;
        // değilse standart konsol penceresinde açılır. Asla arka planda kilitlenip gizli kalmaz.
        std::wstring psArgs = L"-NoExit -Command \"Set-Location -LiteralPath '" + targetDir + L"'; " + cmd + L"\"";
        ShellExecuteW(
            nullptr,
            L"open",
            L"powershell.exe",
            psArgs.c_str(),
            targetDir.c_str(),
            SW_SHOWNORMAL
        );

        // 1 saniye (veya belirtilen gecikme süresi) bekle
        std::this_thread::sleep_for(std::chrono::milliseconds(delayMs));

        // Aktif olan terminal penceresine F5 tuş basımını gönder
        INPUT inputs[2] = {};
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].ki.wVk = VK_F5;
        inputs[0].ki.wScan = static_cast<WORD>(MapVirtualKeyW(VK_F5, MAPVK_VK_TO_VSC));
        inputs[0].ki.dwFlags = 0;

        inputs[1].type = INPUT_KEYBOARD;
        inputs[1].ki.wVk = VK_F5;
        inputs[1].ki.wScan = static_cast<WORD>(MapVirtualKeyW(VK_F5, MAPVK_VK_TO_VSC));
        inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;

        SendInput(2, inputs, sizeof(INPUT));
    }).detach();
}

void DispatchAction(Action act, const Config& cfg) {
    auto& osd = OsdManager::Instance();

    switch (act) {
        case Action::MicMute: {
            ToggleMicMute();
            bool isMuted = GetMicMuteState();
            if (cfg.soundFxEnabled) PlayMicSound(isMuted);
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
            if (cfg.soundFxEnabled) PlayMicSound(mic);
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
            LaunchCustomApp(cfg.customAppPath);
            break;

        case Action::RunAgy:
            ExecuteRunAgy(cfg.agyPath, cfg.agyCommand, cfg.agyDelayMs);
            break;

        case Action::PushToTalk:
        case Action::None:
        default:
            break;
    }
}

void DispatchAction(Action act, const std::wstring& customAppPath, bool soundFx) {
    Config cfg;
    cfg.customAppPath = customAppPath;
    cfg.soundFxEnabled = soundFx;
    DispatchAction(act, cfg);
}
