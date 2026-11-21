#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <atomic>
#include <condition_variable>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
#include "Config.hpp"

enum class MediaCardButton {
    None = 0,
    Prev,
    PlayPause,
    Next
};

enum class MediaLayoutMode {
    Full = 0,
    CompactControls,
    MiniPlay
};

class OsdManager {
public:
    static OsdManager& Instance();

    void Init(HWND hostWnd);
    void UpdateConfig(const Config& cfg);
    void Destroy();

    // Eylem bildirimi (ShowTip)
    void ShowTip(const std::wstring& msg, DWORD durationMs = 0);

    // Medya parça değişim ve sürekli gösterim bildirimi
    void ShowMediaTrack(const std::wstring& songTitle,
                        const std::wstring& artistName = L"Media",
                        bool isPlaying = true,
                        DWORD durationMs = 0,
                        const std::vector<uint8_t>& thumbnailData = {});
    void HideMediaTrack();
    void CheckFullscreenAndTaskbarState();
    void OnTaskbarRecreated();
    void OnTaskbarLayoutUpdated();
    void RefreshTaskbarLayout(DWORD delayMs = 80);

private:
    struct TaskbarFreeBounds {
        bool valid          = false;
        bool isLeftAligned  = false;
        RECT tbRect         = {};
        int  leftSlotLeft   = 0;
        int  leftSlotRight  = 0;
        int  rightSlotLeft  = 0;
        int  rightSlotRight = 0;

        bool operator==(const TaskbarFreeBounds& o) const {
            return valid == o.valid &&
                   isLeftAligned == o.isLeftAligned &&
                   tbRect.left == o.tbRect.left && tbRect.top == o.tbRect.top &&
                   tbRect.right == o.tbRect.right && tbRect.bottom == o.tbRect.bottom &&
                   leftSlotLeft == o.leftSlotLeft && leftSlotRight == o.leftSlotRight &&
                   rightSlotLeft == o.rightSlotLeft && rightSlotRight == o.rightSlotRight;
        }
        bool operator!=(const TaskbarFreeBounds& o) const { return !(*this == o); }
    };

    OsdManager() = default;
    ~OsdManager();

    // ── Tip Penceresi (Aksiyon Bildirimi) ─────────────────────────────
    bool CreateTipWindow();
    void PositionTipWindow(int textW, int textH);
    void OnPaintTip(HWND hwnd);
    static LRESULT CALLBACK TipWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

    // ── Medya Kart Penceresi ──────────────────────────────────────────
    bool CreateMediaWindow();
    bool PositionMediaWindow(int textW, int textH);
    void OnPaintMedia(HWND hwnd);
    static LRESULT CALLBACK MediaWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

    // Arka plan görev çubuğu düzeni ölçümü (UIA)
    void StartTaskbarProbe();
    void StopTaskbarProbe();
    void TaskbarProbeLoop();

    // Buton geometrisi ve tıklama tespiti
    RECT GetPrevBtnRect(int w, int h) const;
    RECT GetPlayBtnRect(int w, int h) const;
    RECT GetNextBtnRect(int w, int h) const;
    MediaCardButton HitTestMediaButton(int x, int y, int w, int h) const;

    // Tam ekran ve görev çubuğu denetimi
    static bool IsFullscreenAppActive(HWND selfWnd);
    static bool IsTaskbarVisible();

    HWND         m_hostWnd       = nullptr;
    Config       m_cfg;

    // Tip penceresi durumu
    HWND         m_tipHwnd       = nullptr;
    std::wstring m_tipText;
    int          m_tipWidth      = 0;
    int          m_tipHeight     = 0;
    int          m_tipAlpha      = 0;
    DWORD        m_tipDuration   = 1500;

    // Medya kart penceresi durumu
    HWND         m_mediaHwnd              = nullptr;
    std::wstring m_mediaTitle;
    std::wstring m_mediaArtist;
    int          m_mediaX                 = 0;
    int          m_mediaY                 = 0;
    int          m_mediaWidth             = 0;
    int          m_mediaHeight            = 0;
    int          m_mediaTextW             = 0;
    int          m_mediaAlpha             = 0;
    DWORD        m_mediaDuration          = 2800;
    bool         m_hasActiveMedia         = false;
    bool         m_isMediaPlaying         = false;
    MediaLayoutMode m_mediaLayoutMode     = MediaLayoutMode::Full;
    MediaCardButton m_hoveredMediaBtn     = MediaCardButton::None;
    bool         m_isTrackingMouse        = false;
    bool         m_suppressedByFullscreen = false;
    bool         m_suppressedBySpace      = false;
    HBITMAP      m_mediaThumbBmp          = nullptr;
    int          m_mediaThumbSize         = 0;
    std::vector<uint8_t> m_mediaThumbData;

    // Arka plan görev çubuğu boş alan izleme durumu
    mutable std::mutex      m_tbBoundsMutex;
    TaskbarFreeBounds       m_tbBounds;
    std::atomic<bool>       m_probeRunning{ false };
    std::atomic<bool>       m_probeActive{ false };
    std::mutex              m_probeWakeMutex;
    std::condition_variable m_probeWakeCv;
    bool                    m_probeRequested = false;
    bool                    m_probePending = false;
    ULONGLONG               m_probeFirstReqMs = 0;
    ULONGLONG               m_probeRunAtMs = 0;
    std::thread             m_probeThread;
};
