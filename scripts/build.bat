@echo off
setlocal
echo ============================================
echo  Copilot Button - Derleme Scripti (MinGW)
echo ============================================

cd /d "%~dp0\.."

echo [1/2] Kaynak dosyalari derleniyor (windres)...
windres -I resources -i resources/app.rc -o resources/app.res -O coff
if errorlevel 1 goto error

echo [2/2] CopilotButton.exe olusturuluyor (C++20)...
g++ -std=c++20 -O2 -s -flto -ffunction-sections -fdata-sections -Wl,--gc-sections -mwindows ^
    -I include ^
    src/main.cpp src/Tray.cpp src/AppRegister.cpp ^
    src/Config.cpp src/Audio.cpp ^
    src/KeyHook.cpp src/Actions.cpp src/MicOverlay.cpp ^
    src/MediaTracker.cpp src/Osd.cpp resources/app.res ^
    -o CopilotButton.exe ^
    -luser32 -lshell32 -lole32 -loleaut32 -luuid -lwinmm -ladvapi32 -lgdi32 -ldwmapi -lcomdlg32 -lwindowsapp ^
    -static-libgcc -static-libstdc++ -static
if errorlevel 1 goto error

echo.
echo ============================================
echo  BASARILI!
echo  - CopilotButton.exe (Tek Parca Hafif Uygulama)
echo ============================================
goto end

:error
echo.
echo [HATA] Derleme basarisiz oldu!
exit /b 1

:end
