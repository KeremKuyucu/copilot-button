## 📦 Sürüm 1.2.2 – Gelişmiş Kurulum, Otomatik Başlatma ve MITM Sertifika Doğrulaması

### 🚀 Değişiklikler

* **🔒 Dijital Sertifika Doğrulaması & MITM Koruması:**
  Otomatik güncelleme mekanizmasına dijital sertifika parmak izi (thumbprint) kontrolü eklendi. İndirilen kurulum paketi (`CopilotButton_Setup.exe`), Win32 CryptoAPI ve PowerShell Authenticode doğrulaması üzerinden `EXPECTED_CERT_THUMBPRINT` ile eşleştirilir. Beklenmeyen ya da geçersiz imzalara sahip güncellemeler derhal engellenir ve dosya silinir. Ayrıca GitHub API isteklerine 5 saniyelik yanıt zaman aşımı (timeout) getirildi.

* **🚀 Windows ile Birlikte Otomatik Başlatma Seçeneği:**
  Ayarlar arayüzündeki "Sistem & Geri Bildirim" bölümüne "Windows ile birlikte otomatik başlat" seçeneği eklendi. Bu seçenek, kayıt defteri (`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`) ve `config.ini` dosyası ile tam senkronize çalışarak uygulamanın başlangıçta açılmasını doğrudan GUI üzerinden yönetmeyi sağlar.

* **📦 Gelişmiş Kurulum ve Sessiz Güncelleme Desteği:**
  Inno Setup kurulum paketine Başlat Menüsü kısayolu eklendi. Arka plan otomatik güncellemelerinde (`/VERYSILENT`), kurulumun ardından uygulamanın otomatik olarak yeniden başlayabilmesi için `WizardSilent` kontrolü ve `skipifsilent` parametresi entegre edildi. Eski kalıntı temizleme girdileri optimize edildi.

* **🎙️ Donanım & Harici Mikrofon Durumunu Sürekli İzleme:**
  Kulaklık üzerindeki fiziksel tuşlardan veya harici uygulamalardan yapılan mikrofon açma/kapama durumlarını yakalamak için 1 saniyelik periyodik senkronizasyon zamanlayıcısı eklendi. Bu sayede mikrofon simgesi ve ekran üzeri bildirim (overlay) her zaman güncel donanım durumuyla senkronize kalır.

* **🔧 Derleme ve Çıktı Mimarisi Düzenlemesi:**
  `build-and-deploy.ps1` ve Inno Setup yapılandırması güncellenerek derleme çıktıları doğrudan `Outputs\copilot-button` klasörüne yönlendirildi.

### 🐛 Hata Düzeltmeleri

* **ToggleDeafen Senkronizasyonu:** Mikrofon veya sistem sesinden biri açıkken diğeri kapalı kaldığında oluşan durum uyumsuzluğu giderildi; her iki kanal da susturulmuşsa açılması, herhangi biri açıksa her ikisinin birden susturulması sağlanarak ses ve mikrofon tam uyumlu hale getirildi.
* **YouTube Music Tarayıcı Başlığı Ayrıştırma:** YouTube Music web sürümü dinlenirken parça adının sonuna tarayıcı adı (örneğin `- Google Chrome` veya `- Brave`) eklenmesi engellendi ve parça bilgisi daha temiz görüntülenecek şekilde regex deseni düzeltildi.
* **Sessiz Mikrofon Durum Senkronizasyonu:** Arka planda her saniye çalışan mikrofon durumu denetiminin (`SyncMicState`) ses efekti çalması veya bildirim balonu göstermesi engellenerek sessiz modda (`silent := true`) çalışması sağlandı.

### ⚠️ Kırıcı Değişiklikler (varsa)

* Bu sürümde geriye dönük uyumluluğu bozan herhangi bir kırıcı değişiklik bulunmamaktadır.
