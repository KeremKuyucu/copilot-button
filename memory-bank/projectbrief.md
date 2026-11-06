# Project Brief: Copilot Button

## 1. Project Identification
- **Project Name**: Copilot Button (`CopilotButton.exe`)
- **Repository**: `KeremKuyucu/copilot-button`
- **Current Version**: v3.2.1
- **Primary Language & Standard**: C++20 (MSVC / GCC MinGW)
- **Target Platform**: Windows 10 (Build 19041+) and Windows 11
- **License**: GNU General Public License v3.0 (GPL-3.0)

---

## 2. Core Purpose & Mission
Modern laptops and OEM keyboards manufactured for Windows 11 include a dedicated Microsoft Copilot hardware key. Mechanically, this key generates a composite scan code sequence (`Left Windows + Left Shift + F23` or scan code `0x006E`). Standard key remappers leak the initial modifier keys, causing unwanted Start Menu popups or introducing perceptible typing lag.

`Copilot Button` is an ultra-lightweight, zero-leak native Windows background utility that intercepts this key sequence at the low-level hook layer, completely prevents Start Menu or modifier leakage, and unlocks programmable multifunction gestures (1 to 4 clicks, press-and-hold, Push-to-Talk, universal media control, audio mute, and terminal automation) paired with a modern Windows 11 On-Screen Display.

---

## 3. High-Level Requirements

1. **Zero-Leak Interception**:
   - Complete suppression of unwanted `Left Windows` and `Left Shift` signals during Copilot key actuation.
   - Fast-path passthrough ensuring standard Windows shortcuts (`Win+E`, `Win+R`, `Shift+A`) and gaming inputs experience zero perceptible latency.

2. **Multi-Gesture Engine**:
   - Support for 1-click, 2-clicks, 3-clicks, and 4-clicks within a configurable time window (`DoubleTapMs`).
   - Dedicated press-and-hold action detection (`HoldMs`).

3. **Audio & Media Control**:
   - Push-to-Talk (unmute while held, mute upon release).
   - Instant mute toggles for microphone, master audio, and simultaneous Discord-style deafen.
   - Universal Windows media integration (GSMTC) tracking playback across all modern players.

4. **Visual Feedback (OSD)**:
   - Modern Windows 11 fluent layered floating badges with DWM rounded corners and smooth alpha animations.
   - Interactive media card with decoded album artwork thumbnail and transport buttons.
   - Dynamic taskbar and fullscreen application awareness.

5. **Extreme Efficiency & Zero Overhead**:
   - Single standalone binary (~440 KB).
   - Low memory footprint (<10 MB RAM).
   - Zero external runtime dependencies (no Electron, no Python, no .NET, no WebView2).
   - Event-driven architecture preserving CPU C-states (zero polling loops in steady state).

6. **Seamless Lifecycle & Windows Integration**:
   - Self-relocation to `%LOCALAPPDATA%\CopilotButton`.
   - Elevated Task Scheduler autostart (`/rl highest`) bypassing UAC prompts.
   - Official Windows Settings (Installed apps) uninstaller registration.
   - Live dynamic hot-reloading for `config.ini` via directory change monitoring.

