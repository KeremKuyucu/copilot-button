# Active Context: Copilot Button

## 1. Current Status & State
- **Current Version**: v3.2.1
- **Active Focus**: Establishing persistent knowledge base (`knowledge/`) and memory bank (`memory-bank/`) synchronization across the entire project history, and adapting `AI_GUIDELINES.md` specifically to C++20 / Win32 / MSVC / GCC standards.
- **System Stability**: Production-ready. All core subsystems (KeyHook, Audio, MediaTracker, OsdManager, TrayManager, ConfigManager, AppRegister) are operating natively in C++20.

---

## 2. Recent Technical Advancements

### 2.1 Release v3.2.1 (UIPI Message Blocking Fix & Modernized Tray)
- **Problem**: In elevated mode (`requireAdministrator`), Windows UIPI blocked tray click notifications (`WM_USER_TRAY_ICON`) and taskbar restart notifications (`TaskbarCreated`) sent from `explorer.exe`.
- **Fix**: Implemented `ChangeWindowMessageFilter` and `ChangeWindowMessageFilterEx` in `src/main.cpp` and `src/Tray.cpp` for `WM_CLOSE`, `WM_USER_TRAY_ICON`, `WM_COMMAND`, and taskbar restart messages.

### 2.2 Release v3.2.0 (RunAgy Terminal Actions & UTF-8 BOM Stripping)
- **RunAgy Action**: Integrated developer workflow action capable of launching Windows Terminal (`wt`) or Command Prompt (`cmd.exe`) in target directories with optional `F5` key injection (`AgySendF5`).
- **UTF-8 BOM Stripping**: Added in-place BOM stripping in `Config.cpp` (`StripUtf8Bom`) to prevent Win32 `GetPrivateProfileStringW` from failing when users edit `config.ini` in modern text editors.

### 2.3 Release v3.1.1 (Event-Driven Taskbar Tracking)
- Replaced the 300 ms polling timer with Shell AppBar notifications (`SHAppBarMessage` `ABM_NEW`) and WinEvent hooks on the Explorer taskbar thread, completely eliminating idle CPU wakeups.

### 2.4 Release v3.1.0 (Persistent Interactive Media Card)
- Added an interactive media card displaying track metadata, album artwork decoded from WinRT byte streams, and transport buttons with mouse hit-testing.

---

## 3. Active Architectural Rules & Invariants
- **Zero Polling**: All subsystems must remain event-driven. Never introduce periodic polling timers on hot paths.
- **Strict Thread Safety**: Worker threads must never touch UI handles directly; all cross-thread notifications must dispatch through the hidden host window via custom window messages.
- **Elevated Privilege Awareness**: Because the binary requires elevation, always maintain UIPI message filtering and use Task Scheduler for autostart.
- **Synchronous Knowledge Sync**: Maintain zero-postponement documentation updates in `knowledge/history/` and `memory-bank/` on every turn.

---

## 4. Next Steps & Upcoming Work
- Continue monitoring user requests and ensure that any new feature or bug fix is synchronously recorded in `knowledge/history/engine_features.md` or `knowledge/history/bug_fixes.md`.
- Ensure all public C++ symbols maintain clear technical documentation comments.
- Maintain single-binary lightweight footprint (<500 KB binary, <10 MB RAM).

