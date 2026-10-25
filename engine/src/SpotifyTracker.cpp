// SpotifyTracker.cpp – Spotify şarkı değişimlerini izleyen arka plan modülü
#include "SpotifyTracker.hpp"
#include <algorithm>

#pragma comment(lib, "user32.lib")

SpotifyTracker::~SpotifyTracker() {
    Stop();
}

bool SpotifyTracker::Start(TrackChangeCallback cb) {
    Stop();
    m_callback = std::move(cb);

    m_stopEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!m_stopEvent) return false;

    m_thread = CreateThread(nullptr, 0, [](LPVOID ctx) -> DWORD {
        static_cast<SpotifyTracker*>(ctx)->WorkerLoop();
        return 0;
    }, this, 0, nullptr);

    return (m_thread != nullptr);
}

void SpotifyTracker::Stop() {
    if (m_stopEvent) {
        SetEvent(m_stopEvent);
        if (m_thread) {
            WaitForSingleObject(m_thread, 1500);
            CloseHandle(m_thread);
            m_thread = nullptr;
        }
        CloseHandle(m_stopEvent);
        m_stopEvent = nullptr;
    }
}

TrackInfo SpotifyTracker::GetCurrentTrack() const {
    std::lock_guard<std::mutex> lk(m_mutex);
    return m_currentTrack;
}

struct SpotifyEnumData {
    std::wstring foundTitle;
};

static BOOL CALLBACK EnumSpotifyWindowsProc(HWND hwnd, LPARAM lParam) {
    if (!IsWindowVisible(hwnd)) return TRUE;

    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid == 0) return TRUE;

    HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!hProc) return TRUE;

    wchar_t procPath[MAX_PATH] = {};
    DWORD size = MAX_PATH;
    BOOL qOk = QueryFullProcessImageNameW(hProc, 0, procPath, &size);
    CloseHandle(hProc);
    if (!qOk) return TRUE;

    // Spotify.exe olup olmadığını kontrol et
    if (!wcsstr(procPath, L"Spotify.exe") && !wcsstr(procPath, L"spotify.exe")) {
        return TRUE;
    }

    wchar_t title[512] = {};
    int len = GetWindowTextW(hwnd, title, 512);
    if (len <= 0) return TRUE;

    // AHK filtreleri: görünmeyen veya sistem pencerelerini ele
    if (wcscmp(title, L"Default IME") == 0 ||
        wcscmp(title, L"MSCTFIME UI") == 0 ||
        wcsstr(title, L"GDI+") != nullptr) {
        return TRUE;
    }

    auto* data = reinterpret_cast<SpotifyEnumData*>(lParam);
    data->foundTitle = title;
    return FALSE; // Ana başlık bulundu, aramayı bitir
}

TrackInfo SpotifyTracker::QuerySpotifyWindow() {
    SpotifyEnumData data;
    EnumWindows(EnumSpotifyWindowsProc, reinterpret_cast<LPARAM>(&data));

    TrackInfo info;
    info.fullTitle = data.foundTitle;

    if (info.fullTitle.empty() ||
        info.fullTitle == L"Spotify" ||
        info.fullTitle == L"Spotify Free" ||
        info.fullTitle == L"Spotify Premium") {
        info.isPlaying = false;
        info.artist    = L"Spotify";
        info.title     = L"";
        return info;
    }

    // "Sanatçı - Şarkı Adı" formatını ayrıştır
    size_t sep = info.fullTitle.find(L" - ");
    if (sep != std::wstring::npos) {
        info.artist    = info.fullTitle.substr(0, sep);
        info.title     = info.fullTitle.substr(sep + 3);
        info.isPlaying = true;
    } else {
        info.artist    = L"Spotify";
        info.title     = info.fullTitle;
        info.isPlaying = true;
    }

    return info;
}

void SpotifyTracker::WorkerLoop() {
    // İlk okuma
    {
        TrackInfo initial = QuerySpotifyWindow();
        std::lock_guard<std::mutex> lk(m_mutex);
        m_currentTrack = initial;
    }

    for (;;) {
        DWORD waitRes = WaitForSingleObject(m_stopEvent, 800);
        if (waitRes != WAIT_TIMEOUT) {
            break; // Stop sinyali geldi
        }

        TrackInfo fresh = QuerySpotifyWindow();
        bool changed = false;

        {
            std::lock_guard<std::mutex> lk(m_mutex);
            if (fresh.fullTitle != m_currentTrack.fullTitle) {
                m_currentTrack = fresh;
                changed = true;
            }
        }

        if (changed && m_callback) {
            m_callback(fresh);
        }
    }
}
