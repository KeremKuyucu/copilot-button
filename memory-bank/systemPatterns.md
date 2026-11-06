# System Patterns & Architecture Design

## 1. Architectural Philosophy

`Copilot Button` adheres to a strict single-binary native architecture optimized for low resource utilization, thread safety, and event-driven responsiveness.

---

## 2. Key Design Patterns & Technical Decisions

### 2.1 3-State Anti-Leak State Machine
- **Pattern**: Finite State Machine (FSM) with time-bounded transitions.
- **Application**: Resolves the ambiguity of `VK_LWIN` and `VK_LSHIFT` key events.
- **Rules**:
  - `VK_LWIN` transitions from `Idle` to `Waiting` (25 ms timer).
  - If `VK_LSHIFT` arrives, transitions to secondary `Waiting` (15 ms timer).
  - If `VK_F23` or `SC06E` arrives, transitions to `Copilot` state and completely suppresses the modifier signals.
  - If an unrelated key arrives or the timer expires, immediately transitions to `Passed` and dispatches the buffered modifiers to the OS via fast-path `SendInput`.

### 2.2 Event-Driven Architecture (Zero Polling)
- **Decision**: Avoid periodic polling loops (such as 300 ms timers) that keep CPU cores awake and prevent deep sleep states (C-states).
- **Application**:
  - **Taskbar & Display Changes**: Registered via Shell AppBar messages (`SHAppBarMessage` `ABM_NEW`), WinEvent hooks for Explorer thread position changes (`EVENT_OBJECT_LOCATIONCHANGE`), and `EVENT_SYSTEM_MOVESIZEEND`.
  - **Audio Hardware Changes**: Registered via COM `IAudioEndpointVolumeCallback`.
  - **Media Changes**: Registered via WinRT GSMTC session event tokens (`CurrentSessionChanged`, `MediaPropertiesChanged`, `PlaybackInfoChanged`).
  - **Configuration File Edits**: Registered via Win32 directory change notifications (`ReadDirectoryChangesW`).

### 2.3 Window Message Marshaling for Thread Safety
- **Pattern**: Actor-style message passing via hidden Win32 host window (`CopilotButtonHost`).
- **Application**: Background worker threads (WinRT callbacks, Core Audio callbacks, directory file watchers) never manipulate UI window handles or GDI+ contexts directly. Instead, they marshal state transitions to the main UI thread via `PostMessageW` (`WM_USER_MIC_STATE_CHANGED`, `WM_USER_TRACK_CHANGED`, `WM_USER_CONFIG_CHANGED`).

### 2.4 Double-Buffered Layered Window Rendering
- **Pattern**: Software offscreen double-buffering submitted via `UpdateLayeredWindow`.
- **Application**:
  - Eliminates tearing and flicker on top-level transparent windows.
  - Offscreen memory DC with a 32-bit ARGB DIB section is rendered using antialiased GDI+ drawing routines.
  - DWM rounded corner preferences (`DWMWA_WINDOW_CORNER_PREFERENCE`) are applied for Windows 11 integration.

### 2.5 Single-Instance with Stale Instance Reaping
- **Pattern**: Mutex-guarded lifecycle with Toolhelp32 process snapshot inspection.
- **Application**: Before acquiring `Global\CopilotButton_SingleInstance_Mutex`, enumerates existing processes with the same executable name and terminates any stale instances (`TerminateProcess`) to guarantee clean hook installation.

### 2.6 Elevated Autostart via Task Scheduler
- **Pattern**: Task Scheduler registration (`/rl highest`) instead of registry `Run` keys.
- **Application**: Because the application requires administrator privileges to intercept keystrokes over elevated game and utility windows, standard registry `Run` keys are swallowed by Windows Explorer on startup. Task Scheduler executes the process at logon with full administrative privileges without displaying UAC prompts.

