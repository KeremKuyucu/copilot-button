// MediaTracker.cpp – Windows Media Transport Controls (GSMTC) tabanlı evrensel medya takibi
// Spotify, Chrome, Edge, YouTube, Apple Music, VLC ve tüm Windows medya oturumlarını destekler.

#include "MediaTracker.hpp"
#include <cwctype>
#include <algorithm>
#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <mutex>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Control.h>
#include <winrt/Windows.Storage.Streams.h>

#pragma comment(lib, "windowsapp.lib")

using namespace winrt::Windows::Media::Control;
using namespace winrt::Windows::Storage::Streams;

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

struct MediaTracker::Impl : std::enable_shared_from_this<Impl> {
    struct PendingThumb {
        IRandomAccessStreamReference ref{ nullptr };
        std::wstring                 trackTitle;
        uint64_t                     generation = 0;
        bool                         hasPending = false;
    };

    std::atomic<bool>   running{ false };

    std::mutex          cbMutex;
    TrackChangeCallback callback;

    mutable std::mutex  trackMutex;
    TrackInfo           currentTrack;

    std::mutex          sessionMutex;
    GlobalSystemMediaTransportControlsSessionManager sessionManager{ nullptr };
    GlobalSystemMediaTransportControlsSession        currentSession{ nullptr };
    winrt::event_token  sessionsChangedToken{};
    winrt::event_token  currentSessionChangedToken{};
    winrt::event_token  mediaPropertiesToken{};
    winrt::event_token  playbackInfoToken{};

    std::mutex              thumbMutex;
    std::condition_variable thumbCv;
    PendingThumb            pendingThumb;
    uint64_t                thumbGen = 0;

    void EmitCallback(const TrackInfo& info) {
        if (!running.load()) return;
        TrackChangeCallback cb;
        {
            std::lock_guard<std::mutex> lk(cbMutex);
            cb = callback;
        }
        if (cb && running.load()) {
            cb(info);
        }
    }

    // sessionMutex kilidi altında çağrılmalıdır
    void UnregisterSessionEventsLocked() {
        if (currentSession) {
            try {
                if (mediaPropertiesToken.value != 0) {
                    currentSession.MediaPropertiesChanged(mediaPropertiesToken);
                    mediaPropertiesToken = {};
                }
                if (playbackInfoToken.value != 0) {
                    currentSession.PlaybackInfoChanged(playbackInfoToken);
                    playbackInfoToken = {};
                }
            } catch (...) {}
        }
    }

    // sessionMutex kilidi altında çağrılmalıdır
    void RegisterSessionEventsLocked() {
        if (!currentSession) return;

        std::weak_ptr<Impl> weak = weak_from_this();
        try {
            mediaPropertiesToken = currentSession.MediaPropertiesChanged([weak](auto const&, auto const&) {
                auto self = weak.lock();
                if (!self || !self->running.load()) return;
                GlobalSystemMediaTransportControlsSession sess{ nullptr };
                {
                    std::lock_guard<std::mutex> lk(self->sessionMutex);
                    sess = self->currentSession;
                }
                if (sess) self->SyncMediaProperties(sess);
            });

            playbackInfoToken = currentSession.PlaybackInfoChanged([weak](auto const&, auto const&) {
                auto self = weak.lock();
                if (!self || !self->running.load()) return;
                GlobalSystemMediaTransportControlsSession sess{ nullptr };
                {
                    std::lock_guard<std::mutex> lk(self->sessionMutex);
                    sess = self->currentSession;
                }
                if (sess) self->SyncPlaybackInfo(sess);
            });
        } catch (...) {}
    }

    void WorkerLoop() {
        try {
            winrt::init_apartment(winrt::apartment_type::multi_threaded);
        } catch (...) {}

        try {
            auto mgr = GlobalSystemMediaTransportControlsSessionManager::RequestAsync().get();
            if (!running.load()) return;

            std::weak_ptr<Impl> weak = weak_from_this();
            {
                std::lock_guard<std::mutex> lk(sessionMutex);
                if (!running.load()) return;
                sessionManager = mgr;
                if (!sessionManager) return;

                sessionsChangedToken = sessionManager.SessionsChanged([weak](auto const&, auto const&) {
                    auto self = weak.lock();
                    if (self && self->running.load()) self->UpdateCurrentSession();
                });

                currentSessionChangedToken = sessionManager.CurrentSessionChanged([weak](auto const&, auto const&) {
                    auto self = weak.lock();
                    if (self && self->running.load()) self->UpdateCurrentSession();
                });
            }

            UpdateCurrentSession();
        } catch (...) {}
    }

    void ThumbLoop() {
        try {
            winrt::init_apartment(winrt::apartment_type::multi_threaded);
        } catch (...) {}

        for (;;) {
            PendingThumb req;
            {
                std::unique_lock<std::mutex> lk(thumbMutex);
                thumbCv.wait(lk, [this]() {
                    return !running.load() || pendingThumb.hasPending;
                });
                if (!running.load()) break;
                req = std::move(pendingThumb);
                pendingThumb = {};
            }

            if (!req.ref) continue;

            try {
                auto stream = req.ref.OpenReadAsync().get();
                if (!running.load()) break;
                if (!stream) continue;

                uint64_t sz = stream.Size();
                if (sz == 0 || sz >= 10 * 1024 * 1024) continue;

                DataReader reader(stream);
                reader.LoadAsync(static_cast<uint32_t>(sz)).get();
                if (!running.load()) break;

                std::vector<uint8_t> bytes(sz);
                reader.ReadBytes(bytes);

                bool updated = false;
                TrackInfo copy;
                {
                    std::lock_guard<std::mutex> lk(trackMutex);
                    if (currentTrack.title == req.trackTitle && currentTrack.thumbnailData != bytes) {
                        currentTrack.thumbnailData = std::move(bytes);
                        copy = currentTrack;
                        updated = true;
                    }
                }

                if (updated && running.load()) {
                    EmitCallback(copy);
                }
            } catch (...) {}
        }
    }

    void UpdateCurrentSession() {
        if (!running.load()) return;

        GlobalSystemMediaTransportControlsSession matchedSession{ nullptr };
        {
            std::lock_guard<std::mutex> lkSession(sessionMutex);
            if (!sessionManager || !running.load()) return;

            UnregisterSessionEventsLocked();

            try {
                // 1. Windows'un belirlediği aktif oturumu al
                matchedSession = sessionManager.GetCurrentSession();

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
                    auto sessions = sessionManager.GetSessions();
                    for (auto const& session : sessions) {
                        try {
                            auto pb = session.GetPlaybackInfo();
                            if (pb && pb.PlaybackStatus() == GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing) {
                                matchedSession = session;
                                isPlaying = true;
                                break;
                            }
                        } catch (...) {}
                    }

                    // Çalan oturum yoksa, Spotify'ı veya bilinen müzik oynatıcısını tercih et
                    if (!isPlaying) {
                        GlobalSystemMediaTransportControlsSession spotifySession{ nullptr };
                        for (auto const& session : sessions) {
                            try {
                                std::wstring aumid = session.SourceAppUserModelId().c_str();
                                std::wstring friendly = GetFriendlyMediaSource(aumid);
                                if (friendly == L"Spotify") {
                                    spotifySession = session;
                                    break;
                                }
                            } catch (...) {}
                        }

                        if (spotifySession) {
                            matchedSession = spotifySession;
                        } else if (!matchedSession && sessions.Size() > 0) {
                            matchedSession = sessions.GetAt(0);
                        }
                    }
                }
            } catch (...) {}

            currentSession = matchedSession;
            if (currentSession) {
                RegisterSessionEventsLocked();
            }
        }

        if (matchedSession) {
            SyncPlaybackInfo(matchedSession);
            SyncMediaProperties(matchedSession);
        } else {
            TrackInfo emptyTrack;
            {
                std::lock_guard<std::mutex> lk(trackMutex);
                currentTrack = emptyTrack;
            }
            EmitCallback(emptyTrack);
        }
    }

    void SyncPlaybackInfo(GlobalSystemMediaTransportControlsSession const& session) {
        if (!running.load() || !session) return;

        try {
            auto playbackInfo = session.GetPlaybackInfo();
            if (!playbackInfo || !running.load()) return;

            bool playing = (playbackInfo.PlaybackStatus() == GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing);
            bool changed = false;
            TrackInfo copy;

            {
                std::lock_guard<std::mutex> lkSess(sessionMutex);
                if (currentSession != session) return;
            }

            {
                std::lock_guard<std::mutex> lk(trackMutex);
                if (currentTrack.isPlaying != playing) {
                    currentTrack.isPlaying = playing;
                    changed = true;
                }
                copy = currentTrack;
            }

            if (changed) {
                EmitCallback(copy);
            }
        } catch (...) {}
    }

    void SyncMediaProperties(GlobalSystemMediaTransportControlsSession const& session) {
        if (!running.load() || !session) return;

        try {
            auto props = session.TryGetMediaPropertiesAsync().get();
            if (!props || !running.load()) return;

            TrackInfo fresh;
            fresh.title  = props.Title().c_str();
            fresh.artist = props.Artist().c_str();
            fresh.album  = props.AlbumTitle().c_str();

            std::wstring rawAumid = session.SourceAppUserModelId().c_str();
            fresh.sourceApp = GetFriendlyMediaSource(rawAumid);

            if (fresh.artist.empty()) {
                fresh.artist = fresh.sourceApp;
            }

            auto playbackInfo = session.GetPlaybackInfo();
            fresh.isPlaying = playbackInfo && (playbackInfo.PlaybackStatus() == GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing);

            {
                std::lock_guard<std::mutex> lkSess(sessionMutex);
                if (currentSession != session || !running.load()) return;
            }

            bool changed = false;
            {
                std::lock_guard<std::mutex> lk(trackMutex);
                // Mevcut şarkının kapağını koru (yeni kapak arkada yüklenene kadar)
                if (currentTrack.title == fresh.title && !currentTrack.thumbnailData.empty()) {
                    fresh.thumbnailData = currentTrack.thumbnailData;
                }

                if (currentTrack.title != fresh.title ||
                    currentTrack.artist != fresh.artist ||
                    currentTrack.album != fresh.album ||
                    currentTrack.sourceApp != fresh.sourceApp ||
                    currentTrack.isPlaying != fresh.isPlaying) {
                    currentTrack = fresh;
                    changed = true;
                }
            }

            // Ana thread'i ASLA bloklamadan hemen bildir: Tuş yakalama ve tepsi anında çalışır
            if (changed) {
                EmitCallback(fresh);
            }

            // Albüm kapağı I/O okumasını tek adanmış arka plan iş parçacığında sıraya al
            try {
                auto thumbRef = props.Thumbnail();
                if (thumbRef && running.load()) {
                    {
                        std::lock_guard<std::mutex> lk(thumbMutex);
                        pendingThumb.ref        = thumbRef;
                        pendingThumb.trackTitle = fresh.title;
                        pendingThumb.generation = ++thumbGen;
                        pendingThumb.hasPending = true;
                    }
                    thumbCv.notify_one();
                }
            } catch (...) {}
        } catch (...) {}
    }

    void ShutdownWinRT() {
        {
            std::lock_guard<std::mutex> lkSession(sessionMutex);
            UnregisterSessionEventsLocked();
            if (sessionManager) {
                try {
                    if (sessionsChangedToken.value != 0) {
                        sessionManager.SessionsChanged(sessionsChangedToken);
                        sessionsChangedToken = {};
                    }
                    if (currentSessionChangedToken.value != 0) {
                        sessionManager.CurrentSessionChanged(currentSessionChangedToken);
                        currentSessionChangedToken = {};
                    }
                } catch (...) {}
            }
            currentSession = nullptr;
            sessionManager = nullptr;
        }

        {
            std::lock_guard<std::mutex> lkThumb(thumbMutex);
            pendingThumb = {};
        }

        {
            std::lock_guard<std::mutex> lkTrack(trackMutex);
            currentTrack = {};
        }
    }
};

MediaTracker::MediaTracker() = default;

MediaTracker::~MediaTracker() {
    Stop();
}

bool MediaTracker::Start(TrackChangeCallback cb) {
    Stop();

    auto impl = std::make_shared<Impl>();
    impl->callback = std::move(cb);
    impl->running.store(true);
    m_impl = impl;

    // Asenkron WinRT başlatma: UI / STA thread'ini ASLA bloklamaz!
    // Tuş yakalama kancası ve tepsi simgesi anında hazır olur.
    m_thumbThread = std::thread([impl]() {
        impl->ThumbLoop();
    });
    m_workerThread = std::thread([impl]() {
        impl->WorkerLoop();
    });

    return true;
}

void MediaTracker::Stop() {
    auto impl = std::move(m_impl);
    if (!impl) {
        if (m_workerThread.joinable()) m_workerThread.join();
        if (m_thumbThread.joinable()) m_thumbThread.join();
        return;
    }

    impl->running.store(false);
    {
        std::lock_guard<std::mutex> lk(impl->cbMutex);
        impl->callback = nullptr;
    }
    impl->thumbCv.notify_all();

    if (m_workerThread.joinable()) {
        m_workerThread.join();
    }
    if (m_thumbThread.joinable()) {
        m_thumbThread.join();
    }

    impl->ShutdownWinRT();
}

TrackInfo MediaTracker::GetCurrentTrack() const {
    auto impl = m_impl;
    if (!impl) return {};
    std::lock_guard<std::mutex> lk(impl->trackMutex);
    return impl->currentTrack;
}
