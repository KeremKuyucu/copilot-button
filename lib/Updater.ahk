; ══════════════════════════════════════════
;  GITHUB OTOMATİK GÜNCELLEME SİSTEMİ (Inno Setup)
; ══════════════════════════════════════════

StartupUpdateCheck() {
    CheckForUpdates(true)
}

CompareVersions(v1, v2) {
    p1 := StrSplit(v1, ".")
    p2 := StrSplit(v2, ".")
    maxLen := Max(p1.Length, p2.Length)
    loop maxLen {
        num1 := (A_Index <= p1.Length && IsInteger(p1[A_Index])) ? Integer(p1[A_Index]) : 0
        num2 := (A_Index <= p2.Length && IsInteger(p2[A_Index])) ? Integer(p2[A_Index]) : 0
        if (num1 > num2)
            return 1
        if (num1 < num2)
            return -1
    }
    return 0
}

CheckForUpdates(silent := true) {
    global APP_VERSION

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://api.github.com/repos/KeremKuyucu/copilot-button/releases/latest", true)
        whr.SetRequestHeader("User-Agent", "CopilotButton-AutoUpdater")
        whr.SetRequestHeader("Accept", "application/vnd.github.v3+json")
        whr.Send()
        whr.WaitForResponse(5)

        if (whr.Status != 200) {
            if (!silent)
                ShowTip("⚠️ Güncelleme kontrolü başarısız (HTTP " . whr.Status . ")", 2500)
            return
        }

        responseText := whr.ResponseText

        ; tag_name alanını regex ile çek
        if !RegExMatch(responseText, '"tag_name"\s*:\s*"([^"]+)"', &tagMatch) {
            if (!silent)
                ShowTip("⚠️ Sürüm bilgisi okunamadı", 2500)
            return
        }

        latestVersion := RegExReplace(tagMatch[1], "^v", "")
        currentVersion := RegExReplace(APP_VERSION, "^v", "")

        if (CompareVersions(latestVersion, currentVersion) <= 0) {
            if (!silent)
                ShowTip("✅ Zaten güncel sürümdesiniz (v" . currentVersion . ")")
            return
        }

        ; Release asset'leri içinde Setup.exe var mı kontrol et (Öncelikli)
        setupUrl := ""
        if RegExMatch(responseText, '"browser_download_url"\s*:\s*"([^"]+Setup\.exe)"', &setupMatch)
            setupUrl := setupMatch[1]
        else if RegExMatch(responseText, '"browser_download_url"\s*:\s*"([^"]+\.exe)"', &exeMatch)
            setupUrl := exeMatch[1]

        ; Yeni sürüm varsa kullanıcıya sormadan arka planda otomatik indir ve kur
        if (setupUrl != "") {
            PerformInstallerUpdate(setupUrl, latestVersion, silent)
        } else {
            if (!silent)
                ShowTip("⚠️ İndirme bağlantısı bulunamadı!", 2500)
        }

    } catch as err {
        if (!silent)
            ShowTip("⚠️ Güncelleme kontrolü hatası: " . err.Message, 2500)
    }
}

VerifyInstallerSignature(filePath, expectedThumbprint) {
    if (!FileExist(filePath) || expectedThumbprint = "")
        return false

    expectedClean := StrUpper(Trim(RegExReplace(expectedThumbprint, "[\r\n\s\-:]", "")))

    hStore := 0
    hMsg := 0
    ; CERT_QUERY_OBJECT_FILE = 1, CERT_QUERY_CONTENT_FLAG_PKCS7_SIGNED_EMBED = 0x400
    success := DllCall("crypt32\CryptQueryObject",
        "uint", 1,
        "wstr", filePath,
        "uint", 0x400,
        "uint", 0x0E,
        "uint", 0,
        "ptr*", &pEncoding := 0,
        "ptr*", &pContentType := 0,
        "ptr*", &pFormatType := 0,
        "ptr*", &hStore,
        "ptr*", &hMsg,
        "ptr*", &pContext := 0,
        "int"
    )

    matched := false
    if (success && hStore) {
        pCertContext := 0
        while (pCertContext := DllCall("crypt32\CertEnumCertificatesInStore", "ptr", hStore, "ptr", pCertContext, "ptr")) {
            hashSize := 0
            if DllCall("crypt32\CertGetCertificateContextProperty", "ptr", pCertContext, "uint", 3, "ptr", 0, "uint*", &hashSize) {
                hashBuf := Buffer(hashSize, 0)
                if DllCall("crypt32\CertGetCertificateContextProperty", "ptr", pCertContext, "uint", 3, "ptr", hashBuf, "uint*", &hashSize) {
                    thumbprint := ""
                    loop hashSize {
                        thumbprint .= Format("{:02X}", NumGet(hashBuf, A_Index - 1, "UChar"))
                    }
                    if (thumbprint == expectedClean) {
                        matched := true
                        DllCall("crypt32\CertFreeCertificateContext", "ptr", pCertContext)
                        break
                    }
                }
            }
        }
        DllCall("crypt32\CertCloseStore", "ptr", hStore, "uint", 0)
    }

    if (hMsg)
        DllCall("crypt32\CryptMsgClose", "ptr", hMsg)

    ; Win32 API ile yakalanamazsa Authenticode PowerShell kontrolü (Fallback)
    if (!matched) {
        try {
            tempOut := A_Temp "\sig_check_" . A_TickCount . ".txt"
            psCmd := 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; (Get-AuthenticodeSignature \`"' . filePath . '\`").SignerCertificate.Thumbprint | Out-File -FilePath \`"' . tempOut . '\`" -Encoding ascii"'
            RunWait(psCmd, , "Hide")
            if FileExist(tempOut) {
                actualThumbprint := StrUpper(Trim(RegExReplace(FileRead(tempOut), "[\r\n\s\-:]", "")))
                try FileDelete(tempOut)
                if (actualThumbprint != "" && actualThumbprint == expectedClean)
                    matched := true
            }
        }
    }

    return matched
}

PerformInstallerUpdate(setupUrl, newVersion, silent := false) {
    global EXPECTED_CERT_THUMBPRINT
    tempInstaller := A_Temp "\CopilotButton_Setup.exe"

    ShowTip("⬇️ v" . newVersion . " güncellemesi arka planda indiriliyor...", 4000)

    try {
        if FileExist(tempInstaller)
            try FileDelete(tempInstaller)

        Download(setupUrl, tempInstaller)

        if !FileExist(tempInstaller) {
            if (!silent)
                ShowTip("⚠️ İndirme başarısız!", 2500)
            return
        }

        ; ── Dijital İmza & MITM Güvenlik Kontrolü ──
        if (EXPECTED_CERT_THUMBPRINT != "") {
            if (!VerifyInstallerSignature(tempInstaller, EXPECTED_CERT_THUMBPRINT)) {
                try FileDelete(tempInstaller)
                ShowTip("❌ Güvenlik Uyarısı: İndirilen güncellemenin sertifikası doğrulanamadı!", 4000)
                return
            }
        }

        ShowTip("🔄 v" . newVersion . " kuruluyor ve başlatılıyor...", 2000)
        Sleep 1000

        ; Inno Setup'ı tamamen sessiz modda çalıştır ve uygulamayı kapat
        ; Inno Setup dosyaları güncelleyip WizardSilent kuralı ile yeni sürümü otomatik başlatacaktır
        Run('"' . tempInstaller . '" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS')
        ExitApp()

    } catch as err {
        if (!silent)
            ShowTip("⚠️ Güncelleme hatası: " . err.Message, 3000)
    }
}
