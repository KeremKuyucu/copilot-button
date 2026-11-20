#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <thread>

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
    struct Impl;

    std::shared_ptr<Impl> m_impl;
    std::thread           m_workerThread;
    std::thread           m_thumbThread;
};
