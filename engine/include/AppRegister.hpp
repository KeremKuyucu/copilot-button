#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <string>

// Uygulamayı Windows'a resmi bir uygulama olarak tanıtır
// AUMID (AppUserModelID), App Paths ve Capabilities kayıtlarını yapar.
void RegisterAppWithWindows();

// Windows başlangıcında otomatik çalışma ayarı (HKCU\...\Run)
void SetAutoStartRegistry(bool enable);
bool GetAutoStartRegistry();
