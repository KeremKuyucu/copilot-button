#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <functional>
#include "Config.hpp"

// ─────────────────────────────────────────────
//  Timer ID'leri
// ─────────────────────────────────────────────
static constexpr UINT TIMER_ID_HOLD       = 1;  // Basılı tutma algılama (HoldMs)
static constexpr UINT TIMER_ID_MULTIPRESS = 2;  // Çok tık toplama (DoubleTapMs)
static constexpr UINT TIMER_ID_WIN_PASS   = 3;  // 25ms Win geçirme gecikmesi (PassModifiers)
static constexpr UINT TIMER_ID_SHIFT_PASS = 4;  // 15ms Shift geçirme gecikmesi (PassShiftOnly)

using ActionCallback = std::function<void(Action)>;

class KeyHook {
public:
    KeyHook() = default;
    ~KeyHook();

    bool Install(ActionCallback cb, HWND msgWnd);
    void Uninstall();
    void UpdateConfig(const Config& cfg);

private:
    static LRESULT CALLBACK LowLevelProc(int nCode, WPARAM wParam, LPARAM lParam);

    // Zamanlayıcı geri dönüşleri
    static void CALLBACK OnHoldTimer(HWND, UINT, UINT_PTR, DWORD);
    static void CALLBACK OnMultiPressTimer(HWND, UINT, UINT_PTR, DWORD);
    static void CALLBACK OnWinPassTimer(HWND, UINT, UINT_PTR, DWORD);
    static void CALLBACK OnShiftPassTimer(HWND, UINT, UINT_PTR, DWORD);

    // Modifier geçirme fonksiyonları (AHK PassModifiers & PassShiftOnly eşdeğerleri)
    void PassModifiers();
    void PassShiftOnly();

    static KeyHook* s_instance;

    HHOOK          m_hook        = nullptr;
    HWND           m_msgWnd      = nullptr;   // SetTimer için pencere
    ActionCallback m_callback;
    Config         m_cfg;

    // ── Tuş durumu ──────────────────────────────────────────────────
    bool  m_isKeyDown       = false;
    bool  m_holdTriggered   = false;
    bool  m_pttActive       = false;
    int   m_tapCount        = 0;

    // ── 3-State Anti-Leak Durum Makinesi (AHK 1:1 portu) ────────────
    enum class CopState   { Idle, Waiting, Copilot, Passed };
    enum class ShiftState { Idle, Waiting, Passed };

    CopState   m_copState            = CopState::Idle;
    ShiftState m_shiftState          = ShiftState::Idle;
    bool       m_winSuppressed       = false;
    bool       m_shiftSuppressed     = false;
    ULONGLONG  m_copilotJustReleased = 0;  // TickCount damgası (80ms trailing bastırma)
};
