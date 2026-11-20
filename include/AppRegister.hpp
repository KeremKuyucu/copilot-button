#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <string>

// Komut satırı bayrağı denetimi (büyük/küçük harf duyarsız, tam argüman eşleşmesi)
bool HasCommandLineFlag(const wchar_t* flag);

// Taşınabilir (Portable) mod denetimi: --portable / /portable veya exe yanında portable.flag
bool IsPortableMode();

// Uygulamayı Windows'a resmi bir uygulama olarak tanıtır:
// - AUMID (AppUserModelID)
// - Başlat menüsü kısayolu
// - App Paths (Win+R ile doğrudan CopilotButton çalıştırma)
// - Windows Ayarları -> Yüklü Uygulamalar (Apps & Features) ve Kaldırma (Uninstall) kaydı
void RegisterAppWithWindows();

// Windows başlangıcında otomatik çalışma ayarı:
// Yönetici yetkisi (requireAdministrator) nedeniyle Windows Explorer Run anahtarını
// yok sayabildiğinden (yuttuğundan), Run kaydı temizlenir ve yalnızca Task Scheduler (/rl highest) kullanılır.
void SetAutoStartRegistry(bool enable);

// Uygulamayı ve tüm bileşenlerini sistemden kaldırır (Kayıt Defteri, Görev Zamanlayıcı, Kısayollar, Dosyalar)
bool UninstallApp(bool silent = false);

// Uygulamanın her zaman %LOCALAPPDATA%\CopilotButton altında çalışmasını sağlar.
// Farklı bir konumdan açıldıysa kendini hedef klasöre kopyalar, yeni exe'yi başlatır ve true döner.
bool CheckAndPerformSelfRelocate();

// Eski kaynak dosyanın arka planda silinmesi
void CleanupOldSourceIfRequested();
