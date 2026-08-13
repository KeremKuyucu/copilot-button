# 🚀 Copilot Button Controller (AutoHotkey v2)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2.0+-green.svg)](https://www.autohotkey.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue)](https://microsoft.com)

Windows 11 klavyelerindeki **Copilot tuşunu (`Win + Shift + F23`)** gelişmiş bir **Mikrofon & Medya Kontrolörüne** dönüştüren güçlü ve özelleştirilebilir bir AutoHotkey v2 aracıdır.

---

## ✨ Öne Çıkan Özellikler

- 🎙️ **1 Tık — Mikrofon Kontrolü:** Sistem mikrofonunu anında açar / susturur. 
  - Discord tarzı ses efekti çalar.
  - Sol üstte mikrofon durumunu gösteren özel OSD açılır.
  - Sistem tepsisindeki (Tray) ikon mikrofon kapalıyken otomatik olarak **kırmızı mikrofon ikonuna** dönüşür.
- ⏸️ **2 Tık — Durdur / Oynat + Now Playing:** Şarkıyı oynatır / durdurur ve aktif şarkı adını ekranda gösterir (Spotify & YouTube Music destekli).
- ⏭️ **3 Tık — Sonraki Parça:** Sonraki şarkıya geçer ve yeni şarkı adını OSD'de görüntüler.
- ⏮️ **4 Tık — Önceki Parça / Özel Eylem:** Önceki şarkıya geçer veya atadığınız özel eylemi çalıştırır.
- 🗣️ **Basılı Tutma (Hold) Modları:**
  - **MusicApp:** Spotify veya YouTube Music'i açar / öne getirir.
  - **PushToTalk:** Tuşa basılı tuttuğunuz sürece mikrofon açılır, bırakınca otomatik kapanır.
  - **CustomApp:** Belirlediğiniz herhangi bir `.exe` uygulamasını veya internet bağlantısını (`URL`) açar.
- 💬 **Gelişmiş OSD Bildirimleri:**
  - **Konum Seçimi:** Sol Üst, Sağ Üst, Sol Alt, Sağ Alt, Merkez.
  - **Renk & Font:** Özelleştirilebilir Hex renk kodu ve font boyutu.
  - **Fade Animasyonu:** Yumuşak beliriş ve kayboluş (Fade-in / Fade-out) animasyonu.
- ⚙️ **Görsel Ayarlar Menüsü (GUI):** Tüm zamanlama, eylem atamaları ve OSD ayarlarını grafiksel arayüzden kolayca yönetin.
- 🔄 **Otomatik Güncelleme Sistemi:** Yeni sürümleri GitHub Releases üzerinden otomatik kontrol eder ve tek tıkla kendini günceller.
- 📁 **Sıfır Bağımlılık & Otomatik Kurulum:** Tek bir `.exe` çalıştırıldığında kendini `%LocalAppData%\CopilotButton` klasörüne kopyalar, simgeleri ve konfigürasyonu otomatik üretir.

---

## 🛠️ Kurulum ve Kullanım

### 🚀 Hızlı Başlangıç (.exe)
1. GitHub [Releases](https://github.com/KeremKuyucu/copilot-button/releases) sayfasından en son `copilot-buton.exe` dosyasını indirin.
2. Dosyayı çalıştırın. 
3. Uygulama otomatik olarak `%LocalAppData%\CopilotButton` klasörüne yerleşecek ve sistem tepsinizde (sağ alt) çalışmaya başlayacaktır.

### 📜 Kaynak Kodu ile Çalıştırma (.ahk)
1. Bilgisayarınızda [AutoHotkey v2](https://www.autohotkey.com/) yüklü olduğundan emin olun.
2. Repoyu klonlayın veya zip olarak indirin.
3. `copilot-buton.ahk` dosyasına çift tıklayarak çalıştırın.

---

## ⚙️ Varsayılan Tıklama Kombinasyonları

| Tetikleyici | Varsayılan Eylem | Açıklama |
|---|---|---|
| **1 Tık** | `MicMute` | Mikrofonu Sustur / Aç |
| **2 Tık** | `PlayPause` | Şarkıyı Durdur / Oynat + Now Playing OSD |
| **3 Tık** | `NextTrack` | Sonraki Şarkı + Şarkı İsmi OSD |
| **4 Tık** | `PrevTrack` | Önceki Şarkı |
| **Basılı Tutma** | `MusicApp` | Spotify / YouTube Music Aç veya Öne Getir |

*Tüm bu eylemler Ayarlar menüsünden (`⚙️ Ayarlar`) veya `config.ini` dosyasından değiştirilebilir.*

---

## 📄 Yapılandırma (`config.ini`)

Uygulama ilk çalıştırıldığında aşağıdaki `config.ini` dosyasını otomatik oluşturur:

```ini
[Settings]

; Tıklama için maksimum bekleme süresi (milisaniye)
DoubleTapMs=250

; Basılı tutma için minimum süre (milisaniye)
HoldMs=250

; Müzik Uygulaması Seçimi: YTM veya Spotify
MusicApp=YTM

; Windows başlangıcında otomatik çalıştır (1 = Açık, 0 = Kapalı)
AutoStart=1

; YouTube Music Ayarları
YtmURL=https://music.youtube.com
YtmWindowTitle=YouTube Music

; Spotify Ayarları
SpotifyCmd=spotify:
SpotifyWindowTitle=ahk_exe spotify.exe

; ── OSD Bildirim Ayarları ──
OsdPosition=TopLeft
OsdColor=00E5FF
OsdFontSize=10
OsdDurationMs=1500
OsdFadeEnabled=1

; ── Basılı Tutma Eylemi ──
; Options: MusicApp, PushToTalk, CustomApp
HoldAction=MusicApp
CustomAppPath=

; ── Tık Eylem Atamaları ──
; Options: MicMute, PlayPause, NextTrack, PrevTrack, VolumeUp, VolumeDown, None
Action1=MicMute
Action2=PlayPause
Action3=NextTrack
Action4=PrevTrack

; ── Tray İkonu ──
TrayIconMicState=1
```

---

## 📜 Lisans

Bu proje **GNU General Public License v3.0 (GPL-3.0)** altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına göz atabilirsiniz.
