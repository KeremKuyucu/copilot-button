# 🚀 Copilot Button Controller (C++20 Native Engine)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Language: C++20](https://img.shields.io/badge/Language-C%2B%2B20-00599C.svg)](https://isocpp.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20(x64)-blue)](https://microsoft.com)
[![Architecture](https://img.shields.io/badge/Architecture-Standalone%20%2F%20Portable-success)](#)
[![UI: WebView2](https://img.shields.io/badge/UI-WebView2%20%2B%20Win32-purple.svg)](https://developer.microsoft.com/microsoft-edge/webview2/)

Windows 11 klavyelerindeki fiziksel **Copilot tuşunu (`Win + Shift + F23`)** gelişmiş, gecikmesiz bir **Mikrofon, Medya ve Kısayol Denetleyicisine** dönüştüren yüksek performanslı, bağımsız (standalone) bir yerel C++20 Win32 motorudur.

---

## ✨ Öne Çıkan Özellikler

- ⚡ **Ultra-Hafif C++20 Motoru:** Arka planda yalnızca **~5 MB RAM** tüketir. Harici çalışma zamanı kütüphanesi (runtime) gerektirmez; tamamen saf Win32 ve modern C++20 ile inşa edilmiştir.
- 🛡️ **Oyun & Uygulama Koruması (Anti-Modifier Leak Hook):** Donanımsal Copilot tuşunun bastığı `Left Shift` ve `Left Windows` tuşlarını alçak seviye klavye kancası (`WH_KEYBOARD_LL`) seviyesinde anında yutar. Oyunlarda Shift tuşunun (koşma/çömelme) takılması veya Windows Başlat menüsünün açılması kesin olarak engellenir.
- 🎙️ **Windows Core Audio & Gerçek Zamanlı Bildirimler:** Mikrofon susturma/açma işlemleri doğrudan Windows Core Audio API (`IAudioEndpointVolume`) üzerinden milisaniye altı sürede gerçekleşir. Harici mikrofon değişiklikleri `IAudioEndpointVolumeCallback` ile anında masaüstü rozetine ve OSD'ye yansıtılır.
- ⏸️ **Spotify Entegrasyonu & Parça Takibi:** Spotify masaüstü oynatıcısını izleyerek çalan şarkı ve sanatçı adını yakalar. Parça değişimlerinde ekranda dinamik OSD kartı gösterir.
- 🗣️ **Basılı Tutma (Hold) Modları:**
  - **PushToTalk:** Tuşa basılı tuttuğunuz sürece mikrofon açılır, bıraktığınız an otomatik susturulur.
  - **CustomApp:** Belirlediğiniz herhangi bir `.exe` uygulamasını veya internet bağlantısını (`URL`) başlatır.
- 💬 **Gelişmiş Ekran Bildirimleri (OSD):**
  - **Konumlandırma:** Sol Üst, Sağ Üst, Sol Alt, Sağ Alt, Merkez.
  - **Kişiselleştirme:** Özel Hex renk kodu, font boyutu ve yumuşak fade animasyonu.
- ⚙️ **Modern WebView2 Ayarlar Paneli:**
  - Yerel HTTP soketi veya port açmadan, bellek içi sanal host eşlemesi (`SetVirtualHostNameToFolderMapping`) ile çalışır.
  - **İsteğe Bağlı (On-Demand) Yaşam Döngüsü:** Ayarlar penceresi kapatıldığında tüm WebView2 denetleyicileri ve Edge alt süreçleri bellekten tamamen silinir.
- 📦 **Tek Dosya (Standalone) & Gömülü Kaynaklar:**
  - HTML arayüzü, `WebView2Loader.dll`, uygulama ikonu ve manifest dosyası doğrudan `.exe` içine gömülüdür (`RCDATA`).
  - Kurulum sihirbazına gerek duymadan indirip doğrudan taşınabilir olarak çalıştırabilirsiniz.
- 🚀 **Akıllı Windows Tanıtımı & İki Katmanlı AutoStart:**
  - `Win + R` veya terminalden `CopilotButton` yazılarak anında çalıştırılabilir (`App Paths`).
  - Başlat Menüsüne (`%APPDATA%\...\Start Menu\Programs\Copilot Button.lnk`) otomatik indekslenir.
  - Yönetici yetkili arka plan motoru için hem Windows Kayıt Defteri (`Run`) hem de Görev Zamanlayıcısı (`schtasks /rl highest`) entegrasyonuyla bilgisayar açılışında UAC uyarısı vermeden otomatik başlar.

---

## 🎯 Tıklama Eylem Seçenekleri

| Eylem Adı | Açıklama |
|---|---|
| `MicMute` | Sistem Mikrofonunu Sustur / Aç *(Varsayılan 1 Tık)* |
| `PlayPause` | Medyayı Oynat / Duraklat *(Varsayılan 2 Tık)* |
| `NextTrack` | Sonraki Şarkı *(Varsayılan 3 Tık)* |
| `PrevTrack` | Önceki Şarkı |
| `MasterMute` | Sistem Genel Sesini Aç / Kapat |
| `ToggleDeafen` | Hem Sistem Sesini Hem Mikrofonu Aynı Anda Sustur / Aç |
| `LockScreen` | Bilgisayarı Kilitle |
| `PushToTalk` | Bas-Konuş Modu *(Varsayılan Basılı Tutma)* |
| `CustomApp` | Özel Uygulama veya URL Başlatıcı |
| `None` | Eylem Yok *(Varsayılan 4 Tık)* |

*Tüm bu eylemler Sistem Tepsisindeki `⚙️ Ayarlar` menüsünden veya `config.ini` dosyasından 1, 2, 3, 4 tık ve basılı tutma için kolayca yapılandırılabilir.*

---

## 🚀 İndirme ve Kullanım

### Hızlı Başlangıç
1. [Releases](https://github.com/KeremKuyucu/copilot-button/releases) sayfasından en son `CopilotButton.exe` veya taşınabilir `.zip` paketini indirin.
2. `CopilotButton.exe` dosyasını çalıştırın.
3. Uygulama sistem tepsisinde (sağ alt) aktifleşir.
4. Ayarları değiştirmek için tepsi simgesine sağ tıklayıp **⚙️ Ayarlar** seçeneğini seçin.

---

## 🛠️ Kaynak Koddan Derleme (Build)

Projeyi yerel olarak MinGW-w64 ile derlemek için:

```cmd
git clone https://github.com/KeremKuyucu/copilot-button.git
cd copilot-button
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

Derleme tamamlandığında ana dizinde tek parça, bağımsız `CopilotButton.exe` oluşturulacaktır.

---

## 📄 Yapılandırma (`config.ini`)

Uygulama ilk kez çalıştırıldığında kendi dizininde otomatik olarak aşağıdaki `config.ini` dosyasını oluşturur:

```ini
[Settings]

; ── Donanım ve Tıklama Eylemleri ──
; Tıklama için maksimum bekleme süresi (milisaniye)
DoubleTapMs=250

; Basılı tutma için minimum süre (milisaniye)
HoldMs=250

; 1 Tık Eylemi (MicMute, PlayPause, NextTrack, PrevTrack, MasterMute, ToggleDeafen, LockScreen, None)
Action1=MicMute

; 2 Tık Eylemi
Action2=PlayPause

; 3 Tık Eylemi
Action3=NextTrack

; 4 Tık Eylemi
Action4=None

; Basılı Tutma Eylemi (PushToTalk: bas-konuş, CustomApp: özel uygulama/URL)
HoldAction=PushToTalk

; CustomApp seçildiğinde açılacak uygulama yolu veya URL
CustomAppPath=

; ── Sistem ve Başlangıç ──
; Windows başlangıcında otomatik çalıştır (1 = Açık, 0 = Kapalı)
AutoStart=1

; Ses Efektleri (Mikrofon susturulduğunda/açıldığında Windows sesini çal)
SoundFxEnabled=1

; ── Spotify ve OSD Ayarları ──
; Spotify Şarkı Değişiminde OSD Göster (1 = Açık, 0 = Kapalı)
SpotifyTrackOsd=1

; OSD Konumu: TopLeft, TopRight, BottomLeft, BottomRight, Center
OsdPosition=TopLeft

; OSD Metin Rengi (hex, # olmadan)
OsdColor=00E5FF

; OSD Font Boyutu (varsayılan: 10)
OsdFontSize=10

; OSD Gösterim Süresi (milisaniye, varsayılan: 1500)
OsdDurationMs=1500

; OSD Fade Animasyonu (1 = Açık, 0 = Kapalı)
OsdFadeEnabled=1
```

---

## 📜 Lisans

Bu proje **GNU General Public License v3.0 (GPL-3.0)** altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına göz atabilirsiniz.
