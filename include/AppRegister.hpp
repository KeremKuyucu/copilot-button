#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <string>

// Uygulamayı Windows'a resmi bir uygulama olarak tanıtır
// AUMID (AppUserModelID), App Paths ve Başlat menüsü kaydı yapar.
void RegisterAppWithWindows();

// Windows başlangıcında otomatik çalışma ayarı (HKCU\...\Run ve Task Scheduler)
void SetAutoStartRegistry(bool enable);
bool GetAutoStartRegistry();

// Uygulamanın her zaman %LOCALAPPDATA%\CopilotButton altında çalışmasını sağlar.
// Farklı bir konumdan açıldıysa kendini hedef klasöre kopyalar, yeni exe'yi başlatır ve true döner.
bool CheckAndPerformSelfRelocate();

// Eski kaynak dosyanın arka planda silinmesi
void CleanupOldSourceIfRequested();
