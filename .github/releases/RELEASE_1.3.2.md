## 📦 Sürüm [1.3.2] – CI/CD Derleme Düzeltmeleri

### 🐛 Hata Düzeltmeleri
* **[CI/CD]:** GitHub Actions'ta Ahk2Exe derleyicisinin asenkron başlatılması nedeniyle `CopilotButton.exe` oluşturulamaması sorunu giderildi. `Start-Process -Wait` ile senkron bekleme sağlandı.
* **[CI/CD]:** Ahk2Exe'nin bulunamadığı durumlarda GitHub API 503 hatası alınması üzerine `Expand-Archive` işleminin `$zip = null` ile çökmesi düzeltildi. Try/catch ve HTTP fallback mekanizmaları eklendi.

### 🚀 İyileştirmeler
* **[CI/CD]:** Ahk2Exe aday yolları genişletildi; otomatik dosya sistemi araması ve çok katmanlı fallback stratejisi eklendi.

### ⚠️ Kırıcı Değişiklikler
* Yoktur.

---

## 📦 Version [1.3.2] – CI/CD Build Fixes

### 🐛 Bug Fixes
* **[CI/CD]:** Fixed `CopilotButton.exe` not being created because Ahk2Exe was launched asynchronously on GitHub Actions. Now uses `Start-Process -Wait` for synchronous execution.
* **[CI/CD]:** Fixed `Expand-Archive` crash when GitHub API returned 503, causing `$zip` to be null. Added try/catch with HTTP fallback.

### 🚀 Improvements
* **[CI/CD]:** Expanded Ahk2Exe candidate paths with filesystem search and multi-tier fallback strategy.
