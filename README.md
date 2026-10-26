# 🚀 Copilot Button Controller (C++20 Native Engine)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Language: C++20](https://img.shields.io/badge/Language-C%2B%2B20-00599C.svg)](https://isocpp.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20(x64)-blue)](https://microsoft.com)
[![Architecture](https://img.shields.io/badge/Architecture-Single%20Binary%20%2F%20Portable-success)](#)
[![RAM Usage](https://img.shields.io/badge/RAM-~2MB-brightgreen.svg)](#)

Windows 11 klavyelerindeki fiziksel **Copilot tuşunu (`Win + Shift + F23`)** gelişmiş, gecikmesiz bir **Mikrofon, Medya ve Kısayol Denetleyicisine** dönüştüren yüksek performanslı, tek parça (standalone) yerel C++20 Win32 uygulamasıdır.

---

## ✨ Öne Çıkan Özellikler

- ⚡ **Ultra-Hafif Tek Parça Mimari (`CopilotButton.exe`):**
  - Tüm klavye kancası (`WH_KEYBOARD_LL`), ses denetimi, mikrofon rozeti, Spotify şarkı takibi, sistem tepsisi (Tray) ve otomatik başlatma mantığı tek bir ~440 KB boyutundaki yürütülebilir dosyada birleştirilmiştir.
  - Harici WebView2, web tarayıcı motoru veya arka plan yardımcı süreçleri yoktur. Yalnızca ~2 MB RAM tüketir.
- ⚙️ **Anında Canlı Yapılandırma (Hot-Reloading):**
  - Tepsi menüsünden **⚙️ Ayarlar** seçildiğinde doğrudan `config.ini` dosyasını varsayılan metin düzenleyicinizde açar.
  - Arka plandaki dosya izleyici iş parçacığı (`WatcherThread`), dosyayı kaydettiğiniz anda değişiklikleri uygulamayı yeniden başlatmaya gerek kalmadan canlı olarak uygular.
- 🛡️ **Oyun & Uygulama Koruması (Anti-Modifier Leak Hook):** Donanımsal Copilot tuşunun bastığı `Left Shift` ve `Left Windows` tuşlarını alçak seviye klavye kancası (`WH_KEYBOARD_LL`) seviyesinde anında yutar. Oyunlarda Shift tuşunun (koşma/çömelme) takılması veya Windows Başlat menüsünün açılması kesin olarak engellenir.
- 🎙️ **Windows Core Audio & Gerçek Zamanlı Bildirimler:** Mikrofon susturma/açma işlemleri doğrudan Windows Core Audio API (`IAudioEndpointVolume`) üzerinden milisaniye altı sürede gerçekleşir. Harici mikrofon değişiklikleri `IAudioEndpointVolumeCallback` ile anında masaüstü rozetine ve OSD'ye yansıtılır.
- ⏸️ **Windows Media API (GSMTC) & Spotify Takibi:** Pencere tarama yerine modern Windows Media Transport Controls olayları ile sıfır CPU tüketimiyle çalan parça ve sanatçı adını anında yakalar. Şarkı değişimlerinde ekranda şık OSD kapsülü gösterir.
- 🗣️ **Basılı Tutma (Hold) Modları:**
  - **PushToTalk:** Tuşa basılı tuttuğunuz sürece mikrofon açılır, bıraktığınız an otomatik susturulur.
  - **CustomApp:** Belirlediğiniz herhangi bir `.exe` uygulamasını veya internet bağlantısını (`URL`) başlatır.
- 💬 **Gelişmiş Ekran Bildirimleri (OSD):**
  - **Konumlandırma:** Sol Üst, Sağ Üst, Sol Alt, Sağ Alt, Merkez.
  - **Kişiselleştirme:** Özel Hex renk kodu, font boyutu ve yumuşak fade animasyonu.
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
1. [Releases](https://github.com/KeremKuyucu/copilot-button/releases) sayfasından en son **`CopilotButton.exe`** dosyasını indirin.
2. `CopilotButton.exe` dosyasını çalıştırın.
3. Uygulama sistem tepsisinde (sağ alt) aktifleşir.
4. Ayarları değiştirmek için tepsi simgesine sağ tıklayıp **⚙️ Ayarlar** seçeneğini seçin (`config.ini` dosyası açılır).

---

## 🛠️ Kaynak Koddan Derleme (Build)

Projeyi yerel olarak MinGW-w64 ile derlemek için:

```cmd
git clone https://github.com/KeremKuyucu/copilot-button.git
cd copilot-button
scripts\build.bat
```

veya CMake ile:

```cmd
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

Derleme tamamlandığında ana dizinde tek bir çalıştırılabilir dosya oluşturulur:
- **`CopilotButton.exe`**: Tüm işlevleri barındıran hafif, tek parça sistem tepsisi ve klavye denetleyicisi.

---

## 📄 Yapılandırma (`config.ini`)

Uygulama ilk kez çalıştırıldığında kendi dizininde tüm açıklamalarıyla birlikte `config.ini` dosyasını otomatik oluşturur. Tepsi menüsünden **⚙️ Ayarlar** seçilerek dosya doğrudan açılabilir; yapılan değişiklikler dosyayı kaydettiğiniz anda canlı (**hot-reload**) olarak uygulanır.

---

## 📜 Lisans

Bu proje **GNU General Public License v3.0 (GPL-3.0)** altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına göz atabilirsiniz.
