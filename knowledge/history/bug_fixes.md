# Historical Bug Fixes Log

This document records all historical bug fixes across the lifetime of the project, categorized chronologically by release version and date. In accordance with Rule 3.1, bug fixes are tracked separately from feature tables.

---

## Release v3.2.1 (2026-11-04)

### Fix UIPI Message Blocking for Elevated Tray Icon
- **Commit**: `d887a73`
- **Subsystem**: System Tray (`Tray.cpp`, `main.cpp`)
- **Root Cause**: When the application runs elevated (`requireAdministrator` via `app.manifest`), Windows User Interface Privilege Isolation (UIPI) blocks lower-integrity processes (such as `explorer.exe`) from sending window messages to higher-integrity windows. As a result, tray icon clicks (`WM_USER_TRAY_ICON`), context menu commands (`WM_COMMAND`), and taskbar recreation broadcasts (`TaskbarCreated`) were blocked.
- **Resolution**: Invoked `ChangeWindowMessageFilter` and `ChangeWindowMessageFilterEx` on the hidden host window (`CopilotButtonHost`) for `WM_CLOSE`, `WM_USER_TRAY_ICON`, `WM_COMMAND`, and `RegisterWindowMessageW(L"TaskbarCreated")` with `MSGFLT_ALLOW`.

---

## Release v3.2.0 (2026-11-01)

### Fix Win32 INI Parser Failure Caused by UTF-8 BOM
- **Commit**: `468308e`
- **Subsystem**: Configuration (`Config.cpp`)
- **Root Cause**: When `config.ini` was saved or edited with a UTF-8 Byte Order Mark (BOM: `0xEF, 0xBB, 0xBF`), the Win32 `GetPrivateProfileStringW` API failed to parse the initial section header (`[Settings]`), treating the file as corrupted or empty and silently reverting all settings to built-in defaults.
- **Resolution**: Added `StripUtf8Bom` helper in `Config.cpp`. When opening the configuration file, the function detects the 3-byte UTF-8 BOM sequence and rewrites the file in-place without the BOM before passing it to Win32 INI parsing routines.

### Fix Windows Terminal Invocation Reliability
- **Commit**: `96944ee`
- **Subsystem**: Actions (`Actions.cpp`)
- **Root Cause**: Direct execution of `wt.exe` via `ShellExecuteW` failed on systems where Windows Terminal app execution aliases were disabled or restricted.
- **Resolution**: Replaced direct `wt.exe` execution with an explicit PowerShell / Command Prompt launcher invocation, ensuring reliable console startup with proper fallback.

### Compiler Warning Clean-Up in Audio and KeyHook Modules
- **Commit**: `5ffdd37`
- **Subsystem**: Audio & Input (`Audio.cpp`, `KeyHook.cpp`)
- **Root Cause**: Minor type conversion mismatches and unused parameter warnings during `/W4` MSVC compilation.
- **Resolution**: Cleaned up casting and parameter handling to achieve zero warnings.

---

## Release v3.0.0 – v3.1.1 (2026-10-26 – 2026-10-30)

### Event-Driven Taskbar Tracking (Eliminating 300ms Polling Loop)
- **Commit**: `ca1bc22`
- **Subsystem**: On-Screen Display (`Osd.cpp`, `main.cpp`)
- **Root Cause**: The media OSD relied on a 300 ms timer (`TIMER_ID_MEDIA_MONITOR`) to poll taskbar positioning and fullscreen state. This periodic timer caused continuous CPU wakeups, hindering low-power sleep states (C-states).
- **Resolution**: Eliminated the polling loop. Implemented shell AppBar event notifications (`SHAppBarMessage` with `ABM_NEW`), WinEvent hooks for Explorer taskbar position changes (`EVENT_OBJECT_LOCATIONCHANGE`), and `EVENT_SYSTEM_MOVESIZEEND` hooks to recalculate OSD positions purely on events.

### Start Menu Shortcut COM Initialization Failure
- **Commit**: `82d57e9`
- **Subsystem**: App Registration (`AppRegister.cpp`)
- **Root Cause**: Attempting to instantiate `IShellLinkW` and `IPersistFile` to create the Start Menu shortcut failed when COM had not yet been initialized on the calling thread.
- **Resolution**: Wrapped shortcut creation logic with explicit `CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)` and matching `CoUninitialize()`.

### Dangling WebView2 Process Teardown on Application Exit
- **Commit**: `abd9395`
- **Subsystem**: Engine / GUI Lifecycle
- **Root Cause**: Closing the main application window left orphaned WebView2 runtime processes in memory due to missing controller close calls.
- **Resolution**: Added explicit controller teardown and process cleanup handlers before window destruction. (Subsequently superseded by the v3.0 single-binary native rewrite which completely eliminated WebView2).

---

## Release v1.3.1 – v1.3.4 (2026-10-04 – 2026-10-09)

### Telemetry Network Failure and Offline Retry
- **Commit**: `cc464d7`
- **Subsystem**: Telemetry & Updater
- **Root Cause**: Network timeouts on unstable connections caused updater checks and telemetry reporting to throw unhandled exceptions.
- **Resolution**: Implemented offline retry mechanism with exponential backoff and silent failure recovery.

### Release Notes Generator Tag Detection Logic
- **Commit**: `8006d51`
- **Subsystem**: Build Scripts (`generate-release-notes.ps1`)
- **Root Cause**: Lexicographical tag sorting returned incorrect previous git tags for versions with differing numeric lengths.
- **Resolution**: Refactored git tag query to sort by version semantics (`v*.*.*`) rather than plain string ordering.

### Ahk2Exe CI Compilation Deadlock
- **Commit**: `f6b716b`, `7cca06a`, `910d1a3`
- **Subsystem**: CI / CD Workflow (`.github/workflows/`)
- **Root Cause**: Ahk2Exe standard output buffering caused the compilation process to freeze indefinitely in headless GitHub Actions runners.
- **Resolution**: Configured file-redirected `Start-Process` with an explicit timeout watchdog, synchronous process join, and fallback executable search paths.

### Updater Script Syntax Error
- **Commit**: `e7f4209`
- **Subsystem**: Auto-Updater (`Updater.ahk`)
- **Root Cause**: Malformed expression in `Updater.ahk` caused syntax parser failures during compilation.
- **Resolution**: Fixed conditional expression and verified clean compilation across environments.

### Updater COM Timeout on High Latency Connections
- **Commit**: `ac56e97`
- **Subsystem**: Auto-Updater
- **Root Cause**: Default WinHTTP timeout was too short for slow connections during update payload checks.
- **Resolution**: Increased HTTP timeout threshold and added status code validation.

---

## Release v1.0.1 – v1.3.0 (2026-08-13 – 2026-10-03)

### CI Build Artifact Race Condition
- **Commit**: `bb2f7fb`, `1c99640`
- **Subsystem**: CI / CD Build Automation
- **Root Cause**: Downstream packaging steps executed before Ahk2Exe had flushed the compiled binary to disk.
- **Resolution**: Added synchronous file completion verification loops before packaging artifacts.

### Installer Silent Launch Suppression
- **Commit**: `799238c`
- **Subsystem**: Installer (`installer.iss`)
- **Root Cause**: The `skipifsilent` flag in Inno Setup prevented the application executable from launching upon silent setup completion.
- **Resolution**: Removed the flag to guarantee proper launch after installation.

### Button Remap Trigger Logic and Stability
- **Commit**: `e1cf74c`, `6403152`, `d2a06bc`
- **Subsystem**: Key Interception Logic
- **Root Cause**: Edge cases in scan code filtering caused spurious double-firing or dropped events during rapid typing.
- **Resolution**: Optimized hook evaluation order and tightened state machine transitions.

### Tray Icon Initialization Error Handling
- **Commit**: `2b5ee5c`
- **Subsystem**: Tray & UI
- **Root Cause**: Missing icon file or invalid resource handle caused initialization failure without user-facing error reporting.
- **Resolution**: Added resource validation and fallback default icon creation.

### PowerShell Authenticode Quoting Error
- **Commit**: `67f9359`
- **Subsystem**: Code Signing Scripts
- **Root Cause**: Unescaped quotation marks in PowerShell Authenticode signature verification commands broke execution paths containing spaces.
- **Resolution**: Sanitized argument strings with explicit quotation escaping.

### Modifier Key Sticking on Rapid Releases
- **Commit**: `5c69ad3`
- **Subsystem**: Input Simulation
- **Root Cause**: Standard `SendInput` calls without modifier synchronization caused `Shift` or `Win` keys to become stuck down in the OS keyboard state table.
- **Resolution**: Adopted `SendInput` with `Blind` mode semantics, preserving external modifier states.

### Build Script Parameter Collision
- **Commit**: `0a7a222`
- **Subsystem**: Build Scripts
- **Root Cause**: Variable naming conflict in switch parameter evaluation within the build script.
- **Resolution**: Renamed switch parameters to enforce strict scoping.

