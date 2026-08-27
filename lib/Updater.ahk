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
        whr.WaitForResponse()

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

        ; Değişiklik notlarını çek
        releaseBody := ""
        if RegExMatch(responseText, '"body"\s*:\s*"([^"]*?)"', &bodyMatch)
            releaseBody := StrReplace(bodyMatch[1], "\n", "`n")

        ; Kullanıcıya sor
        updateMsg := "Yeni sürüm mevcut!`n`n"
            . "Mevcut: v" . currentVersion . "`n"
            . "Yeni: v" . latestVersion . "`n"

        if (releaseBody != "")
            updateMsg .= "`n── Değişiklikler ──`n" . releaseBody . "`n"

        updateMsg .= "`nOtomatik olarak güncellensin mi?"

        result := MsgBox(updateMsg, "🔄 Güncelleme Mevcut — v" . latestVersion, "YesNo Icon!")
        if (result = "Yes") {
            if (setupUrl != "")
                PerformInstallerUpdate(setupUrl, latestVersion)
            else
                ShowTip("⚠️ İndirme bağlantısı bulunamadı!", 2500)
        }

    } catch as err {
        if (!silent)
            ShowTip("⚠️ Güncelleme kontrolü hatası: " . err.Message, 2500)
    }
}

PerformInstallerUpdate(setupUrl, newVersion) {
    tempInstaller := A_Temp "\CopilotButton_Setup.exe"

    ShowTip("⬇️ v" . newVersion . " güncellemesi indiriliyor...", 5000)

    try {
        if FileExist(tempInstaller)
            try FileDelete(tempInstaller)

        Download(setupUrl, tempInstaller)

        if !FileExist(tempInstaller) {
            ShowTip("⚠️ İndirme başarısız!", 2500)
            return
        }

        ShowTip("🔄 Güncelleme kuruluyor...", 2000)
        Sleep 1000

        ; Inno Setup'ı sessiz modda çalıştır ve uygulamayı kapat
        ; Inno Setup dosyaları yenileyip yeni sürümü başlatacaktır
        Run('"' . tempInstaller . '" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS')
        ExitApp()

    } catch as err {
        ShowTip("⚠️ Güncelleme hatası: " . err.Message, 3000)
    }
}
