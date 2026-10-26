// SpotifyTracker.cpp – Windows Media Transport Controls (GSMTC) tabanlı şarkı takibi
// Pencere tarama (EnumWindows) yerine modern, sıfır CPU tüketen olay tabanlı Windows Media API kullanır.

#include "SpotifyTracker.hpp"
#include <cwctype>

#pragma comment(lib, "windowsapp.lib")

using namespace winrt::Windows::Media::Control;

SpotifyTracker::SpotifyTracker() {
    try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
    } catch (...) {}
}

SpotifyTracker::~SpotifyTracker() {
    Stop();
}

bool SpotifyTracker::Start(TrackChangeCallback cb) {
    Stop();
    m_callback = std::move(cb);

    try {
        m_sessionManager = GlobalSystemMediaTransportControlsSessionManager::RequestAsync().get();
        if (!m_sessionManager) return false;

        m_sessionsChangedToken = m_sessionManager.SessionsChanged([this](auto const&, auto const&) {
            UpdateCurrentSession();
        });

        UpdateCurrentSession();
        return true;
    } catch (...) {
        return false;
    }
}

void SpotifyTracker::Stop() {
    if (m_sessionManager) {
        try {
            if (m_sessionsChangedToken.value != 0) {
                m_sessionManager.SessionsChanged(m_sessionsChangedToken);
                m_sessionsChangedToken = {};
            }
        } catch (...) {}
    }

    UnregisterSessionEvents();
    m_currentSession = nullptr;
    m_sessionManager = nullptr;

    std::lock_guard<std::mutex> lk(m_mutex);
    m_currentTrack = {};
}

void SpotifyTracker::UnregisterSessionEvents() {
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

void SpotifyTracker::RegisterSessionEvents() {
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

void SpotifyTracker::UpdateCurrentSession() {
    UnregisterSessionEvents();

    if (!m_sessionManager) return;

    GlobalSystemMediaTransportControlsSession matchedSession{ nullptr };

    try {
        auto sessions = m_sessionManager.GetSessions();
        for (auto const& session : sessions) {
            std::wstring id = session.SourceAppUserModelId().c_str();
            std::wstring idLower = id;
            for (auto& c : idLower) {
                c = static_cast<wchar_t>(towlower(c));
            }

            if (idLower.find(L"spotify") != std::wstring::npos) {
                matchedSession = session;
                break;
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

void SpotifyTracker::SyncPlaybackInfo() {
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

void SpotifyTracker::SyncMediaProperties() {
    if (!m_currentSession) return;

    try {
        auto props = m_currentSession.TryGetMediaPropertiesAsync().get();
        if (!props) return;

        TrackInfo fresh;
        fresh.title  = props.Title().c_str();
        fresh.artist = props.Artist().c_str();
        fresh.album  = props.AlbumTitle().c_str();

        if (!fresh.artist.empty() && !fresh.title.empty()) {
            fresh.fullTitle = fresh.artist + L" - " + fresh.title;
        } else if (!fresh.title.empty()) {
            fresh.fullTitle = fresh.title;
        } else {
            fresh.fullTitle = L"Spotify";
        }

        auto playbackInfo = m_currentSession.GetPlaybackInfo();
        fresh.isPlaying = playbackInfo && (playbackInfo.PlaybackStatus() == GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing);

        bool changed = false;
        {
            std::lock_guard<std::mutex> lk(m_mutex);
            if (m_currentTrack.title != fresh.title ||
                m_currentTrack.artist != fresh.artist ||
                m_currentTrack.album != fresh.album ||
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

TrackInfo SpotifyTracker::GetCurrentTrack() const {
    std::lock_guard<std::mutex> lk(m_mutex);
    return m_currentTrack;
}