@echo off
setlocal

set OUT=..\CopilotButton.exe

echo [*] Compiling resource file (windres)...
windres app.rc -O coff -o build_app.res
if errorlevel 1 (
    echo [!] windres failed!
    exit /b 1
)

echo [*] Compiling C++ sources...
g++ -std=c++20 ^
    -DUNICODE -D_UNICODE -DWIN32_LEAN_AND_MEAN ^
    -O2 -mwindows ^
    -Iinclude ^
    src\Config.cpp ^
    src\Audio.cpp ^
    src\KeyHook.cpp ^
    src\Actions.cpp ^
    src\MicOverlay.cpp ^
    src\SpotifyTracker.cpp ^
    src\Osd.cpp ^
    src\Tray.cpp ^
    src\WebViewSettings.cpp ^
    src\AppRegister.cpp ^
    src\main.cpp ^
    build_app.res ^
    -o %OUT% ^
    -luser32 -lshell32 -lole32 -loleaut32 -luuid -lwinmm -ladvapi32 -lgdi32 -ldwmapi -lcomdlg32 ^
    -static-libgcc -static-libstdc++ -static

if errorlevel 1 (
    echo [!] Compilation failed!
    exit /b 1
)

echo [OK] Successfully built: %OUT%
