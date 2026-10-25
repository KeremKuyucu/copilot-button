@echo off
rem ═══════════════════════════════════════════════════════════════════
rem  CopilotButton Engine – MSVC derleme betiği
rem  Kullanım: build_msvc.bat [Release|Debug]
rem  Gereksinim: Visual Studio 2022 veya 2019 yüklü olmalı
rem ═══════════════════════════════════════════════════════════════════
setlocal enabledelayedexpansion

set CONFIG=%1
if "%CONFIG%"=="" set CONFIG=Release

set BUILD_DIR=build_msvc_%CONFIG%

echo [*] CMake yapılandırma (MSVC, %CONFIG%)...
cmake -S . -B %BUILD_DIR% ^
    -G "Visual Studio 17 2022" ^
    -A x64

if errorlevel 1 (
    echo [!] CMake yapılandırma başarısız!
    exit /b 1
)

echo [*] Derleme başlıyor...
cmake --build %BUILD_DIR% --config %CONFIG% -j4

if errorlevel 1 (
    echo [!] Derleme başarısız!
    exit /b 1
)

echo [✓] Başarılı: ..\CopilotButton.exe
