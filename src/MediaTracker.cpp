// MediaTracker.cpp – Windows Media Transport Controls (GSMTC) tabanlı evrensel medya takibi
// Spotify, Chrome, Edge, YouTube, Apple Music, VLC ve tüm Windows medya oturumlarını destekler.

#include "MediaTracker.hpp"
#include <cwctype>
#include <algorithm>

#pragma comment(lib, "windowsapp.lib")

using namespace winrt::Windows::Media::Control;

static std::wstring GetFriendlyMediaSource(const std::wstring& aumid) {
    if (aumid.empty()) return L"Media";

    std::wstring lower = aumid;
    for (auto& c : lower) {
        c = static_cast<wchar_t>(towlower(c));
    }

    if (lower.find(L"spotify") != std::wstring::npos) return L"Spotify";
    if (lower.find(L"chrome") != std::wstring::npos) return L"Chrome";
    if (lower.find(L"edge") != std::wstring::npos) return L"Edge";
    if (lower.find(L"firefox") != std::wstring::npos) return L"Firefox";
    if (lower.find(L"brave") != std::wstring::npos) return L"Brave";
    if (lower.find(L"opera") != std::wstring::npos) return L"Opera";
    if (lower.find(L"applemusic") != std::wstring::npos) return L"Apple Music";
    if (lower.find(L"itunes") != std::wstring::npos) return L"iTunes";
    if (lower.find(L"vlc") != std::wstring::npos) return L"VLC";
    if (lower.find(L"musicbee") != std::wstring::npos) return L"MusicBee";
    if (lower.find(L"foobar") != std::wstring::npos) return L"Foobar2000";
    if (lower.find(L"deezer") != std::wstring::npos) return L"Deezer";
    if (lower.find(L"tidal") != std::wstring::npos) return L"Tidal";
    if (lower.find(L"zune") != std::wstring::npos || lower.find(L"media player") != std::wstring::npos) return L"Media Player";

    size_t lastSlash = aumid.find_last_of(L"\\/");
    std::wstring name = (lastSlash != std::wstring::npos) ? aumid.substr(lastSlash + 1) : aumid;
    if (name.length() > 4 && name.substr(name.length() - 4) == L".exe") {
        name = name.substr(0, name.length() - 4);
    }
    return name.empty() ? L"Media" : name;
}

MediaTracker::MediaTracker() {
    try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
    } catch (...) {}
}

MediaTracker::~MediaTracker() {
    Stop();
}

bool MediaTracker::Start(TrackChangeCallback cb) {
    Stop();
    m_callback = std::move(cb);

    try {
        m_sessionManager = GlobalSystemMediaTransportControlsSessionManager::RequestAsync().get();
        if (!m_sessionManager) return false;

        m_sessionsChangedToken = m_sessionManager.SessionsChanged([this](auto const&, auto const&) {
            UpdateCurrentSession();
        });

        m_currentSessionChangedToken = m_sessionManager.CurrentSessionChanged([this](auto const&, auto const&) {
            UpdateCurrentSession();
        });

        UpdateCurrentSession();
        return true;
    } catch (...) {
        return false;
    }
}

void MediaTracker::Stop() {
    if (m_sessionManager) {
        try {
            if (m_sessionsChangedToken.value != 0) {
                m_sessionManager.SessionsChanged(m_sessionsChangedToken);
                m_sessionsChangedToken = {};
            }
            if (m_currentSessionChangedToken.value != 0) {
                m_sessionManager.CurrentSessionChanged(m_currentSessionChangedToken);
                m_currentSessionChangedToken = {};
            }
        } catch (...) {}
    }

    UnregisterSessionEvents();
    m_currentSession = nullptr;
    m_sessionManager = nullptr;

    std::lock_guard<std::mutex> lk(m_mutex);
    m_currentTrack = {};
}

void MediaTracker::UnregisterSessionEvents() {
    if (m_currentSession) {
        try {
            if (m_mediaPropertiesToken.value != 0) {
                m_currentSession.MediaPropertiesChanged(m_mediaPropertiesToken);
                m_mediaPropertiesToken = {};
            }
            if (m_playbackInfoToken.value != 0) {
                m_currentSession.PlaybackInfoChanged(m_playbackInfoToken);
                m_playbackInfoToken = {};
            }
        } catch (...) {}
    }
}

void MediaTracker::RegisterSessionEvents() {
    if (!m_currentSession) return;

    try {
        m_mediaPropertiesToken = m_currentSession.MediaPropertiesChanged([this](auto const&, auto const&) {
            SyncMediaProperties();
        });

        m_playbackInfoToken = m_currentSession.PlaybackInfoChanged([this](auto const&, auto const&) {
            SyncPlaybackInfo();
        });
    } catch (...) {}
}

void MediaTracker::UpdateCurrentSession() {
    UnregisterSessionEvents();

    if (!m_sessionManager) return;

    GlobalSystemMediaTransportControlsSession matchedSession{ nullptr };

    try {
        // 1. Windows'un belirlediği aktif oturumu al
        matchedSession = m_sessionManager.GetCurrentSession();

        // 2. Eğer mevcut oturum yoksa veya çalmıyorsa, çalan bir oturum ara
        bool isPlaying = false;
        if (matchedSession) {
            try {
                auto pb = matchedSession.GetPlaybackInfo();
                if (pb && pb.PlaybackStatus() == GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing) {
                    isPlaying = true;
                }
            } catch (...) {}
        }

        if (!isPlaying) {
            auto sessions = m_sessionManager.GetSessions();
            for (auto const& session : sessions) {
                try {
                    auto pb = session.GetPlaybackInfo();
                    if (pb && pb.PlaybackStatus() == GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing) {
                        matchedSession = session;
                        break;
                    }
                } catch (...) {}
            }

            // Çalan oturum yoksa ilk oturumu al
            if (!matchedSession && sessions.Size() > 0) {
                matchedSession = sessions.GetAt(0);
            }
        }
    } catch (...) {}

    m_currentSession = matchedSession;

    if (m_currentSession) {
        RegisterSessionEvents();
        SyncPlaybackInfo();
        SyncMediaProperties();
    } else {
        TrackInfo emptyTrack;
        {
            std::lock_guard<std::mutex> lk(m_mutex);
            m_currentTrack = emptyTrack;
        }
        if (m_callback) m_callback(emptyTrack);
    }
}

void MediaTracker::SyncPlaybackInfo() {
    if (!m_currentSession) return;

    try {
        auto playbackInfo = m_currentSession.GetPlaybackInfo();
        if (!playbackInfo) return;

        bool playing = (playbackInfo.PlaybackStatus() == GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing);
        bool changed = false;
        TrackInfo copy;

        {
            std::lock_guard<std::mutex> lk(m_mutex);
            if (m_currentTrack.isPlaying != playing) {
                m_currentTrack.isPlaying = playing;
                changed = true;
            }
            copy = m_currentTrack;
        }

        if (changed && m_callback) {
            m_callback(copy);
        }
    } catch (...) {}
}

void MediaTracker::SyncMediaProperties() {
    if (!m_currentSession) return;

    try {
        auto props = m_currentSession.TryGetMediaPropertiesAsync().get();
        if (!props) return;

        TrackInfo fresh;
        fresh.title  = props.Title().c_str();
        fresh.artist = props.Artist().c_str();
        fresh.album  = props.AlbumTitle().c_str();

        std::wstring rawAumid = m_currentSession.SourceAppUserModelId().c_str();
        fresh.sourceApp = GetFriendlyMediaSource(rawAumid);

        if (fresh.artist.empty()) {
            fresh.artist = fresh.sourceApp;
        }

        if (!fresh.artist.empty() && !fresh.title.empty()) {
            fresh.fullTitle = fresh.artist + L" - " + fresh.title;
        } else if (!fresh.title.empty()) {
            fresh.fullTitle = fresh.title;
        } else {
            fresh.fullTitle = fresh.sourceApp;
        }

        auto playbackInfo = m_currentSession.GetPlaybackInfo();
        fresh.isPlaying = playbackInfo && (playbackInfo.PlaybackStatus() == GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing);

        bool changed = false;
        {
            std::lock_guard<std::mutex> lk(m_mutex);
            if (m_currentTrack.title != fresh.title ||
                m_currentTrack.artist != fresh.artist ||
                m_currentTrack.album != fresh.album ||
                m_currentTrack.sourceApp != fresh.sourceApp ||
                m_currentTrack.isPlaying != fresh.isPlaying) {
                m_currentTrack = fresh;
                changed = true;
            }
        }

        if (changed && m_callback) {
            m_callback(fresh);
        }
    } catch (...) {}
}

TrackInfo MediaTracker::GetCurrentTrack() const {
    std::lock_guard<std::mutex> lk(m_mutex);
    return m_currentTrack;
}
