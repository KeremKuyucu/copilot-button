## 📦 Sürüm [1.3.1] – Güncelleme ve Dağıtım İyileştirmeleri

### 🐛 Hata Düzeltmeleri
* **[Otomatik Güncelleyici]:** Güncelleme kontrolü sırasında ağ gecikmelerinde ortaya çıkan `(0x8000000A)` zaman aşımı hatası giderildi. WinHttp zaman aşımları ve hata yakalama mekanizması güçlendirildi.

### 🚀 Dağıtım & Pipeline İyileştirmeleri
* **[GitHub Releases]:** Release sürecinde ham `.exe` dosyasının doğrudan yüklenmesi kaldırıldı; yalnızca dijital imzalı Inno Setup kurulum paketi (`CopilotButton-Setup.exe`) ve SHA-256 doğrulama dosyası yayınlanacak şekilde yapılandırıldı.
* **[Güvenlik & İmzalama]:** Kurulum paketi oluşturulmadan önce içerideki ana uygulamanın imzalanması sağlanarak imza bütünlüğü artırıldı.

### ⚠️ Kırıcı Değişiklikler
* Yoktur.

---

## 📦 Version [1.3.1] – Updater and Pipeline Improvements

### 🐛 Bug Fixes
* **[Auto-Updater]:** Fixed `(0x8000000A)` COM timeout error during update checks by improving asynchronous WinHttp handling and error resilience.

### 🚀 Release Pipeline Improvements
* **[GitHub Releases]:** Removed direct compilation `.exe` upload; releases now exclusively distribute the digitally signed Inno Setup package (`CopilotButton-Setup.exe`) and SHA-256 checksum.
* **[Code Signing]:** Ensured the packaged binary is signed before Inno Setup bundles it, guaranteeing complete signature integrity.