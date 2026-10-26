#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <string>
#include <functional>
#include <mutex>

// C++/WinRT başlıkları
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Control.h>

struct TrackInfo {
    std::wstring fullTitle;
    std::wstring artist;
    std::wstring title;
    std::wstring album;
    std::wstring sourceApp;
    bool         isPlaying = false;
};

using TrackChangeCallback = std::function<void(const TrackInfo&)>;

class MediaTracker {
public:
    MediaTracker();
    ~MediaTracker();

    // Kopyalama ve taşımayı devre dışı bırak
    MediaTracker(const MediaTracker&) = delete;
    MediaTracker& operator=(const MediaTracker&) = delete;

    bool Start(TrackChangeCallback cb);
    void Stop();

    TrackInfo GetCurrentTrack() const;

private:
    void UpdateCurrentSession();
    void RegisterSessionEvents();
    void UnregisterSessionEvents();
    void SyncMediaProperties();
    void SyncPlaybackInfo();

    TrackChangeCallback m_callback;
    mutable std::mutex  m_mutex;
    TrackInfo           m_currentTrack;

    // WinRT Media nesneleri
    winrt::Windows::Media::Control::GlobalSystemMediaTransportControlsSessionManager m_sessionManager{ nullptr };
    winrt::Windows::Media::Control::GlobalSystemMediaTransportControlsSession        m_currentSession{ nullptr };

    // Event dinleme token'ları
    winrt::event_token m_sessionsChangedToken{};
    winrt::event_token m_currentSessionChangedToken{};
    winrt::event_token m_mediaPropertiesToken{};
    winrt::event_token m_playbackInfoToken{};
};

// Geriye dönük uyumluluk takma adı
using SpotifyTracker = MediaTracker;
