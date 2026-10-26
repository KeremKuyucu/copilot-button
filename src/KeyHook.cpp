// KeyHook.cpp – WH_KEYBOARD_LL tabanlı Copilot tuşu yakalama
// AutoHotkey KeyHook.ahk modülünden 1:1 portlanmış 3-State Anti-Leak mimarisi.
// ──────────────────────────────────────────────────────────────────
#include "KeyHook.hpp"
#include "Audio.hpp"
#include "Osd.hpp"
#include <shellapi.h>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")

// ─────────────────────────────────────────────
//  Copilot tuş kodları (F23 / SC06E / Launch_App1)
// ─────────────────────────────────────────────
static constexpr DWORD VK_COP1 = 0x86;   // VK_F23
static constexpr DWORD VK_COP2 = 0xB6;   // VK_LAUNCH_APP1
static constexpr DWORD SC_COP  = 0x06E;  // SC06E

// Kendi SendInput çağrılarımızı kesin olarak tanımak için sihirli imza.
// SADECE kendi ürettiğimiz tuşları izole etmek için kullanılır.
static constexpr ULONG_PTR MAGIC_INJECTED_TAG = 0xC0F1107;

// ─────────────────────────────────────────────
//  Singleton
// ─────────────────────────────────────────────
KeyHook* KeyHook::s_instance = nullptr;

// ─────────────────────────────────────────────
//  Yardımcılar
// ─────────────────────────────────────────────
static bool IsOurInjectedKey(const KBDLLHOOKSTRUCT* kb) {
    return (kb->dwExtraInfo == MAGIC_INJECTED_TAG);
}

static bool IsWinKey(DWORD vk) {
    return (vk == VK_LWIN || vk == VK_RWIN);
}

static bool IsShiftKey(DWORD vk) {
    return (vk == VK_LSHIFT || vk == VK_RSHIFT || vk == VK_SHIFT);
}

static bool IsCopilotKey(const KBDLLHOOKSTRUCT* kb) {
    return (kb->vkCode == VK_COP1 ||
            kb->vkCode == VK_COP2 ||
            (kb->scanCode & 0xFF) == SC_COP);
}

// ─────────────────────────────────────────────
//  Güvenli Tuş Enjeksiyonları (SendInput)
//  Tüm enjeksiyonlara MAGIC_INJECTED_TAG verilir,
//  böylece hook döngüsüne asla girmezler.
// ─────────────────────────────────────────────
static void SendKey(WORD vk, bool down) {
    INPUT in = {};
    in.type = INPUT_KEYBOARD;
    in.ki.wVk = vk;
    in.ki.wScan = static_cast<WORD>(MapVirtualKeyW(vk, MAPVK_VK_TO_VSC));
    in.ki.dwFlags = down ? 0 : KEYEVENTF_KEYUP;
    if (vk == VK_LWIN || vk == VK_RWIN) {
        in.ki.dwFlags |= KEYEVENTF_EXTENDEDKEY;
    }
    in.ki.dwExtraInfo = MAGIC_INJECTED_TAG;
    SendInput(1, &in, sizeof(INPUT));
}

static void SendWinDown() {
    SendKey(VK_LWIN, true);
}

static void SendWinUp() {
    SendKey(VK_LWIN, false);
}

static void SendShiftDown() {
    SendKey(VK_LSHIFT, true);
}

static void SendShiftUp() {
    SendKey(VK_LSHIFT, false);
}

// {Blind}{LWin Down}{LWin Up}
static void SendWinTap() {
    INPUT in[2] = {};
    in[0].type = in[1].type = INPUT_KEYBOARD;
    in[0].ki.wVk = in[1].ki.wVk = VK_LWIN;
    in[0].ki.wScan = in[1].ki.wScan = static_cast<WORD>(MapVirtualKeyW(VK_LWIN, MAPVK_VK_TO_VSC));
    in[0].ki.dwFlags = KEYEVENTF_EXTENDEDKEY;
    in[1].ki.dwFlags = KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP;
    in[0].ki.dwExtraInfo = in[1].ki.dwExtraInfo = MAGIC_INJECTED_TAG;
    SendInput(2, in, sizeof(INPUT));
}

// {Blind}{LWin Down}{LShift Down}{LShift Up}{LWin Up}
static void SendWinShiftTap() {
    INPUT in[4] = {};
    for (int i = 0; i < 4; ++i) in[i].type = INPUT_KEYBOARD;

    in[0].ki.wVk = VK_LWIN;
    in[0].ki.dwFlags = KEYEVENTF_EXTENDEDKEY;

    in[1].ki.wVk = VK_LSHIFT;
    in[1].ki.dwFlags = 0;

    in[2].ki.wVk = VK_LSHIFT;
    in[2].ki.dwFlags = KEYEVENTF_KEYUP;

    in[3].ki.wVk = VK_LWIN;
    in[3].ki.dwFlags = KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP;

    for (int i = 0; i < 4; ++i) in[i].ki.dwExtraInfo = MAGIC_INJECTED_TAG;
    SendInput(4, in, sizeof(INPUT));
}

// {Blind}{LShift Down}{LShift Up}
static void SendShiftTap() {
    INPUT in[2] = {};
    in[0].type = in[1].type = INPUT_KEYBOARD;
    in[0].ki.wVk = in[1].ki.wVk = VK_LSHIFT;
    in[0].ki.wScan = in[1].ki.wScan = static_cast<WORD>(MapVirtualKeyW(VK_LSHIFT, MAPVK_VK_TO_VSC));
    in[0].ki.dwFlags = 0;
    in[1].ki.dwFlags = KEYEVENTF_KEYUP;
    in[0].ki.dwExtraInfo = in[1].ki.dwExtraInfo = MAGIC_INJECTED_TAG;
    SendInput(2, in, sizeof(INPUT));
}

// {Blind}{LWin Down}{LShift Down}
static void SendWinAndShiftDown() {
    INPUT in[2] = {};
    in[0].type = in[1].type = INPUT_KEYBOARD;
    in[0].ki.wVk = VK_LWIN;
    in[0].ki.dwFlags = KEYEVENTF_EXTENDEDKEY;
    in[1].ki.wVk = VK_LSHIFT;
    in[1].ki.dwFlags = 0;
    in[0].ki.dwExtraInfo = in[1].ki.dwExtraInfo = MAGIC_INJECTED_TAG;
    SendInput(2, in, sizeof(INPUT));
}

// ─────────────────────────────────────────────
//  Kurulum / Kaldırma
// ─────────────────────────────────────────────
bool KeyHook::Install(ActionCallback cb, HWND msgWnd) {
    m_callback = std::move(cb);
    m_msgWnd   = msgWnd;
    s_instance = this;
    m_hook = SetWindowsHookExW(WH_KEYBOARD_LL, LowLevelProc, GetModuleHandleW(nullptr), 0);
    return m_hook != nullptr;
}

KeyHook::~KeyHook() { Uninstall(); }

void KeyHook::Uninstall() {
    if (m_hook) { UnhookWindowsHookEx(m_hook); m_hook = nullptr; }
    if (m_msgWnd) {
        KillTimer(m_msgWnd, TIMER_ID_HOLD);
        KillTimer(m_msgWnd, TIMER_ID_MULTIPRESS);
        KillTimer(m_msgWnd, TIMER_ID_WIN_PASS);
        KillTimer(m_msgWnd, TIMER_ID_SHIFT_PASS);
    }
}

void KeyHook::UpdateConfig(const Config& cfg) {
    m_cfg = cfg;
}

// ─────────────────────────────────────────────
//  AHK PassModifiers() eşdeğeri (25ms zamanlayıcı)
// ─────────────────────────────────────────────
void KeyHook::PassModifiers() {
    if (m_copState == CopState::Waiting) {
        m_copState = CopState::Passed;
        if (m_shiftSuppressed || m_shiftState == ShiftState::Waiting) {
            m_shiftSuppressed = false;
            m_shiftState = ShiftState::Passed;
            SendWinAndShiftDown();
        } else {
            SendWinDown();
        }
    }
}

// ─────────────────────────────────────────────
//  AHK PassShiftOnly() eşdeğeri (15ms zamanlayıcı)
// ─────────────────────────────────────────────
void KeyHook::PassShiftOnly() {
    if (m_shiftState == ShiftState::Waiting && m_copState != CopState::Copilot) {
        m_shiftState = ShiftState::Passed;
        SendShiftDown();
    }
}

void CALLBACK KeyHook::OnWinPassTimer(HWND hw, UINT, UINT_PTR, DWORD) {
    auto* h = s_instance;
    if (!h) return;
    KillTimer(hw, TIMER_ID_WIN_PASS);
    h->PassModifiers();
}

void CALLBACK KeyHook::OnShiftPassTimer(HWND hw, UINT, UINT_PTR, DWORD) {
    auto* h = s_instance;
    if (!h) return;
    KillTimer(hw, TIMER_ID_SHIFT_PASS);
    h->PassShiftOnly();
}

void CALLBACK KeyHook::OnHoldTimer(HWND hw, UINT, UINT_PTR, DWORD) {
    auto* h = s_instance;
    if (!h) return;
    KillTimer(hw, TIMER_ID_HOLD);
    h->m_holdTriggered = true;

    if (h->m_cfg.holdAction == Action::PushToTalk) {
        h->m_pttActive = true;
        SetMicMuteState(false);
        if (h->m_cfg.soundFxEnabled) PlayMicSound(false);
        OsdManager::Instance().ShowTip(L"🎙️ PTT — Active");
    } else if (h->m_cfg.holdAction == Action::CustomApp) {
        if (h->m_callback) {
            h->m_callback(Action::CustomApp);
        }
    }
}

void CALLBACK KeyHook::OnMultiPressTimer(HWND hw, UINT, UINT_PTR, DWORD) {
    auto* h = s_instance;
    if (!h) return;
    KillTimer(hw, TIMER_ID_MULTIPRESS);

    int count = h->m_tapCount;
    h->m_tapCount = 0;

    Action act = Action::None;
    switch (count) {
        case 1: act = h->m_cfg.action1; break;
        case 2: act = h->m_cfg.action2; break;
        case 3: act = h->m_cfg.action3; break;
        case 4: act = h->m_cfg.action4; break;
        default: break;
    }

    if (act != Action::None && h->m_callback)
        h->m_callback(act);
}

// ─────────────────────────────────────────────
//  Ana Klavye Kancası (LowLevelProc)
// ─────────────────────────────────────────────
LRESULT CALLBACK KeyHook::LowLevelProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode < 0)
        return CallNextHookEx(nullptr, nCode, wParam, lParam);

    auto* kb = reinterpret_cast<KBDLLHOOKSTRUCT*>(lParam);
    auto* h  = s_instance;
    if (!h) return CallNextHookEx(nullptr, nCode, wParam, lParam);

    // Kendi enjekte ettiğimiz tuşları asla tekrar yakalama, işletim sistemine bırak
    if (IsOurInjectedKey(kb))
        return CallNextHookEx(nullptr, nCode, wParam, lParam);

    bool isDown = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN);
    bool isUp   = (wParam == WM_KEYUP   || wParam == WM_SYSKEYUP);

    // ── LWin / RWin Yakalama ─────────────────────────────────────────
    if (IsWinKey(kb->vkCode)) {
        if (isDown) {
            if (h->m_copState == CopState::Copilot) {
                // Copilot basılıyken donanımın tekrarladığı Win sinyalini tamamen yut
                return 1;
            }
            if (h->m_copState == CopState::Passed) {
                // Win zaten geçirilmişti, donanım auto-repeat sinyalini yut
                return 1;
            }

            h->m_copState = CopState::Waiting;
            h->m_winSuppressed = true;
            KillTimer(h->m_msgWnd, TIMER_ID_WIN_PASS);
            SetTimer(h->m_msgWnd, TIMER_ID_WIN_PASS, 25, OnWinPassTimer);
            return 1;
        } else { // Up
            ULONGLONG now = GetTickCount64();
            // Copilot henüz bırakıldıysa trailing Win Up sinyalini tamamen yut
            if (h->m_copState == CopState::Copilot || now < h->m_copilotJustReleased) {
                h->m_winSuppressed = false;
                return 1;
            }

            if (h->m_copState == CopState::Waiting) {
                KillTimer(h->m_msgWnd, TIMER_ID_WIN_PASS);
                h->m_copState = CopState::Idle;
                if (h->m_shiftSuppressed) {
                    h->m_shiftSuppressed = false;
                    h->m_winSuppressed = false;
                    SendWinShiftTap();
                } else {
                    h->m_winSuppressed = false;
                    SendWinTap();
                }
                return 1;
            } else if (h->m_copState == CopState::Passed) {
                h->m_copState = CopState::Idle;
                h->m_winSuppressed = false;
                SendWinUp();
                return 1;
            }
            return 1;
        }
    }

    // ── LShift / RShift Yakalama ─────────────────────────────────────
    if (IsShiftKey(kb->vkCode)) {
        if (isDown) {
            if (h->m_copState == CopState::Copilot) {
                // Copilot basılıyken donanımın tekrarladığı Shift sinyalini tamamen yut
                return 1;
            }
            if (h->m_copState == CopState::Waiting) {
                // Win tuşundan hemen sonra Shift geldi -> bu Copilot tuş dizisidir, bastır!
                h->m_shiftSuppressed = true;
                return 1;
            }
            if (h->m_shiftState == ShiftState::Passed) {
                // Shift zaten geçirilmişti, auto-repeat sinyalini yut
                return 1;
            }

            // Bağımsız Shift basımı: Çok kısa (15ms) bekle (arkasından Win+F23 gelebilir mi?)
            h->m_shiftState = ShiftState::Waiting;
            KillTimer(h->m_msgWnd, TIMER_ID_SHIFT_PASS);
            SetTimer(h->m_msgWnd, TIMER_ID_SHIFT_PASS, 15, OnShiftPassTimer);
            return 1;
        } else { // Up
            ULONGLONG now = GetTickCount64();
            // Copilot basılıyken veya yeni bırakıldıysa trailing Shift Up sinyalini tamamen yut
            if (h->m_copState == CopState::Copilot || now < h->m_copilotJustReleased) {
                h->m_shiftSuppressed = false;
                return 1;
            }
            if (h->m_shiftSuppressed) {
                h->m_shiftSuppressed = false;
                return 1;
            }
            if (h->m_shiftState == ShiftState::Waiting) {
                KillTimer(h->m_msgWnd, TIMER_ID_SHIFT_PASS);
                h->m_shiftState = ShiftState::Idle;
                SendShiftTap();
                return 1;
            }
            if (h->m_shiftState == ShiftState::Passed) {
                h->m_shiftState = ShiftState::Idle;
                SendShiftUp();
                return 1;
            }
            return 1;
        }
    }

    // ── Copilot Tuşu (F23 / SC06E / Launch_App1) ──────────────────────
    if (IsCopilotKey(kb)) {
        if (isDown) {
            // Zamanlayıcıları hemen durdur ve tamponları temizle (Shift/Win tamamen yok edilir)
            KillTimer(h->m_msgWnd, TIMER_ID_WIN_PASS);
            KillTimer(h->m_msgWnd, TIMER_ID_SHIFT_PASS);
            h->m_copState = CopState::Copilot;
            h->m_shiftState = ShiftState::Idle;
            h->m_shiftSuppressed = false;
            h->m_winSuppressed = false;

            if (h->m_isKeyDown)
                return 1; // Donanım auto-repeat: yut ve çık

            h->m_isKeyDown = true;
            h->m_holdTriggered = false;

            // Tıklama sayacı zamanlayıcısını geçici olarak durdur
            KillTimer(h->m_msgWnd, TIMER_ID_MULTIPRESS);

            // Basılı tutma zamanlayıcısını başlat
            SetTimer(h->m_msgWnd, TIMER_ID_HOLD, h->m_cfg.holdMs, OnHoldTimer);
            return 1;
        } else { // Up
            h->m_copState = CopState::Idle;
            h->m_shiftState = ShiftState::Idle;
            h->m_copilotJustReleased = GetTickCount64() + 80; // 80ms trailing bastırma

            if (!h->m_isKeyDown)
                return 1;

            h->m_isKeyDown = false;
            KillTimer(h->m_msgWnd, TIMER_ID_HOLD);

            // Push-to-Talk: tuş bırakıldığında mikrofonu sustur
            if (h->m_pttActive) {
                h->m_pttActive = false;
                SetMicMuteState(true);
                if (h->m_cfg.soundFxEnabled) PlayMicSound(true);
                OsdManager::Instance().ShowTip(L"🎙️ PTT — Muted");
                return 1;
            }

            // Eğer basılı tutma eylemi zaten çalıştıysa, tıklama işlemlerini atla
            if (h->m_holdTriggered) {
                h->m_tapCount = 0;
                return 1;
            }

            // Tıklama sayısını artır ve zamanlayıcıyı başlat
            h->m_tapCount++;
            KillTimer(h->m_msgWnd, TIMER_ID_MULTIPRESS);
            SetTimer(h->m_msgWnd, TIMER_ID_MULTIPRESS, h->m_cfg.doubleTapMs, OnMultiPressTimer);
            return 1;
        }
    }

    // ── Diğer Normal Tuşlar (Harf, Rakam, Boşluk vb.) ────────────────
    // Kullanıcı bir harfe bastıysa ve bekleyen bir Win/Shift varsa,
    // tuş sıralamasının bozulmaması için bekleyen modifier'ı HEMEN geçir.
    if (isDown) {
        if (h->m_copState == CopState::Waiting) {
            KillTimer(h->m_msgWnd, TIMER_ID_WIN_PASS);
            h->PassModifiers();
        }
        if (h->m_shiftState == ShiftState::Waiting) {
            KillTimer(h->m_msgWnd, TIMER_ID_SHIFT_PASS);
            h->PassShiftOnly();
        }
    }

    return CallNextHookEx(nullptr, nCode, wParam, lParam);
}
