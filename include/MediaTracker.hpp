#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <string>
#include <vector>
#include <functional>
#include <mutex>
#include <thread>
#include <atomic>

// C++/WinRT başlıkları
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Control.h>

struct TrackInfo {
    std::wstring          artist;
    std::wstring          title;
    std::wstring          album;
    std::wstring          sourceApp;
    bool                  isPlaying = false;
    std::vector<uint8_t>  thumbnailData;
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
    void WorkerLoop();
    void UpdateCurrentSession();
    void RegisterSessionEvents();
    void UnregisterSessionEvents();
    void SyncMediaProperties();
    void SyncPlaybackInfo();

    TrackChangeCallback m_callback;
    mutable std::mutex  m_mutex;
    TrackInfo           m_currentTrack;

    std::mutex          m_sessionMutex;
    std::thread         m_workerThread;
    std::atomic<bool>   m_running{ false };

    // WinRT Media nesneleri
    winrt::Windows::Media::Control::GlobalSystemMediaTransportControlsSessionManager m_sessionManager{ nullptr };
    winrt::Windows::Media::Control::GlobalSystemMediaTransportControlsSession        m_currentSession{ nullptr };

    // Event dinleme token'ları
    winrt::event_token m_sessionsChangedToken{};
    winrt::event_token m_currentSessionChangedToken{};
    winrt::event_token m_mediaPropertiesToken{};
    winrt::event_token m_playbackInfoToken{};
};
