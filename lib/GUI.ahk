; ══════════════════════════════════════════
;  GUI, AYARLAR PANELİ & TEMA MODÜLÜ
; ══════════════════════════════════════════

; ══════════════════════════════════════════
;  BAŞLAT MENÜSÜ KISAYOL İŞLEMLERİ
; ══════════════════════════════════════════

CreateStartMenuShortcut(targetPath := "") {
    if (targetPath = "")
        targetPath := A_ScriptFullPath
    startMenuPath := A_Programs "\CopilotButton.lnk"
    try {
        iconPath := A_ScriptDir "\logo.ico"
        if FileExist(iconPath)
            FileCreateShortcut(targetPath, startMenuPath, A_ScriptDir, , "CopilotButton Media & Mic Control", iconPath)
        else
            FileCreateShortcut(targetPath, startMenuPath, A_ScriptDir, , "CopilotButton Media & Mic Control")
    }
}

RemoveStartMenuShortcut() {
    startMenuPath := A_Programs "\CopilotButton.lnk"
    if FileExist(startMenuPath)
        try FileDelete(startMenuPath)
}

; ══════════════════════════════════════════
;  TEMA VE GÖRÜNÜM YARDIMCILARI
; ══════════════════════════════════════════
GetEffectiveTheme() {
    global themeMode
    if (themeMode = "Dark")
        return "Dark"
    if (themeMode = "Light")
        return "Light"

    ; "Auto" — Windows Sistem temasını oku
    try {
        appsUseLight := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
            "AppsUseLightTheme")
        if (appsUseLight == 0)
            return "Dark"
        else
            return "Light"
    } catch {
        return "Dark"
    }
}

SetWindowDarkMode(hWnd, isDark := true) {
    val := isDark ? 1 : 0
    ; 20 = DWMWA_USE_IMMERSIVE_DARK_MODE (Windows 10 20H1+ ve Windows 11)
    ; 19 = DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1 (Eski Win10)
    if DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "UInt", 20, "Int*", &val, "UInt", 4)
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "UInt", 19, "Int*", &val, "UInt", 4)
}

ApplyThemeToControls(guiObj, isDark) {
    themeName := isDark ? "DarkMode_Explorer" : "Explorer"
    for _, ctrl in guiObj {
        try DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", themeName, "Str", "")
    }
}

; ══════════════════════════════════════════
;  EYLEM İSİMLERİ VE GÖRÜNTÜLEME EŞLEMELERİ
; ══════════════════════════════════════════
global actionKeys := ["MicMute", "PlayPause", "NextTrack", "PrevTrack", "VolumeUp", "VolumeDown", "MasterMute",
    "ToggleDeafen", "VoiceTyping", "Screenshot", "TaskView", "LockScreen", "CustomMacro", "None"]

global actionDisplayMap := Map(
    "MicMute", "🎙️  Mikrofonu Sustur / Aç",
    "PlayPause", "⏯️  Oynat / Duraklat",
    "NextTrack", "⏭️  Sonraki Şarkı",
    "PrevTrack", "⏮️  Önceki Şarkı",
    "VolumeUp", "🔊  Ses Düzeyini Artır",
    "VolumeDown", "🔉  Ses Düzeyini Azalt",
    "MasterMute", "🔇  Genel Sesi Kapat (Mute)",
    "ToggleDeafen", "🔕  Sağırlaştır (Kulaklık & Mic)",
    "VoiceTyping", "🗣️  Windows Sesle Yazma",
    "Screenshot", "📸  Ekran Alıntısı Aracı",
    "TaskView", "🗂️  Görev Görünümü (Win+Tab)",
    "LockScreen", "🔒  Ekranı Kilitle",
    "CustomMacro", "🎹  Özel Tuş Makrosu",
    "None", "⛔  Hiçbir Şey Yapma"
)

GetActionDisplay(key) {
    global actionDisplayMap
    return actionDisplayMap.Has(key) ? actionDisplayMap[key] : actionDisplayMap["None"]
}

GetActionKey(displayStr) {
    global actionDisplayMap
    for k, v in actionDisplayMap {
        if (v = displayStr)
            return k
    }
    return "None"
}

; ══════════════════════════════════════════
;  GÖRSEL AYARLAR PENCERESİ (AHK GUI — MODERN BLUE FLUENT DESIGN)
; ══════════════════════════════════════════
ShowSettingsGUI(*) {
    global settingsGui, configFile, doubleTapThreshold, holdThreshold, musicApp, autoStart, ytmUrl, ytmTitle,
        spotifyCmd, spotifyTitle, osdPosition, osdColor, osdFontSize, osdDurationMs, osdFadeEnabled, holdAction,
        action1, action2, action3, action4, trayIconMicState, customAppPath, themeMode, soundFxEnabled,
        telemetryEnabled, actionKeys, actionDisplayMap, tipGui, APP_VERSION, micDevice,
        customMacro1, customMacro2, customMacro3, customMacro4, customMacroHold

    if (IsObject(settingsGui)) {
        settingsGui.Show()
        return
    }

    isDark := (GetEffectiveTheme() = "Dark")

    ; ═════════════════════════════════════════════════════════════
    ;  MODERN FLUENT PALETTE
    ; ═════════════════════════════════════════════════════════════
    if (isDark) {
        bgColor := "0B0F16"
        sidebarBg := "101722"
        cardBgColor := "151D2A"
        cardAltBg := "111925"
        textColor := "F5F7FA"
        subTextColor := "A8B4C5"
        dimTextColor := "708096"
        accentBlue := "1683E6"
        accentHover := "2494F2"
        darkBlueBtn := "125FA8"
        navInactiveBg := "151F2D"
        navInactiveTxt := "9DB5D0"
        editBgColor := "101824"
        borderClr := "263347"
        successColor := "35C98A"
        warningColor := "F4B942"
    } else {
        bgColor := "F4F7FB"
        sidebarBg := "EAF0F7"
        cardBgColor := "FFFFFF"
        cardAltBg := "F8FAFD"
        textColor := "172033"
        subTextColor := "52627A"
        dimTextColor := "7B899E"
        accentBlue := "0878D1"
        accentHover := "0A86E7"
        darkBlueBtn := "1769A8"
        navInactiveBg := "E2EAF3"
        navInactiveTxt := "29435F"
        editBgColor := "FFFFFF"
        borderClr := "CCD6E3"
        successColor := "128A5A"
        warningColor := "A96800"
    }

    editOpt := "Background" editBgColor " c" textColor

    ; 900x680: içerik için daha fazla nefes alanı
    settingsGui := Gui("+AlwaysOnTop +Owner -MinimizeBox", "Copilot Button — Ayarlar")
    settingsGui.BackColor := bgColor
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")

    ; Windows 11 title bar / rounded corners
    SetWindowDarkMode(settingsGui.Hwnd, isDark)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", settingsGui.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)

    ; ═════════════════════════════════════════════════════════════
    ;  BUTTON / PAGE HELPERS
    ; ═════════════════════════════════════════════════════════════
    buttonHwnds := Map()
    RegBtn(ctrl) => (buttonHwnds[ctrl.Hwnd] := true, ctrl)

    page1 := []
    page2 := []
    page3 := []
    page4 := []
    page5 := []

    AddP1(ctrl) => (page1.Push(ctrl), ctrl)
    AddP2(ctrl) => (page2.Push(ctrl), ctrl)
    AddP3(ctrl) => (page3.Push(ctrl), ctrl)
    AddP4(ctrl) => (page4.Push(ctrl), ctrl)
    AddP5(ctrl) => (page5.Push(ctrl), ctrl)

    ; ═════════════════════════════════════════════════════════════
    ;  HEADER
    ; ═════════════════════════════════════════════════════════════
    iconPath := A_ScriptDir "\logo.ico"
    if FileExist(iconPath)
        settingsGui.Add("Picture", "x22 y18 w34 h34", iconPath)

    settingsGui.SetFont("s14 bold c" textColor, "Segoe UI")
    settingsGui.Add("Text", "x68 y15 w360 h27", "Copilot Button")

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    settingsGui.Add("Text", "x69 y43 w430 h18", "Donanım tuşu • Medya • Mikrofon • Kısayollar")

    ; Sağ üst durum rozeti
    settingsGui.SetFont("s8.5 bold c" successColor, "Segoe UI")
    settingsGui.Add("Text", "x690 y22 w185 h22 Right", "●  AKTİF   v" APP_VERSION)

    settingsGui.Add("Text", "x0 y70 w900 h1 Background" borderClr)

    ; ═════════════════════════════════════════════════════════════
    ;  SIDEBAR
    ; ═════════════════════════════════════════════════════════════
    settingsGui.Add("Text", "x0 y71 w220 h539 Background" sidebarBg)

    settingsGui.SetFont("s8 bold c" dimTextColor, "Segoe UI")
    settingsGui.Add("Text", "x20 y91 w180 h18", "AYARLAR")

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnNav1 := RegBtn(settingsGui.Add("Text", "x14 y115 w192 h44 Background" accentBlue " cFFFFFF Center 0x200",
        "⚡  Tıklama Eylemleri"))
    btnNav2 := RegBtn(settingsGui.Add("Text", "x14 y165 w192 h44 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "⏱  Zamanlama & Sistem"))
    btnNav3 := RegBtn(settingsGui.Add("Text", "x14 y215 w192 h44 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "🎨  OSD & Görünüm"))
    btnNav4 := RegBtn(settingsGui.Add("Text", "x14 y265 w192 h44 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "🎵  Medya & Bas-Konuş"))
    btnNav5 := RegBtn(settingsGui.Add("Text", "x14 y315 w192 h44 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "ℹ  Hakkında & Bakım"))

    navButtons := [btnNav1, btnNav2, btnNav3, btnNav4, btnNav5]
    navLabels := [
        "⚡  Tıklama Eylemleri",
        "⏱  Zamanlama & Sistem",
        "🎨  OSD & Görünüm",
        "🎵  Medya & Bas-Konuş",
        "ℹ  Hakkında & Bakım"
    ]

    ; Sidebar bilgi kartı
    settingsGui.Add("GroupBox", "x14 y382 w192 h205", "Hızlı Bilgi")
    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    settingsGui.Add("Text", "x27 y408 w166 h165",
        "Copilot tuşu için farklı basma`n"
        . "senaryoları atayabilirsiniz.`n`n"
        . "• 1 Tık → Mikrofon`n"
        . "• 2 Tık → Medya`n"
        . "• 3 / 4 Tık → Kısayol`n"
        . "• Basılı Tutma → Uygulama`n"
        . "  veya özel makro`n`n"
        . "Değişiklikler yalnızca`n"
        . "Kaydet & Uygula ile kalıcı olur."
    )

    ; İçerik alanı ayırıcı
    settingsGui.Add("Text", "x220 y71 w1 h539 Background" borderClr)

    ; ═════════════════════════════════════════════════════════════
    ;  PAGE 1 — CLICK ACTIONS
    ; ═════════════════════════════════════════════════════════════
    settingsGui.SetFont("s12 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x248 y91 w625 h28", "Tıklama Eylemleri"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x248 y120 w625 h18",
        "Copilot tuşuna kaç kez basıldığına göre çalıştırılacak işlevleri belirleyin."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("GroupBox", "x248 y151 w625 h374", "Tuş Atamaları"))

    actionDisplayList := []
    for k in actionKeys
        actionDisplayList.Push(actionDisplayMap[k])

    ; Row helper
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x268 y181 w150 h22", "1 Tık"))
    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x268 y201 w150 h18", "Tek basım"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct1 := AddP1(settingsGui.Add("DropDownList", "x430 y177 w443 r12 " editOpt, actionDisplayList))
    ddlAct1.Text := GetActionDisplay(action1)

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x268 y249 w150 h22", "2 Tık"))
    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x268 y269 w150 h18", "Çift basım"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct2 := AddP1(settingsGui.Add("DropDownList", "x430 y245 w443 r12 " editOpt, actionDisplayList))
    ddlAct2.Text := GetActionDisplay(action2)

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x268 y317 w150 h22", "3 Tık"))
    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x268 y337 w150 h18", "Üç basım"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct3 := AddP1(settingsGui.Add("DropDownList", "x430 y313 w443 r12 " editOpt, actionDisplayList))
    ddlAct3.Text := GetActionDisplay(action3)

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x268 y385 w150 h22", "4 Tık"))
    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x268 y405 w150 h18", "Dört basım"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct4 := AddP1(settingsGui.Add("DropDownList", "x430 y381 w443 r12 " editOpt, actionDisplayList))
    ddlAct4.Text := GetActionDisplay(action4)

    ; Dynamic macro editors — intentionally below each row
    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    lblMacro1 := AddP1(settingsGui.Add("Text", "x430 y207 w95 h18 Hidden", "Makro:"))
    edtMacro1 := AddP1(settingsGui.Add("Edit", "x475 y204 w295 h24 Hidden " editOpt, customMacro1))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnRec1 := RegBtn(AddP1(settingsGui.Add("Text", "x776 y204 w97 h24 Hidden Background" darkBlueBtn " cFFFFFF Center 0x200",
        "⏺  Kaydet")))
    btnRec1.OnEvent("Click", (*) => OpenMacroRecorder(1, edtMacro1, settingsGui))

    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    lblMacro2 := AddP1(settingsGui.Add("Text", "x430 y275 w95 h18 Hidden", "Makro:"))
    edtMacro2 := AddP1(settingsGui.Add("Edit", "x475 y272 w295 h24 Hidden " editOpt, customMacro2))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnRec2 := RegBtn(AddP1(settingsGui.Add("Text", "x776 y272 w97 h24 Hidden Background" darkBlueBtn " cFFFFFF Center 0x200",
        "⏺  Kaydet")))
    btnRec2.OnEvent("Click", (*) => OpenMacroRecorder(2, edtMacro2, settingsGui))

    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    lblMacro3 := AddP1(settingsGui.Add("Text", "x430 y343 w95 h18 Hidden", "Makro:"))
    edtMacro3 := AddP1(settingsGui.Add("Edit", "x475 y340 w295 h24 Hidden " editOpt, customMacro3))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnRec3 := RegBtn(AddP1(settingsGui.Add("Text", "x776 y340 w97 h24 Hidden Background" darkBlueBtn " cFFFFFF Center 0x200",
        "⏺  Kaydet")))
    btnRec3.OnEvent("Click", (*) => OpenMacroRecorder(3, edtMacro3, settingsGui))

    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    lblMacro4 := AddP1(settingsGui.Add("Text", "x430 y411 w95 h18 Hidden", "Makro:"))
    edtMacro4 := AddP1(settingsGui.Add("Edit", "x475 y408 w295 h24 Hidden " editOpt, customMacro4))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnRec4 := RegBtn(AddP1(settingsGui.Add("Text", "x776 y408 w97 h24 Hidden Background" darkBlueBtn " cFFFFFF Center 0x200",
        "⏺  Kaydet")))
    btnRec4.OnEvent("Click", (*) => OpenMacroRecorder(4, edtMacro4, settingsGui))

    UpdateMacroVisibility(ddl, lblMacro, edtMacro, btnRec) {
        isMacro := (GetActionKey(ddl.Text) = "CustomMacro")
        lblMacro.Visible := isMacro
        edtMacro.Visible := isMacro
        btnRec.Visible := isMacro
    }

    UpdateMacroVisibility(ddlAct1, lblMacro1, edtMacro1, btnRec1)
    UpdateMacroVisibility(ddlAct2, lblMacro2, edtMacro2, btnRec2)
    UpdateMacroVisibility(ddlAct3, lblMacro3, edtMacro3, btnRec3)
    UpdateMacroVisibility(ddlAct4, lblMacro4, edtMacro4, btnRec4)

    ddlAct1.OnEvent("Change", (*) => UpdateMacroVisibility(ddlAct1, lblMacro1, edtMacro1, btnRec1))
    ddlAct2.OnEvent("Change", (*) => UpdateMacroVisibility(ddlAct2, lblMacro2, edtMacro2, btnRec2))
    ddlAct3.OnEvent("Change", (*) => UpdateMacroVisibility(ddlAct3, lblMacro3, edtMacro3, btnRec3))
    ddlAct4.OnEvent("Change", (*) => UpdateMacroVisibility(ddlAct4, lblMacro4, edtMacro4, btnRec4))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x268 y486 w585 h30",
        "Makro kullanmak için ilgili eylemden “Özel Tuş Makrosu” seçin. Ardından Kaydet ile tuş dizisini kaydedin."))

    ; ═════════════════════════════════════════════════════════════
    ;  PAGE 2 — TIMING / SYSTEM
    ; ═════════════════════════════════════════════════════════════
    settingsGui.SetFont("s12 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x248 y91 w625 h28", "Zamanlama & Sistem"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x248 y120 w625 h18",
        "Tıklama algılama hassasiyetini ve sistem davranışlarını ayarlayın."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("GroupBox", "x248 y151 w625 h230", "Algılama Eşik Süreleri"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x268 y183 w250 h22", "Çoklu Tık Bekleme Süresi"))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x268 y205 w250 h18", "İki tık arasındaki maksimum süre (ms)"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtDoubleTap := AddP2(settingsGui.Add("Edit", "x535 y179 w78 h26 Number " editOpt, doubleTapThreshold))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnDT150 := RegBtn(AddP2(settingsGui.Add("Text", "x622 y179 w65 h26 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "150 ms")))
    btnDT250 := RegBtn(AddP2(settingsGui.Add("Text", "x693 y179 w65 h26 Background" accentBlue " cFFFFFF Center 0x200",
        "250 ms")))
    btnDT350 := RegBtn(AddP2(settingsGui.Add("Text", "x764 y179 w65 h26 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "350 ms")))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x268 y253 w250 h22", "Basılı Tutma Eşik Süresi"))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x268 y275 w250 h18", "Basılı tutma eyleminin tetiklenme süresi"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtHold := AddP2(settingsGui.Add("Edit", "x535 y249 w78 h26 Number " editOpt, holdThreshold))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnHold200 := RegBtn(AddP2(settingsGui.Add("Text", "x622 y249 w65 h26 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "200 ms")))
    btnHold250 := RegBtn(AddP2(settingsGui.Add("Text", "x693 y249 w65 h26 Background" accentBlue " cFFFFFF Center 0x200",
        "250 ms")))
    btnHold400 := RegBtn(AddP2(settingsGui.Add("Text", "x764 y249 w65 h26 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "400 ms")))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x268 y319 w560 h18",
        "Öneri: çoğu kullanıcı için 250 ms iyi bir başlangıç noktasıdır."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("GroupBox", "x248 y396 w625 h78", "Mikrofon Cihazı"))

    captureDevices := EnumerateCaptureDevices()
    micDeviceList := ["🔄  Otomatik Algıla"]
    for _, devName in captureDevices
        micDeviceList.Push(devName)

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x268 y425 w130 h22", "Kullanılacak cihaz:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlMicDevice := AddP2(settingsGui.Add("DropDownList", "x405 y421 w448 r8 " editOpt, micDeviceList))

    if (micDevice = "Auto" || micDevice = "")
        ddlMicDevice.Text := "🔄  Otomatik Algıla"
    else
        try ddlMicDevice.Text := micDevice

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("GroupBox", "x248 y489 w625 h101", "Sistem & Geri Bildirim"))

    chkTrayMic := AddP2(settingsGui.Add("Checkbox", "x268 y514 w570 h22 Checked" (trayIconMicState ? "1" : "0"),
    "🎙  Mikrofon durumuna göre görev çubuğu simgesini değiştir"))
    chkSoundFx := AddP2(settingsGui.Add("Checkbox", "x268 y540 w570 h22 Checked" (soundFxEnabled ? "1" : "0"),
    "🔊  Mikrofon açma / kapamada hafif ses efekti çal"))
    chkTelemetry := AddP2(settingsGui.Add("Checkbox", "x268 y566 w570 h22 Checked" (telemetryEnabled ? "1" : "0"),
    "📊  Anonim açılış telemetrisi ve kullanım loglarını gönder"))

    ; ═════════════════════════════════════════════════════════════
    ;  PAGE 3 — OSD / APPEARANCE
    ; ═════════════════════════════════════════════════════════════
    settingsGui.SetFont("s12 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x248 y91 w625 h28", "OSD & Görünüm"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x248 y120 w625 h18",
        "Ekran üstü bildirimlerin konumunu, rengini ve tipografisini özelleştirin."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("GroupBox", "x248 y151 w625 h145", "Tema & Konum"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x268 y184 w130 h22", "Arayüz Teması"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlTheme := AddP3(settingsGui.Add("DropDownList", "x405 y180 w170 r7 " editOpt, ["Dark", "Light", "Auto"]))
    ddlTheme.Text := themeMode
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x590 y184 w240 h20", "Dark / Light / Windows"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x268 y230 w130 h22", "OSD Konumu"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlPos := AddP3(settingsGui.Add("DropDownList", "x405 y226 w170 r7 " editOpt,
        ["TopLeft", "TopRight", "BottomLeft", "BottomRight", "Center"]))
    ddlPos.Text := osdPosition
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x590 y230 w240 h20", "Bildirim ekran üzerindeki konumu"))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("GroupBox", "x248 y313 w625 h277", "OSD Biçimlendirme & Önizleme"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x268 y346 w130 h22", "Metin Rengi"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtOsdColor := AddP3(settingsGui.Add("Edit", "x405 y342 w88 h26 " editOpt, osdColor))

    settingsGui.SetFont("s9 cFFFFFF", "Segoe UI")
    btnClr1 := RegBtn(AddP3(settingsGui.Add("Text", "x502 y342 w43 h26 Background1C283C Center 0x200", "🟦")))
    btnClr2 := RegBtn(AddP3(settingsGui.Add("Text", "x549 y342 w43 h26 Background1C283C Center 0x200", "🟩")))
    btnClr3 := RegBtn(AddP3(settingsGui.Add("Text", "x596 y342 w43 h26 Background1C283C Center 0x200", "🟪")))
    btnClr4 := RegBtn(AddP3(settingsGui.Add("Text", "x643 y342 w43 h26 Background1C283C Center 0x200", "🟧")))
    btnClr5 := RegBtn(AddP3(settingsGui.Add("Text", "x690 y342 w43 h26 Background1C283C Center 0x200", "🟥")))
    btnClr6 := RegBtn(AddP3(settingsGui.Add("Text", "x737 y342 w43 h26 Background1C283C Center 0x200", "⬜")))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x268 y390 w130 h22", "Font Boyutu"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtOsdSize := AddP3(settingsGui.Add("Edit", "x405 y386 w88 h26 Number " editOpt, osdFontSize))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x502 y390 w310 h20", "pt  •  Önerilen: 9–14"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x268 y434 w130 h22", "Gösterim Süresi"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtOsdDur := AddP3(settingsGui.Add("Edit", "x405 y430 w88 h26 Number " editOpt, osdDurationMs))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x502 y434 w310 h20", "ms  •  Önerilen: 1500"))

    chkFade := AddP3(settingsGui.Add("Checkbox", "x268 y478 w560 h22 Checked" (osdFadeEnabled ? "1" : "0"),
    "✨  Yumuşak Fade-in / Fade-out animasyonu kullan"))

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnTestOsd := RegBtn(AddP3(settingsGui.Add("Text", "x268 y520 w560 h38 Background" accentBlue " cFFFFFF Center 0x200",
        "👁  OSD Bildirimini Şimdi Önizle")))

    ; ═════════════════════════════════════════════════════════════
    ;  PAGE 4 — MEDIA / HOLD
    ; ═════════════════════════════════════════════════════════════
    settingsGui.SetFont("s12 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x248 y91 w625 h28", "Medya & Basılı Tutma"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x248 y120 w625 h18",
        "Müzik oynatıcınızı ve Copilot tuşuna basılı tutulduğunda çalışacak eylemi ayarlayın."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("GroupBox", "x248 y151 w625 h183", "Hedef Müzik Oynatıcı"))

    radSpotify := AddP4(settingsGui.Add("Radio", "x268 y180 w145 h22 Checked" (musicApp = "Spotify" ? "1" : "0"),
    " Spotify"))
    radYtm := AddP4(settingsGui.Add("Radio", "x430 y180 w170 h22 Checked" (musicApp = "YTM" ? "1" : "0"),
    " YouTube Music"))

    settingsGui.SetFont("s8.5 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x268 y215 w95 h20", "Spotify Komut"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    edtSpotCmd := AddP4(settingsGui.Add("Edit", "x370 y211 w503 h24 " editOpt, spotifyCmd))

    settingsGui.SetFont("s8.5 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x268 y249 w95 h20", "Spotify Başlık"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    edtSpotTitle := AddP4(settingsGui.Add("Edit", "x370 y245 w503 h24 " editOpt, spotifyTitle))

    settingsGui.SetFont("s8.5 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x268 y283 w95 h20", "YTM URL"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    edtYtmUrl := AddP4(settingsGui.Add("Edit", "x370 y279 w503 h24 " editOpt, ytmUrl))

    settingsGui.SetFont("s8.5 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x268 y317 w95 h20", "YTM Başlık"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    edtYtmTitle := AddP4(settingsGui.Add("Edit", "x370 y313 w503 h24 " editOpt, ytmTitle))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("GroupBox", "x248 y352 w625 h238", "Basılı Tutma Eylemi"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x268 y382 w150 h22", "Basılı Tutma Modu"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlHold := AddP4(settingsGui.Add("DropDownList", "x430 y378 w443 r8 " editOpt,
        ["MusicApp", "PushToTalk", "CustomApp", "CustomMacro"]))
    ddlHold.Text := holdAction

    ; CustomApp
    settingsGui.SetFont("s8.5 bold c" textColor, "Segoe UI")
    lblCustomApp := AddP4(settingsGui.Add("Text", "x268 y418 w585 h20",
        "Özel Uygulama Yolu veya Web URL"))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x268 y438 w585 h18",
        "Program, .lnk veya web adresi girin."))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtCustomApp := AddP4(settingsGui.Add("Edit", "x268 y461 w350 h27 " editOpt, customAppPath))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnPickApp := RegBtn(AddP4(settingsGui.Add("Text", "x626 y461 w117 h27 Background" accentBlue " cFFFFFF Center 0x200",
        "🚀 Uygulama Seç")))
    btnBrowse := RegBtn(AddP4(settingsGui.Add("Text", "x749 y461 w124 h27 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "📁 Dosya Seç")))

    ; CustomMacro
    settingsGui.SetFont("s8.5 bold c" textColor, "Segoe UI")
    lblHoldMacro := AddP4(settingsGui.Add("Text", "x268 y418 w585 h20 Hidden",
        "Basılı Tutma Makro Dizisi"))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x268 y438 w585 h18 Hidden",
        "Örn: ^c = Ctrl+C, !{F4} = Alt+F4, #+s = Win+Shift+S"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtHoldMacro := AddP4(settingsGui.Add("Edit", "x268 y461 w455 h27 Hidden " editOpt, customMacroHold))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnRecHold := RegBtn(AddP4(settingsGui.Add("Text", "x733 y461 w140 h27 Hidden Background" darkBlueBtn " cFFFFFF Center 0x200",
        "⏺  Makro Kaydet")))
    btnRecHold.OnEvent("Click", (*) => OpenMacroRecorder(0, edtHoldMacro, settingsGui))

    UpdateHoldVisibility(*) {
        mode := ddlHold.Text
        isCustomApp := (mode = "CustomApp")
        isCustomMacro := (mode = "CustomMacro")

        lblCustomApp.Visible := isCustomApp
        edtCustomApp.Visible := isCustomApp
        btnPickApp.Visible := isCustomApp
        btnBrowse.Visible := isCustomApp

        lblHoldMacro.Visible := isCustomMacro
        edtHoldMacro.Visible := isCustomMacro
        btnRecHold.Visible := isCustomMacro
    }

    UpdateHoldVisibility()
    ddlHold.OnEvent("Change", UpdateHoldVisibility)

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x268 y505 w585 h72",
        "MusicApp: Spotify veya YouTube Music'i açar / öne getirir.`n"
        . "PushToTalk: Tuş basılıyken mikrofonu açar, bırakınca susturur.`n"
        . "CustomApp: Belirlediğiniz programı veya web sayfasını açar.`n"
        . "CustomMacro: Kaydettiğiniz makro dizisini gönderir."
    ))

    ; ═════════════════════════════════════════════════════════════
    ;  PAGE 5 — ABOUT / MAINTENANCE
    ; ═════════════════════════════════════════════════════════════
    settingsGui.SetFont("s12 bold c" textColor, "Segoe UI")
    AddP5(settingsGui.Add("Text", "x248 y91 w625 h28", "Hakkında & Bakım"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP5(settingsGui.Add("Text", "x248 y120 w625 h18",
        "Uygulama sürümü, proje bilgileri ve bakım araçları."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP5(settingsGui.Add("GroupBox", "x248 y151 w625 h190", "Copilot Button Controller"))

    if FileExist(iconPath)
        AddP5(settingsGui.Add("Picture", "x268 y181 w42 h42", iconPath))

    settingsGui.SetFont("s11 bold c" textColor, "Segoe UI")
    AddP5(settingsGui.Add("Text", "x325 y180 w520 h25", "Copilot Button Controller"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP5(settingsGui.Add("Text", "x325 y207 w520 h44",
        "Windows Copilot donanım tuşunu medya, mikrofon ve üretkenlik"
        . "`n" . "kısayolları için özelleştirilebilir bir kontrol tuşuna dönüştürür."
    ))

    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    AddP5(settingsGui.Add("Text", "x268 y270 w570 h20", "Sürüm:  v" APP_VERSION))
    AddP5(settingsGui.Add("Text", "x268 y294 w570 h20", "Geliştirici:  Kerem Kuyucu"))
    AddP5(settingsGui.Add("Text", "x268 y318 w570 h20", "Altyapı:  AutoHotkey v2 Native Architecture"))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP5(settingsGui.Add("GroupBox", "x248 y360 w625 h108", "Bakım Araçları"))

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnCheckUpdate := RegBtn(AddP5(settingsGui.Add("Text", "x268 y392 w290 h42 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "🔄  Güncellemeleri Denetle")))
    btnReloadScript := RegBtn(AddP5(settingsGui.Add("Text", "x570 y392 w283 h42 Background" accentBlue " cFFFFFF Center 0x200",
        "↻  Uygulamayı Yeniden Başlat")))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP5(settingsGui.Add("Text", "x268 y482 w585 h55",
        "Proje açık kaynak olarak GitHub üzerinde yayınlanmaktadır.`n"
        . "https://github.com/KeremKuyucu/copilot-button"
    ))

    ; ═════════════════════════════════════════════════════════════
    ;  FOOTER
    ; ═════════════════════════════════════════════════════════════
    settingsGui.Add("Text", "x0 y610 w900 h1 Background" borderClr)
    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    settingsGui.Add("Text", "x20 y631 w430 h22",
        "Değişiklikleri kaydetmek için “Kaydet & Uygula” seçeneğini kullanın.")

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnCancel := RegBtn(settingsGui.Add("Text", "x610 y624 w120 h38 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "✕  İptal"))
    btnCancel.OnEvent("Click", (*) => CleanAndClose())

    btnSave := RegBtn(settingsGui.Add("Text", "x742 y624 w135 h38 Background" accentBlue " cFFFFFF Center 0x200",
        "✓  Kaydet & Uygula"))
    btnSave.OnEvent("Click", (*) => SaveAndReload())

    ; ═════════════════════════════════════════════════════════════
    ;  TAB / INTERACTION MANAGEMENT
    ; ═════════════════════════════════════════════════════════════
    SwitchTab(tabIndex) {
        pageLists := [page1, page2, page3, page4, page5]

        for idx, ctrlList in pageLists {
            isCurrent := (idx = tabIndex)
            for _, ctrl in ctrlList
                ctrl.Visible := isCurrent
        }

        ; Dynamic controls must be re-applied after page visibility changes.
        if (tabIndex = 1) {
            UpdateMacroVisibility(ddlAct1, lblMacro1, edtMacro1, btnRec1)
            UpdateMacroVisibility(ddlAct2, lblMacro2, edtMacro2, btnRec2)
            UpdateMacroVisibility(ddlAct3, lblMacro3, edtMacro3, btnRec3)
            UpdateMacroVisibility(ddlAct4, lblMacro4, edtMacro4, btnRec4)
        } else if (tabIndex = 4) {
            UpdateHoldVisibility()
        }

        for idx, btn in navButtons {
            if (idx = tabIndex) {
                btn.Opt("Background" accentBlue " cFFFFFF")
                btn.Text := "●  " navLabels[idx]
                btn.SetFont("s9 bold cFFFFFF")
            } else {
                btn.Opt("Background" navInactiveBg " c" navInactiveTxt)
                btn.Text := "    " navLabels[idx]
                btn.SetFont("s9 bold c" navInactiveTxt)
            }
            btn.Redraw()
        }
    }

    btnNav1.OnEvent("Click", (*) => SwitchTab(1))
    btnNav2.OnEvent("Click", (*) => SwitchTab(2))
    btnNav3.OnEvent("Click", (*) => SwitchTab(3))
    btnNav4.OnEvent("Click", (*) => SwitchTab(4))
    btnNav5.OnEvent("Click", (*) => SwitchTab(5))

    ; Page 2 presets
    btnDT150.OnEvent("Click", (*) => (edtDoubleTap.Value := "150"))
    btnDT250.OnEvent("Click", (*) => (edtDoubleTap.Value := "250"))
    btnDT350.OnEvent("Click", (*) => (edtDoubleTap.Value := "350"))

    btnHold200.OnEvent("Click", (*) => (edtHold.Value := "200"))
    btnHold250.OnEvent("Click", (*) => (edtHold.Value := "250"))
    btnHold400.OnEvent("Click", (*) => (edtHold.Value := "400"))

    ; Page 3 color presets
    btnClr1.OnEvent("Click", (*) => (edtOsdColor.Value := "00E5FF"))
    btnClr2.OnEvent("Click", (*) => (edtOsdColor.Value := "00E676"))
    btnClr3.OnEvent("Click", (*) => (edtOsdColor.Value := "B388FF"))
    btnClr4.OnEvent("Click", (*) => (edtOsdColor.Value := "FFB300"))
    btnClr5.OnEvent("Click", (*) => (edtOsdColor.Value := "FF5252"))
    btnClr6.OnEvent("Click", (*) => (edtOsdColor.Value := "FFFFFF"))

    btnTestOsd.OnEvent("Click", ShowTestOsd)

    ; Page 4 / 5
    btnPickApp.OnEvent("Click", (*) => OpenAppPicker(edtCustomApp, settingsGui))
    btnBrowse.OnEvent("Click", (*) => BrowseCustomApp(edtCustomApp))
    btnCheckUpdate.OnEvent("Click", (*) => CheckForUpdates(false))
    btnReloadScript.OnEvent("Click", (*) => Reload())

    ; ═════════════════════════════════════════════════════════════
    ;  HOVER CURSOR
    ; ═════════════════════════════════════════════════════════════
    GuiMouseMove(wParam, lParam, msg, hwnd) {
        if (buttonHwnds.Has(hwnd))
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))
    }
    OnMessage(0x0200, GuiMouseMove)

    CleanAndClose() {
        try OnMessage(0x0200, GuiMouseMove, 0)
        try CloseAppPicker()

        if (IsObject(settingsGui)) {
            settingsGui.Destroy()
            settingsGui := 0
        }
    }

    settingsGui.OnEvent("Close", (*) => CleanAndClose())
    settingsGui.OnEvent("Escape", (*) => CleanAndClose())

    ApplyThemeToControls(settingsGui, isDark)

    ; Başlangıç sayfası
    SwitchTab(1)

    settingsGui.Show("w900 h680")

    ; ═════════════════════════════════════════════════════════════
    ;  INTERNAL HELPERS
    ; ═════════════════════════════════════════════════════════════
    BrowseCustomApp(editCtrl) {
        selectedFile := FileSelect(3, , "Çalıştırılacak Uygulama veya Dosyayı Seçin",
            "Programlar (*.exe; *.bat; *.cmd; *.lnk; *.vbs; *.ps1; *.*)")
        if (selectedFile != "")
            editCtrl.Value := selectedFile
    }

    ShowTestOsd(*) {
        testColor := Trim(edtOsdColor.Value)
        if (testColor = "")
            testColor := "00E5FF"

        testSize := Integer(edtOsdSize.Value)
        testDur := Integer(edtOsdDur.Value)
        testFade := chkFade.Value
        testPos := ddlPos.Text

        oldColor := osdColor
        oldSize := osdFontSize
        oldDur := osdDurationMs
        oldFade := osdFadeEnabled
        oldPos := osdPosition

        osdColor := testColor
        osdFontSize := testSize
        osdDurationMs := testDur
        osdFadeEnabled := testFade
        osdPosition := testPos

        if (IsObject(tipGui)) {
            try tipGui.Destroy()
            tipGui := 0
        }

        ShowTip("✨ Copilot Tuşu OSD Önizleme ✨`nKonum: " testPos " | Renk: #" testColor, testDur)

        osdColor := oldColor
        osdFontSize := oldSize
        osdDurationMs := oldDur
        osdFadeEnabled := oldFade
        osdPosition := oldPos
    }

    SaveAndReload() {
        newApp := radSpotify.Value ? "Spotify" : "YTM"
        newDouble := Integer(edtDoubleTap.Value)
        newHold := Integer(edtHold.Value)
        newYtmUrl := Trim(edtYtmUrl.Value)
        newYtmTitle := Trim(edtYtmTitle.Value)
        newSpotCmd := Trim(edtSpotCmd.Value)
        newSpotTitle := Trim(edtSpotTitle.Value)

        newTheme := ddlTheme.Text
        newOsdPos := ddlPos.Text
        newOsdColor := Trim(edtOsdColor.Value)
        newOsdSize := Integer(edtOsdSize.Value)
        newOsdDur := Integer(edtOsdDur.Value)
        newFade := chkFade.Value ? 1 : 0

        if (newDouble < 100 || newDouble > 1000) {
            MsgBox("Tıklama bekleme süresi 100 ms ile 1000 ms arasında olmalıdır.", "Hata", "Icon!")
            return
        }

        if (newHold < 100 || newHold > 2000) {
            MsgBox("Basılı tutma süresi 100 ms ile 2000 ms arasında olmalıdır.", "Hata", "Icon!")
            return
        }

        if (newOsdSize < 6 || newOsdSize > 48) {
            MsgBox("Font boyutu 6 ile 48 arasında olmalıdır.", "Hata", "Icon!")
            return
        }

        if (newOsdDur < 300 || newOsdDur > 10000) {
            MsgBox("OSD gösterim süresi 300 ms ile 10000 ms arasında olmalıdır.", "Hata", "Icon!")
            return
        }

        IniWrite(newApp, configFile, "Settings", "MusicApp")
        IniWrite(newDouble, configFile, "Settings", "DoubleTapMs")
        IniWrite(newHold, configFile, "Settings", "HoldMs")
        IniWrite(newYtmUrl, configFile, "Settings", "YtmURL")
        IniWrite(newYtmTitle, configFile, "Settings", "YtmWindowTitle")
        IniWrite(newSpotCmd, configFile, "Settings", "SpotifyCmd")
        IniWrite(newSpotTitle, configFile, "Settings", "SpotifyWindowTitle")

        IniWrite(newTheme, configFile, "Settings", "Theme")
        IniWrite(newOsdPos, configFile, "Settings", "OsdPosition")
        IniWrite(newOsdColor, configFile, "Settings", "OsdColor")
        IniWrite(newOsdSize, configFile, "Settings", "OsdFontSize")
        IniWrite(newOsdDur, configFile, "Settings", "OsdDurationMs")
        IniWrite(newFade, configFile, "Settings", "OsdFadeEnabled")

        IniWrite(ddlHold.Text, configFile, "Settings", "HoldAction")
        IniWrite(Trim(edtCustomApp.Value), configFile, "Settings", "CustomAppPath")
        IniWrite(Trim(edtHoldMacro.Value), configFile, "Settings", "CustomMacroHold")
        IniWrite(chkTrayMic.Value ? 1 : 0, configFile, "Settings", "TrayIconMicState")
        IniWrite(chkSoundFx.Value ? 1 : 0, configFile, "Settings", "SoundFxEnabled")
        IniWrite(chkTelemetry.Value ? 1 : 0, configFile, "Settings", "TelemetryEnabled")

        IniWrite(GetActionKey(ddlAct1.Text), configFile, "Settings", "Action1")
        IniWrite(GetActionKey(ddlAct2.Text), configFile, "Settings", "Action2")
        IniWrite(GetActionKey(ddlAct3.Text), configFile, "Settings", "Action3")
        IniWrite(GetActionKey(ddlAct4.Text), configFile, "Settings", "Action4")

        IniWrite(Trim(edtMacro1.Value), configFile, "Settings", "CustomMacro1")
        IniWrite(Trim(edtMacro2.Value), configFile, "Settings", "CustomMacro2")
        IniWrite(Trim(edtMacro3.Value), configFile, "Settings", "CustomMacro3")
        IniWrite(Trim(edtMacro4.Value), configFile, "Settings", "CustomMacro4")

        selectedMic := ddlMicDevice.Text
        if (selectedMic = "🔄  Otomatik Algıla")
            IniWrite("Auto", configFile, "Settings", "MicDevice")
        else
            IniWrite(selectedMic, configFile, "Settings", "MicDevice")

        settingsGui.Destroy()
        settingsGui := 0
        ShowTip("✅ Ayarlar kaydedildi! Yenileniyor...")
        Sleep 500
        Reload()
    }
}
