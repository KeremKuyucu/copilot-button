# Technical Context: Tools, Dependencies & Constraints

## 1. Programming Languages & Toolchain

- **Language Standard**: C++20 (`/std:c++20` under MSVC, `-std=c++20` under GCC/Clang).
- **Build System**: CMake (minimum version 3.20).
- **Supported Compilers**:
  - Microsoft Visual Studio C++ Compiler (MSVC 2019 / 2022 / v142 / v143).
  - MinGW-w64 GCC (with static runtime linking `-static-libgcc -static-libstdc++ -static`).
- **Resource Compiler**: Windows Resource Compiler (`rc.exe` / `windres`).

---

## 2. Platform & System Dependencies

The application relies strictly on standard Windows APIs and includes no external package dependencies:

| Subsystem / API | Header / Library | Purpose |
| :--- | :--- | :--- |
| **Win32 User & Shell** | `<windows.h>`, `user32.lib`, `shell32.lib` | Window creation, message loop, low-level hook (`WH_KEYBOARD_LL`), tray icon, AppBar notifications. |
| **Windows Core Audio** | `<mmdeviceapi.h>`, `<endpointvolume.h>`, `ole32.lib` | Audio endpoint enumeration, mute control, volume change callbacks. |
| **Windows Runtime (WinRT)** | `<winrt/Windows.Media.Control.h>`, `windowsapp.lib` | Universal media session management (`GSMTC`), track metadata extraction, thumbnail streaming. |
| **Desktop Window Manager** | `<dwmapi.h>`, `dwmapi.lib` | Native rounded corners (`DwmSetWindowAttribute`). |
| **GDI+ Graphics** | `<gdiplus.h>`, `gdiplus.lib` | Double-buffered antialiased rendering, sub-pixel text rendering, alpha compositing. |
| **Process & Toolhelp** | `<tlhelp32.h>`, `advapi32.lib` | Stale process detection, single instance mutex, registry operations. |

---

## 3. Binary & Resource Constraints

- **Binary Size**: Target $\le 500 \text{ KB}$ (current v3.2.1 binary is approximately 440 KB).
- **Memory Footprint**: Target $\le 15 \text{ MB}$ working set RAM (typical runtime is 8–10 MB).
- **CPU Utilization**: 0.0% idle CPU usage. Steady state is 100% interrupt/event-driven with zero active polling timers.
- **Elevation Requirement**: Requires Administrator privileges (`app.manifest` specifies `level="requireAdministrator"`).
  - Must configure UIPI message filters via `ChangeWindowMessageFilterEx` to permit tray notifications from Medium integrity Explorer.
  - Must use Task Scheduler for autostart to bypass UAC prompts and prevent Windows from dropping the process.

