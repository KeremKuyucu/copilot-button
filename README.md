# Copilot Button

A small Windows utility I built for myself to remap my laptop's Copilot key (`LWin + LShift + F23` / `VK_LAUNCH_APP1`) without leaking `Win` or `Shift` to the Start Menu.

> **Note:** This project was written for my own setup and daily workflow, so its features, defaults, and behavior are tailored to my preferences. If you want to use it or change how it works, feel free to fork the repository and adjust it to your needs.

## What It Does

- Intercepts the Copilot key via a low-level keyboard hook (`WH_KEYBOARD_LL`) without breaking normal `Win+*` or `Shift+*` shortcuts.
- Maps 1–4 taps and press-and-hold to actions (`MicMute`, `PushToTalk`, `PlayPause`, `NextTrack`, `PrevTrack`, `MasterMute`, `ToggleDeafen`, `LockScreen`, `CustomApp`, `None`).
- Shows a simple OSD for actions/media track changes and a microphone status overlay.
- All settings are compiled directly from `include/Config.hpp` (no external config file).

## Usage

Run `CopilotButton.exe`. By default, it moves itself to `%LOCALAPPDATA%\CopilotButton\`, registers with Windows (including startup), and runs in the system tray.

- **Portable mode:** Run with `--portable` or place an empty `portable.flag` file next to the executable to run from the current folder without registry/startup entries.
- **Uninstall:** Remove from **Windows Settings > Installed apps** or run `CopilotButton.exe --uninstall --silent`.

## Configuration

There is no external `config.ini`. Edit the values in `include/Config.hpp` (actions, `customAppPath`, `windowsHelloLight`, timings, sound, and OSD options) and rebuild.

## Building

Requires Windows 10/11 (64-bit) and either MinGW-w64 (GCC 11+, C++20) or MSVC / CMake 3.20+.

**MinGW:**
```cmd
scripts\build.bat
```

**CMake:**
```cmd
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

## License

[GPL-3.0](LICENSE)
