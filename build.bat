@echo off
setlocal
echo ============================================
echo  Copilot Button - Derleme Scripti (MinGW)
echo ============================================

echo [1/4] Engine kaynak dosyalari derleniyor (windres)...
windres -I engine -i engine/app.rc -o engine/app.res -O coff
if errorlevel 1 goto error

echo [2/4] CopilotButtonEngine.exe olusturuluyor (C++20)...
g++ -std=c++20 -O2 -s -flto -ffunction-sections -fdata-sections -Wl,--gc-sections -mwindows -I engine/include -I common/include ^
    engine/src/main.cpp common/src/Config.cpp engine/src/Audio.cpp ^
    engine/src/KeyHook.cpp engine/src/Actions.cpp engine/src/MicOverlay.cpp ^
    engine/src/SpotifyTracker.cpp engine/src/Osd.cpp engine/app.res ^
    -o CopilotButtonEngine.exe ^
    -luser32 -lshell32 -lole32 -loleaut32 -luuid -lwinmm -ladvapi32 -lgdi32 -ldwmapi -lcomdlg32 -lwindowsapp ^
    -static-libgcc -static-libstdc++ -static
if errorlevel 1 goto error

echo [3/4] GUI kaynak dosyalari derleniyor (windres)...
windres -I gui/resources -I gui -i gui/app.rc -o gui/app.res -O coff
if errorlevel 1 goto error

echo [4/4] CopilotButton.exe olusturuluyor (C++20)...
g++ -std=c++20 -O2 -s -flto -ffunction-sections -fdata-sections -Wl,--gc-sections -mwindows -I gui/include -I common/include ^
    gui/src/main.cpp gui/src/Tray.cpp gui/src/WebViewSettings.cpp ^
    gui/src/AppRegister.cpp common/src/Config.cpp gui/app.res ^
    -o CopilotButton.exe ^
    -luser32 -lshell32 -lole32 -loleaut32 -luuid -lwinmm -ladvapi32 -lgdi32 -ldwmapi -lcomdlg32 ^
    -static-libgcc -static-libstdc++ -static
if errorlevel 1 goto error

echo.
echo ============================================
echo  BASARILI!
echo  - CopilotButton.exe (GUI / Tray)
echo  - CopilotButtonEngine.exe (Arka Plan Motoru)
echo ============================================
goto end

:error
echo.
echo [HATA] Derleme basarisiz oldu!
exit /b 1

:end
