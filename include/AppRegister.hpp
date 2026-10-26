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

// Uygulamanın %LOCALAPPDATA%\CopilotButton altında çalışmasını denetler.
// Farklı bir konumdan (ör. İndirilenler) açıldıysa kendini hedef klasöre kopyalar,
// kısayol ve autostart'ı bağlar, yeni exe'yi başlatır ve true döner.
bool CheckAndPerformSelfRelocate();

// İndirilen geçici dosyanın silinmesi istenmişse (--delete-source) arka planda siler
void CleanupOldSourceIfRequested();
