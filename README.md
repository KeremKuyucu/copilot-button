# 🚀 Copilot Button (Native C++20 Win32)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Language: C++20](https://img.shields.io/badge/Language-C%2B%2B20-00599C.svg)](https://isocpp.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20(x64)-blue)](https://microsoft.com)
[![Architecture](https://img.shields.io/badge/Architecture-Single%20Binary%20%2F%20Standalone-success)](#)
[![Size](https://img.shields.io/badge/Binary%20Size-~440%20KB-brightgreen.svg)](#)
[![RAM Usage](https://img.shields.io/badge/RAM-~2%20MB-brightgreen.svg)](#)

A high-performance, single-binary Windows utility that transforms the physical **Copilot key (`Win + Shift + F23`)** into a latency-free, zero-bloat controller for **microphone muting, media playback, Spotify tracking, and custom shortcuts**.

---

## ✨ Features

- ⚡ **Ultra-Lightweight Single Binary (`CopilotButton.exe`)**:
  - The entire keyboard hook (`WH_KEYBOARD_LL`), Core Audio control, desktop overlay, Spotify tracker, system tray, and auto-start logic are bundled into a single **~440 KB** executable.
  - Zero external runtimes, zero WebView2/Edge helper processes, and zero background daemons. Consumes only **~2 MB RAM**.
- ⚙️ **Instant Live Hot-Reloading**:
  - Selecting **⚙️ Settings** from the tray menu opens `config.ini` directly in your default text editor.
  - A background file watcher (`WatcherThread`) detects file saves in real time and applies changes immediately with **zero restart required**.
- 🛡️ **Anti-Modifier Leak Engine**:
  - Automatically intercepts and swallows the hardware modifier keys (`Left Shift` and `Left Windows`) emitted by the physical Copilot key.
  - Prevents sticky Shift in games (sprinting/crouching) and stops the Windows Start menu from accidentally popping up.
- 🎙️ **Windows Core Audio Integration**:
  - Sub-millisecond microphone mute toggling directly via `IAudioEndpointVolume`.
  - Listens to external hardware/app mute events via `IAudioEndpointVolumeCallback` to keep the desktop badge and OSD in perfect sync.
- 🔴 **Persistent Desktop Mute Badge**:
  - Displays a clean, click-through, non-intrusive `MICROPHONE MUTED` badge on your screen whenever your mic is muted.
- 💬 **Smooth On-Screen Display (OSD)**:
  - Instant visual feedback for volume, mute status, media controls, and Spotify track changes.
  - Configurable position (TopLeft, TopRight, BottomLeft, BottomRight, Center), font size, accent color, and fade animations.
- 🎵 **Windows Media Controls (GSMTC) & Spotify**:
  - Native media key dispatch for play/pause and track navigation.
  - Subscribes to Windows Media Transport Controls events to display track title and artist on song changes with zero CPU polling.
- 🗣️ **Flexible Tap & Hold Actions**:
  - Distinguishes 1, 2, 3, 4 clicks and long press.
  - Built-in **Push-to-Talk** (unmutes while held, mutes on release) or **Custom App/URL** launcher.
- 🚀 **Smart AutoStart & Windows Integration**:
  - Automatically indexes into the Start Menu and registers with `App Paths` (run directly via `Win + R` -> `CopilotButton`).
  - Supports automatic startup via Windows Registry (`Run`) and Task Scheduler (`schtasks /rl highest`) for silent, UAC-prompt-free launch at boot.

---

## 🎯 Action Mapping

| Action | Default Trigger | Description |
|---|---|---|
| `MicMute` | **1 Click** | Toggle system microphone mute |
| `PlayPause` | **2 Clicks** | Media play / pause |
| `NextTrack` | **3 Clicks** | Skip to next track |
| `PrevTrack` | — | Return to previous track |
| `MasterMute` | — | Toggle master system volume mute |
| `ToggleDeafen` | — | Mute both system audio and microphone simultaneously |
| `LockScreen` | — | Lock workstation immediately |
| `PushToTalk` | **Hold** | Push-to-Talk (unmute while held, mute on release) |
| `CustomApp` | — | Launch custom application path or URL |
| `None` | **4 Clicks** | No action assigned |

*All actions can be customized for 1, 2, 3, 4 clicks and long press inside `config.ini`.*

---

## 🚀 Quick Start

1. Download the latest **`CopilotButton.exe`** from [Releases](https://github.com/KeremKuyucu/copilot-button/releases).
2. Run `CopilotButton.exe`.
3. The app sits quietly in your system tray (bottom-right).
4. To configure settings, right-click the tray icon and select **⚙️ Settings** (opens `config.ini`).

---

## 🛠️ Building from Source

### Prerequisites
- Windows 10 / 11 (x64)
- MinGW-w64 (GCC with C++20 support) or MSVC

### Build using MinGW (Recommended)
```cmd
git clone https://github.com/KeremKuyucu/copilot-button.git
cd copilot-button
scripts\build.bat
```

### Build using CMake
```cmd
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

The resulting standalone executable will be located in the root directory: **`CopilotButton.exe`**.

---

## 📄 Configuration (`config.ini`)

`config.ini` is automatically generated in the application folder on first run, complete with default settings and explanatory comments. 

Any changes made in `config.ini` are applied **live on file save** (hot-reload) without restarting the application.

---

## 📜 License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](LICENSE) file for details.
