#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <string>
#include <functional>
#include <mutex>

struct TrackInfo {
    std::wstring fullTitle;
    std::wstring artist;
    std::wstring title;
    bool         isPlaying = false;
};

using TrackChangeCallback = std::function<void(const TrackInfo&)>;

class SpotifyTracker {
public:
    SpotifyTracker() = default;
    ~SpotifyTracker();

    bool Start(TrackChangeCallback cb);
    void Stop();

    TrackInfo GetCurrentTrack() const;

private:
    void WorkerLoop();
    static TrackInfo QuerySpotifyWindow();

    TrackChangeCallback m_callback;
    HANDLE              m_thread    = nullptr;
    HANDLE              m_stopEvent = nullptr;

    mutable std::mutex  m_mutex;
    TrackInfo           m_currentTrack;
};
