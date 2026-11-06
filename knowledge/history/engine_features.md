# Historical Engine Features Log

This document tracks all new features and functional enhancements across the project history. In accordance with Rule 3.1, features are documented in categorized tables and bug fixes are excluded.

---

## 1. Input & Low-Level Keyhook System

| Feature | Release | Commit | Description |
| :--- | :--- | :--- | :--- |
| **Initial Interception Logic** | v1.0.0 | `8c90b26`, `298061c` | Low-level keyboard hook intercepting OEM Copilot composite scan codes. |
| **3-State Anti-Leak State Machine** | v1.0.7 | `78b1eee` | 3-state state machine buffering `LWin` (25 ms) and `LShift` (15 ms) to confirm `F23`/`SC06E` before suppressing modifiers. Prevents Start Menu flash. |
| **Trailing Release Suppression** | v1.0.7 | `78b1eee` | 80 ms trailing release suppression preventing ghost key events after Copilot key release. |
| **Multi-Click Gesture Recognition** | v1.1.0 | `9b9bfe9` | Multi-press detection engine supporting 1, 2, 3, and 4 sequential taps within configurable `DoubleTapMs` (default 250 ms). |
| **Press-and-Hold Detection** | v1.1.0 | `9b9bfe9` | Continuous key-down timer triggering dedicated hold action after `HoldMs` (default 250 ms). |
| **Native C++20 Hook Engine** | v2.0.0 | `bf59e87` | Complete reimplementation of hook engine in native C++20 using Win32 `WH_KEYBOARD_LL`. |
| **Modifier Fast-Path Pass-Through** | v2.0.0 | `bf59e87` | Immediate pass-through of buffered modifier keys when an unrelated regular key (e.g., `Win+R`, `Shift+A`) arrives before `F23`. |

---

## 2. Audio & Endpoint Volume Management

| Feature | Release | Commit | Description |
| :--- | :--- | :--- | :--- |
| **Microphone Mute Toggle** | v1.0.0 | `8c90b26` | Toggle default recording endpoint mute state via system audio endpoints. |
| **Push-to-Talk (PTT)** | v1.0.0 | `8c90b26` | Unmutes default microphone on key-down and automatically mutes upon key release. |
| **Master Audio Mute** | v1.0.4 | `4de702a` | Toggle default playback device master audio mute state. |
| **Discord-Style Deafen** | v1.0.4 | `4de702a` | Simultaneous mute/unmute toggle affecting both microphone input and master output endpoints. |
| **Core Audio COM Integration** | v2.0.0 | `bf59e87` | Native integration with Windows Core Audio API (`IMMDeviceEnumerator`, `IAudioEndpointVolume`). |
| **Bi-directional Volume Callback Sync** | v2.0.0 | `bf59e87` | Implementation of `IAudioEndpointVolumeCallback` to reflect external hardware button or OS sound setting changes in real time. |
| **Persistent Microphone Overlay** | v2.0.0 | `bf59e87` | Layered transparent floating badge on screen showing live microphone mute state. |

---

## 3. On-Screen Display (OSD) & Visual Overlays

| Feature | Release | Commit | Description |
| :--- | :--- | :--- | :--- |
| **Basic Text OSD** | v1.1.0 | `9b9bfe9` | On-screen notification displaying active action or mute state changes. |
| **Fluent Rounded Visuals** | v1.1.9 | `c2461bb` | Modernized OSD layout matching Windows fluent design aesthetics. |
| **Single-Line Capsule Media OSD** | v2.0.0 | `1ad83db`, `eefc973` | Compact 36px capsule badge displaying current media track info without obscuring work area. |
| **Layered Window Hardware Rendering** | v3.0.0 | `e07c58f` | Native GDI+ layered window (`WS_EX_LAYERED`) rendering with sub-pixel antialiasing and alpha blending. |
| **DWM Window Corner Rounding** | v3.0.0 | `e07c58f` | Native Desktop Window Manager rounded corner preference (`DWMWA_WINDOW_CORNER_PREFERENCE`). |
| **Interactive Media Card with Album Art** | v3.1.0 | `5e7e10c` | Expanded media card displaying song title, artist, decoded thumbnail bitmap, and clickable transport buttons (Prev, Play/Pause, Next). |
| **Fullscreen Application Suppression** | v3.1.0 | `5e7e10c` | Automatic detection (`IsFullscreenAppActive`) suppressing OSD display when fullscreen games or video players are active. |
| **Event-Driven Taskbar Tracking** | v3.1.1 | `ca1bc22` | Shell AppBar (`SHAppBarMessage` `ABM_NEW`) and WinEvent hooks to position OSD relative to taskbar position and autohide state without polling. |

---

## 4. Universal Media Transport Integration

| Feature | Release | Commit | Description |
| :--- | :--- | :--- | :--- |
| **Virtual Key Media Control** | v1.0.0 | `8c90b26` | Emulated `VK_MEDIA_PLAY_PAUSE`, `VK_MEDIA_NEXT_TRACK`, and `VK_MEDIA_PREV_TRACK` signals. |
| **Windows WinRT Media Integration** | v2.1.0 | `d6426fd` | Direct connection to `GlobalSystemMediaTransportControlsSessionManager` via Windows Runtime (WinRT). |
| **Universal Player Support** | v2.1.0 | `d6426fd` | Transport tracking across all WinRT-compliant media sessions (Spotify, YouTube/Chrome, Edge, Apple Music, VLC, Firefox, Tidal, Deezer). |
| **Thumbnail Stream Decoding** | v3.1.0 | `5e7e10c` | Asynchronous extraction of album art byte streams (`IRandomAccessStreamWithContentType`) converted to memory buffers for GDI+ bitmap creation. |

---

## 5. Application Lifecycle, Shell Integration & Persistence

| Feature | Release | Commit | Description |
| :--- | :--- | :--- | :--- |
| **Single-Instance Mutex** | v1.0.0 | `8c90b26` | Global named mutex (`Global\CopilotButton_SingleInstance_Mutex`) preventing duplicate instances. |
| **Stale Process Cleanup** | v3.0.0 | `e07c58f` | Automatic enumeration and termination of stale or orphaned instances via Toolhelp32 snapshot before acquiring mutex. |
| **Self-Relocation Engine** | v2.0.0 | `a2df551` | Self-relocation to `%LOCALAPPDATA%\CopilotButton\CopilotButton.exe` on first launch with background source file cleanup. |
| **Windows Settings Registration** | v3.0.2 | `7075a30` | Registration in `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall` (Installed apps) with full uninstaller metadata. |
| **Elevated Task Scheduler Autostart** | v3.0.2 | `7075a30` | Task Scheduler integration (`schtasks /create /rl highest`) replacing registry Run keys to avoid silent UAC drops for elevated binaries. |
| **Shell App Paths & Start Menu** | v1.2.2 | `e5c3eb4`, `6da2daf` | Registration under `App Paths` enabling direct execution via `Win+R -> CopilotButton` and official Start Menu shortcuts. |
| **Built-in Uninstaller Routine** | v3.0.2 | `7075a30` | Command line uninstaller (`--uninstall`) removing registry entries, scheduled tasks, shortcuts, and application data. |
| **UIPI Message Filter Configuration** | v3.2.1 | `d887a73` | Elevated message filtering via `ChangeWindowMessageFilterEx` allowing tray messages from lower-integrity `explorer.exe`. |

---

## 6. Configuration, Actions & Automation

| Feature | Release | Commit | Description |
| :--- | :--- | :--- | :--- |
| **File-Based INI Configuration** | v1.0.0 | `8c90b26`, `b1fddc3` | Configuration stored in structured `config.ini` file with automatic fallback defaults generation. |
| **Background Hot-Reload Engine** | v2.0.0 | `bf59e87` | Background thread using `ReadDirectoryChangesW` monitoring `config.ini` changes and updating engine parameters without restarting. |
| **Custom Application / URL Launcher** | v1.2.0 | `a48f2c6`, `518e23c` | Action allowing execution of arbitrary `.exe` paths or opening default browser URLs. |
| **Workstation Screen Lock** | v1.0.0 | `8c90b26` | Direct workstation lock trigger (`LockWorkStation`). |
| **RunAgy Terminal Launcher** | v3.2.0 | `334a845`, `87e3b0a` | Action launching terminal commands in Windows Terminal (`wt`) or Command Prompt (`cmd.exe`) at configured working directories. |
| **Optional F5 Key Injection for RunAgy** | v3.2.0 | `90e909a` | Configurable automatic `F5` key press injection after terminal launch (`AgySendF5=1`). |
| **In-Place UTF-8 BOM Stripping** | v3.2.0 | `468308e` | Detection and removal of UTF-8 Byte Order Marks to guarantee Win32 INI parsing reliability. |

---

## 7. Major Architectural Milestones

| Era | Releases | Architectural Characteristics |
| :--- | :--- | :--- |
| **v1.x (AutoHotkey Era)** | v1.0.0 – v1.4.0 | Prototyped in AutoHotkey. Introduced the 3-state anti-leak concept, multi-click recognition, and basic audio controls. Modularized across `.ahk` library files. |
| **v2.x (Dual-Process & WebView2)** | v2.0.0 – v2.1.0 | Migrated core engine to native C++20. Settings interface powered by embedded WebView2 GUI. Added WinRT media tracking and Core Audio callbacks. |
| **v3.x (Single-Binary Native C++20)** | v3.0.0 – v3.2.1 | Complete native rewrite eliminating WebView2. Pure C++20 standalone executable (~440 KB, <10 MB RAM). Direct Win32 tray, GDI+ layered OSD, taskbar tracking, and Windows Settings uninstaller. |

