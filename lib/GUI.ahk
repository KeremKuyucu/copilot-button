; ══════════════════════════════════════════
;  GUI, AYARLAR PANELİ & TEMA MODÜLÜ
; ══════════════════════════════════════════

; ══════════════════════════════════════════
;  BAŞLANGIÇ KAYIT DEFTERİ (REGISTRY) İŞLEMLERİ
; ══════════════════════════════════════════
SetAutoStartRegistry(enable) {
    regKey := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
    regName := "CopilotButton"
    exePath := A_IsCompiled ? A_ScriptFullPath : '"' . A_AhkPath . '" "' . A_ScriptFullPath . '"'
    if (enable) {
        try RegWrite('"' . exePath . '"', "REG_SZ", regKey, regName)
    } else {
        try RegDelete(regKey, regName)
    }
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
global actionKeys := ["MicMute", "PlayPause", "NextTrack", "PrevTrack", "MasterMute",
    "ToggleDeafen", "LockScreen", "None"]

global actionDisplayMap := Map(
    "MicMute", "🎙️  Mikrofonu Sustur / Aç",
    "PlayPause", "⏯️  Oynat / Duraklat",
    "NextTrack", "⏭️  Sonraki Şarkı",
    "PrevTrack", "⏮️  Önceki Şarkı",
    "MasterMute", "🔇  Genel Sesi Kapat (Mute)",
    "ToggleDeafen", "🔕  Sağırlaştır (Kulaklık & Mic)",
    "LockScreen", "🔒  Ekranı Kilitle",
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
    global settingsGui, configFile, doubleTapThreshold, holdThreshold, autoStart,
        spotifyCmd, spotifyTitle, spotifyTrackOsdEnabled, osdPosition, osdColor, osdFontSize, osdDurationMs, osdFadeEnabled, holdAction,
        action1, action2, action3, action4, customAppPath, themeMode, soundFxEnabled,
        telemetryEnabled, actionKeys, actionDisplayMap, tipGui, APP_VERSION, micDevice

    if (IsObject(settingsGui)) {
        settingsGui.Show()
        return
    }

    isDark := (GetEffectiveTheme() = "Dark")

    ; ═════════════════════════════════════════════════════════════
    ;  MODERN FLUENT RENK PALETİ
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
    }

    editOpt := "Background" editBgColor " c" textColor

    ; Standart pencere: AlwaysOnTop yok, gezgin ve pencereler arkasında kalmaz
    settingsGui := Gui("-MinimizeBox", "Copilot Button — Ayarlar")
    settingsGui.BackColor := bgColor
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")

    ; Windows 11 title bar / rounded corners
    SetWindowDarkMode(settingsGui.Hwnd, isDark)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", settingsGui.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)

    ; ═════════════════════════════════════════════════════════════
    ;  BUTTON / PAGE DİZİLERİ (3 SEKME)
    ; ═════════════════════════════════════════════════════════════
    buttonHwnds := Map()
    RegBtn(ctrl) => (buttonHwnds[ctrl.Hwnd] := true, ctrl)

    page1 := []
    page2 := []
    page3 := []

    AddP1(ctrl) => (page1.Push(ctrl), ctrl)
    AddP2(ctrl) => (page2.Push(ctrl), ctrl)
    AddP3(ctrl) => (page3.Push(ctrl), ctrl)

    ; ═════════════════════════════════════════════════════════════
    ;  ÜST BAŞLIK (HEADER)
    ; ═════════════════════════════════════════════════════════════
    iconPath := FileExist(A_ScriptDir "\assets\logo.ico") ? A_ScriptDir "\assets\logo.ico" : A_ScriptDir "\logo.ico"
    if FileExist(iconPath)
        settingsGui.Add("Picture", "x22 y12 w32 h32", iconPath)

    settingsGui.SetFont("s13 bold c" textColor, "Segoe UI")
    settingsGui.Add("Text", "x64 y10 w350 h24", "Copilot Button")

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    settingsGui.Add("Text", "x65 y34 w430 h18", "Donanım tuşu • Medya • Mikrofon • Kısayollar")

    ; Sağ üst durum rozeti
    settingsGui.SetFont("s8.5 bold c" successColor, "Segoe UI")
    settingsGui.Add("Text", "x660 y17 w185 h22 Right", "●  AKTİF   v" APP_VERSION)

    settingsGui.Add("Text", "x0 y56 w860 h1 Background" borderClr)

    ; ═════════════════════════════════════════════════════════════
    ;  SOL MENÜ (SIDEBAR — 3 SEKME)
    ; ═════════════════════════════════════════════════════════════
    settingsGui.Add("Text", "x0 y57 w210 h413 Background" sidebarBg)

    settingsGui.SetFont("s8 bold c" dimTextColor, "Segoe UI")
    settingsGui.Add("Text", "x20 y72 w170 h18", "AYARLAR")

    navLabels := [
        "⚡  Tuşlar / Eylemler",
        "🎨  OSD / Görünüm",
        "ℹ️  Sistem / Hakkında"
    ]

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnNav1 := RegBtn(settingsGui.Add("Text", "x15 y96 w180 h38 Background" accentBlue " cFFFFFF Center 0x200",
        navLabels[1]))
    btnNav2 := RegBtn(settingsGui.Add("Text", "x15 y142 w180 h38 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        navLabels[2]))
    btnNav3 := RegBtn(settingsGui.Add("Text", "x15 y188 w180 h38 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        navLabels[3]))

    navButtons := [btnNav1, btnNav2, btnNav3]

    ; Sidebar bilgi kartı
    settingsGui.Add("GroupBox", "x15 y240 w180 h215", "Hızlı Bilgi")
    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    settingsGui.Add("Text", "x24 y262 w162 h185",
        "Copilot tuşu için farklı basma`n"
        . "senaryoları atayabilirsiniz.`n`n"
        . "• 1-4 Tık → Eylemler`n"
        . "• Basılı Tutma → Bas-Konuş`n"
        . "  veya Hazır Şablon / URL`n`n"
        . "Değişiklikler Kaydet & Uygula`n"
        . "ile geçerli olur."
    )

    ; Dikey sınır çizgisi
    settingsGui.Add("Text", "x210 y57 w1 h413 Background" borderClr)

    ; ═════════════════════════════════════════════════════════════
    ;  PAGE 1 — TUŞLAR / EYLEMLER
    ; ═════════════════════════════════════════════════════════════
    settingsGui.SetFont("s12 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x230 y65 w615 h22", "Tuşlar / Eylemler"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x230 y87 w615 h16",
        "Copilot tuşuna basılma sayısına ve basılı tutmaya göre eylemleri belirleyin."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("GroupBox", "x230 y105 w615 h168", "Tıklama Eylemleri (1 - 4 Tık)"))

    actionDisplayList := []
    for k in actionKeys
        actionDisplayList.Push(actionDisplayMap[k])

    ; Row 1
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x245 y124 w45 h22", "1 Tık"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct1 := AddP1(settingsGui.Add("DropDownList", "x295 y120 w535 r10 " editOpt, actionDisplayList))
    ddlAct1.Text := GetActionDisplay(action1)

    ; Row 2
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x245 y154 w45 h22", "2 Tık"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct2 := AddP1(settingsGui.Add("DropDownList", "x295 y150 w535 r10 " editOpt, actionDisplayList))
    ddlAct2.Text := GetActionDisplay(action2)

    ; Row 3
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x245 y184 w45 h22", "3 Tık"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct3 := AddP1(settingsGui.Add("DropDownList", "x295 y180 w535 r10 " editOpt, actionDisplayList))
    ddlAct3.Text := GetActionDisplay(action3)

    ; Row 4
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x245 y214 w45 h22", "4 Tık"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct4 := AddP1(settingsGui.Add("DropDownList", "x295 y210 w535 r10 " editOpt, actionDisplayList))
    ddlAct4.Text := GetActionDisplay(action4)

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x245 y246 w585 h18",
        "• Her tıklama sayısı için ayrı bir eylem belirleyebilirsiniz."))

    ; ── BASILI TUTMA EYLEMİ ──
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("GroupBox", "x230 y279 w615 h112", "Basılı Tutma Eylemi"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x245 y300 w125 h20", "Basılı Tutma Modu:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlHold := AddP1(settingsGui.Add("DropDownList", "x375 y296 w160 r3 " editOpt,
        ["PushToTalk", "CustomApp"]))
    if (holdAction != "CustomApp")
        holdAction := "PushToTalk"
    ddlHold.Text := holdAction

    ; Hazır Şablonlar Seçici (Spotify, Gemini)
    ddlPreset := AddP1(settingsGui.Add("DropDownList", "x550 y296 w280 r4 Hidden " editOpt,
        ["⚡ Hazır Şablon Seç...", "Spotify", "Gemini"]))
    ddlPreset.Choose(1)

    ; Bilgi notu (PushToTalk seçiliyken)
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    lblHoldInfo := AddP1(settingsGui.Add("Text", "x245 y333 w585 h20",
        "🎙️ Tuş basılı tutulduğunda mikrofonu açar, bırakınca susturur (Bas-Konuş)."))

    ; CustomApp kontrolleri (CustomApp seçiliyken serbest link/exe yazma)
    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    lblCustomApp := AddP1(settingsGui.Add("Text", "x245 y333 w65 h20 Hidden", "Yol / URL:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtCustomApp := AddP1(settingsGui.Add("Edit", "x315 y329 w435 h26 Hidden " editOpt, customAppPath))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnBrowse := RegBtn(AddP1(settingsGui.Add("Text", "x758 y329 w72 h26 Hidden Background" darkBlueBtn " cFFFFFF Center 0x200",
        "📁 Gözat")))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    lblCustomHelp := AddP1(settingsGui.Add("Text", "x245 y363 w585 h18 Hidden",
        "İster .exe yolu, ister web linki (https://...), ister spotify: gibi protokol yazabilirsiniz."))

    OnPresetChange(*) {
        sel := ddlPreset.Text
        if (sel = "Spotify")
            edtCustomApp.Value := "spotify:"
        else if (sel = "Gemini")
            edtCustomApp.Value := EnvGet("LOCALAPPDATA") "\Google\Gemini\Gemini.exe"
    }
    ddlPreset.OnEvent("Change", OnPresetChange)

    ; ── MİKROFON CİHAZI SEÇİMİ (Şarta Bağlı: Sadece Mikrofon Özelliği Varsa Gösterilir) ──
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    grpMic := AddP1(settingsGui.Add("GroupBox", "x230 y397 w615 h64", "Mikrofon Cihazı"))

    captureDevices := EnumerateCaptureDevices()
    micDeviceList := ["🔄  Otomatik Algıla"]
    for _, devName in captureDevices
        micDeviceList.Push(devName)

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    lblMic := AddP1(settingsGui.Add("Text", "x245 y421 w115 h20", "Mikrofon Cihazı:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlMicDevice := AddP1(settingsGui.Add("DropDownList", "x365 y417 w465 r8 " editOpt, micDeviceList))
    if (micDevice = "Auto" || micDevice = "")
        ddlMicDevice.Text := "🔄  Otomatik Algıla"
    else
        try ddlMicDevice.Text := micDevice

    UpdateMicVisibility(*) {
        hasMic := (GetActionKey(ddlAct1.Text) = "MicMute" || GetActionKey(ddlAct1.Text) = "ToggleDeafen"
                || GetActionKey(ddlAct2.Text) = "MicMute" || GetActionKey(ddlAct2.Text) = "ToggleDeafen"
                || GetActionKey(ddlAct3.Text) = "MicMute" || GetActionKey(ddlAct3.Text) = "ToggleDeafen"
                || GetActionKey(ddlAct4.Text) = "MicMute" || GetActionKey(ddlAct4.Text) = "ToggleDeafen"
                || ddlHold.Text = "PushToTalk")
        grpMic.Visible := hasMic
        lblMic.Visible := hasMic
        ddlMicDevice.Visible := hasMic
    }

    UpdateHoldVisibility(*) {
        isCustomApp := (ddlHold.Text = "CustomApp")
        lblHoldInfo.Visible := !isCustomApp
        ddlPreset.Visible := isCustomApp
        lblCustomApp.Visible := isCustomApp
        edtCustomApp.Visible := isCustomApp
        btnBrowse.Visible := isCustomApp
        lblCustomHelp.Visible := isCustomApp
        UpdateMicVisibility()
    }

    UpdateAllActionVisibilities() {
        UpdateHoldVisibility()
        UpdateMicVisibility()
    }

    ddlAct1.OnEvent("Change", UpdateMicVisibility)
    ddlAct2.OnEvent("Change", UpdateMicVisibility)
    ddlAct3.OnEvent("Change", UpdateMicVisibility)
    ddlAct4.OnEvent("Change", UpdateMicVisibility)
    ddlHold.OnEvent("Change", UpdateHoldVisibility)

    UpdateAllActionVisibilities()

    ; ═════════════════════════════════════════════════════════════
    ;  PAGE 2 — OSD / GÖRÜNÜM
    ; ═════════════════════════════════════════════════════════════
    settingsGui.SetFont("s12 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x230 y68 w615 h24", "OSD / Görünüm"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x230 y92 w615 h16",
        "Ekran üstü bildirimlerin konumunu, temasını ve renklerini özelleştirin."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("GroupBox", "x230 y112 w615 h84", "Tema / Bildirim Konumu"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x245 y134 w100 h20", "Arayüz Teması:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlTheme := AddP2(settingsGui.Add("DropDownList", "x350 y130 w120 r7 " editOpt, ["Dark", "Light", "Auto"]))
    ddlTheme.Text := themeMode

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x495 y134 w95 h20", "OSD Konumu:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlPos := AddP2(settingsGui.Add("DropDownList", "x595 y130 w150 r7 " editOpt,
        ["TopLeft", "TopRight", "BottomLeft", "BottomRight", "Center"]))
    ddlPos.Text := osdPosition

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x245 y168 w585 h18", "Koyu/Açık tema ve ekran üzerindeki bildirim pozisyonu."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("GroupBox", "x230 y202 w615 h262", "OSD Biçimlendirme & Önizleme"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x245 y226 w85 h20", "Metin Rengi:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtOsdColor := AddP2(settingsGui.Add("Edit", "x335 y222 w75 h24 " editOpt, osdColor))

    ; Gerçek renk dolgulu palet kutuları (emoji yerine net renkli butonlar)
    settingsGui.SetFont("s8 bold c000000", "Segoe UI")
    btnClr1 := RegBtn(AddP2(settingsGui.Add("Text", "x418 y222 w32 h24 Background00E5FF Center 0x200", "")))
    btnClr2 := RegBtn(AddP2(settingsGui.Add("Text", "x456 y222 w32 h24 Background00E676 Center 0x200", "")))
    btnClr3 := RegBtn(AddP2(settingsGui.Add("Text", "x494 y222 w32 h24 BackgroundB388FF Center 0x200", "")))
    btnClr4 := RegBtn(AddP2(settingsGui.Add("Text", "x532 y222 w32 h24 BackgroundFFB300 Center 0x200", "")))
    btnClr5 := RegBtn(AddP2(settingsGui.Add("Text", "x570 y222 w32 h24 BackgroundFF5252 Center 0x200", "")))
    btnClr6 := RegBtn(AddP2(settingsGui.Add("Text", "x608 y222 w32 h24 BackgroundFFFFFF Center 0x200", "●")))

    ; Canlı renk önizleme kutusu
    boxPreview := AddP2(settingsGui.Add("Text", "x648 y222 w36 h24 Background" osdColor " Center 0x200", ""))

    UpdateColorPreview(colorHex) {
        colorHex := Trim(colorHex)
        if (RegExMatch(colorHex, "^[0-9a-fA-F]{6}$")) {
            try boxPreview.Opt("Background" colorHex)
        }
    }
    edtOsdColor.OnEvent("Change", (*) => UpdateColorPreview(edtOsdColor.Value))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x245 y262 w85 h20", "Font Boyutu:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtOsdSize := AddP2(settingsGui.Add("Edit", "x335 y258 w75 h24 Number " editOpt, osdFontSize))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x418 y262 w110 h20", "pt (Örn: 9-14)"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x535 y262 w75 h20", "Süre (ms):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtOsdDur := AddP2(settingsGui.Add("Edit", "x615 y258 w75 h24 Number " editOpt, osdDurationMs))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x698 y262 w80 h20", "ms (1500)"))

    chkFade := AddP2(settingsGui.Add("Checkbox", "x245 y296 w570 h20 Checked" (osdFadeEnabled ? "1" : "0"),
        "✨  Yumuşak Fade-in / Fade-out animasyonu kullan"))

    chkSpotifyOsd := AddP2(settingsGui.Add("Checkbox", "x245 y322 w570 h20 Checked" (spotifyTrackOsdEnabled ? "1" : "0"),
        "🎵  Spotify şarkı değişiminde estetik OSD bildirimi göster"))

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnTestOsd := RegBtn(AddP2(settingsGui.Add("Text", "x245 y350 w585 h34 Background" accentBlue " cFFFFFF Center 0x200",
        "👁  OSD Bildirimini Şimdi Önizle")))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x245 y392 w585 h36",
        "OSD ekran bildirimleri mikrofon veya Spotify parça değiştiğinde belirir.`n"
        . "Yukarıdaki renk kutularına tıklayarak paletten doğrudan renk seçebilirsiniz."))

    ; ═════════════════════════════════════════════════════════════
    ;  PAGE 3 — SİSTEM / HAKKINDA
    ; ═════════════════════════════════════════════════════════════
    settingsGui.SetFont("s12 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x230 y68 w615 h24", "Sistem / Hakkında"))
    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x230 y92 w615 h16",
        "Sistem tercihleri, geri bildirimler ve uygulama bilgileri."))

    ; Sistem & Geri Bildirim
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("GroupBox", "x230 y112 w615 h118", "Sistem / Geri Bildirim"))

    chkAutoStart := AddP3(settingsGui.Add("Checkbox", "x245 y134 w275 h22 Checked" (autoStart ? "1" : "0"),
        "🚀  Windows ile otomatik başlat"))
    chkSoundFx := AddP3(settingsGui.Add("Checkbox", "x535 y134 w295 h22 Checked" (soundFxEnabled ? "1" : "0"),
        "🔊  Susturma / açma ses efekti"))
    chkTelemetry := AddP3(settingsGui.Add("Checkbox", "x245 y164 w275 h22 Checked" (telemetryEnabled ? "1" : "0"),
        "📊  Anonim kullanım telemetrisi"))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x245 y196 w585 h18",
        "Seçenekler 'Kaydet & Uygula' butonuna tıklandığında hemen devreye girer."))

    ; Hakkında Kartı
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("GroupBox", "x230 y236 w615 h136", "Copilot Button Controller"))

    if FileExist(iconPath)
        AddP3(settingsGui.Add("Picture", "x248 y256 w36 h36", iconPath))

    settingsGui.SetFont("s11 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x295 y254 w530 h22", "Copilot Button Controller"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x295 y276 w530 h18",
        "Windows Copilot tuşu medya, mikrofon ve üretkenlik kontrol merkezi."))

    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x248 y300 w260 h18", "Sürüm:  v" APP_VERSION))
    AddP3(settingsGui.Add("Text", "x520 y300 w300 h18", "Geliştirici:  Kerem Kuyucu"))
    AddP3(settingsGui.Add("Text", "x248 y320 w260 h18", "Altyapı:  AutoHotkey v2 Native"))
    AddP3(settingsGui.Add("Text", "x520 y320 w300 h18", "Lisans:  Açık Kaynak (GPL)"))
    AddP3(settingsGui.Add("Text", "x248 y340 w570 h18", "GitHub:  https://github.com/KeremKuyucu/copilot-button"))

    ; Bakım & Araçlar
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("GroupBox", "x230 y380 w615 h82", "Bakım / Yönetim Araçları"))

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnCheckUpdate := RegBtn(AddP3(settingsGui.Add("Text", "x248 y404 w280 h36 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "🔄  Güncellemeleri Denetle")))
    btnReloadScript := RegBtn(AddP3(settingsGui.Add("Text", "x540 y404 w280 h36 Background" accentBlue " cFFFFFF Center 0x200",
        "↻  Uygulamayı Yeniden Başlat")))

    ; ═════════════════════════════════════════════════════════════
    ;  ALT BİLGİ & BUTONLAR (FOOTER)
    ; ═════════════════════════════════════════════════════════════
    settingsGui.Add("Text", "x0 y470 w860 h1 Background" borderClr)
    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    settingsGui.Add("Text", "x20 y486 w420 h22",
        "Değişiklikleri kaydetmek için “Kaydet & Uygula” seçeneğini kullanın.")

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnCancel := RegBtn(settingsGui.Add("Text", "x580 y480 w120 h36 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "✕  İptal"))
    btnCancel.OnEvent("Click", (*) => CleanAndClose())

    btnSave := RegBtn(settingsGui.Add("Text", "x710 y480 w135 h36 Background" accentBlue " cFFFFFF Center 0x200",
        "✓  Kaydet & Uygula"))
    btnSave.OnEvent("Click", (*) => SaveAndReload())

    ; ═════════════════════════════════════════════════════════════
    ;  SEKME DEĞİŞTİRME MANTIĞI
    ; ═════════════════════════════════════════════════════════════
    SwitchTab(tabIndex) {
        pageLists := [page1, page2, page3]

        for idx, ctrlList in pageLists {
            isCurrent := (idx = tabIndex)
            for _, ctrl in ctrlList
                ctrl.Visible := isCurrent
        }

        if (tabIndex = 1) {
            UpdateAllActionVisibilities()
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

    ; Renk paleti buton tıklamaları
    btnClr1.OnEvent("Click", (*) => (edtOsdColor.Value := "00E5FF", UpdateColorPreview("00E5FF")))
    btnClr2.OnEvent("Click", (*) => (edtOsdColor.Value := "00E676", UpdateColorPreview("00E676")))
    btnClr3.OnEvent("Click", (*) => (edtOsdColor.Value := "B388FF", UpdateColorPreview("B388FF")))
    btnClr4.OnEvent("Click", (*) => (edtOsdColor.Value := "FFB300", UpdateColorPreview("FFB300")))
    btnClr5.OnEvent("Click", (*) => (edtOsdColor.Value := "FF5252", UpdateColorPreview("FF5252")))
    btnClr6.OnEvent("Click", (*) => (edtOsdColor.Value := "FFFFFF", UpdateColorPreview("FFFFFF")))

    btnTestOsd.OnEvent("Click", ShowTestOsd)

    ; Özel Uygulama & Sistem Butonları
    btnBrowse.OnEvent("Click", (*) => BrowseCustomApp(edtCustomApp))
    btnCheckUpdate.OnEvent("Click", (*) => CheckForUpdates(false))
    btnReloadScript.OnEvent("Click", (*) => Reload())

    ; ═════════════════════════════════════════════════════════════
    ;  FARE İMLECİ ETKİLEŞİMİ (HOVER)
    ; ═════════════════════════════════════════════════════════════
    GuiMouseMove(wParam, lParam, msg, hwnd) {
        if (buttonHwnds.Has(hwnd))
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))
    }
    OnMessage(0x0200, GuiMouseMove)

    CleanAndClose() {
        try OnMessage(0x0200, GuiMouseMove, 0)

        if (IsObject(settingsGui)) {
            settingsGui.Destroy()
            settingsGui := 0
        }
    }

    settingsGui.OnEvent("Close", (*) => CleanAndClose())
    settingsGui.OnEvent("Escape", (*) => CleanAndClose())

    ApplyThemeToControls(settingsGui, isDark)

    ; Başlangıç sekmesi
    SwitchTab(1)

    settingsGui.Show("w860 h530")

    ; ═════════════════════════════════════════════════════════════
    ;  YARDIMCI FONKSİYONLAR
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

        SetTimer(() => (
            osdColor := oldColor,
            osdFontSize := oldSize,
            osdDurationMs := oldDur,
            osdFadeEnabled := oldFade,
            osdPosition := oldPos
        ), -(testDur + 500))
    }

    SaveAndReload() {
        newSpotCmd := spotifyCmd
        newSpotTitle := spotifyTitle

        newTheme := ddlTheme.Text
        newOsdPos := ddlPos.Text
        newOsdColor := Trim(edtOsdColor.Value)
        newOsdSize := Integer(edtOsdSize.Value)
        newOsdDur := Integer(edtOsdDur.Value)
        newFade := chkFade.Value ? 1 : 0
        newSpotifyOsd := chkSpotifyOsd.Value ? 1 : 0

        if (newOsdSize < 6 || newOsdSize > 48) {
            MsgBox("Font boyutu 6 ile 48 arasında olmalıdır.", "Hata", "Icon!")
            return
        }

        if (newOsdDur < 300 || newOsdDur > 10000) {
            MsgBox("OSD gösterim süresi 300 ms ile 10000 ms arasında olmalıdır.", "Hata", "Icon!")
            return
        }

        IniWrite("Spotify", configFile, "Settings", "MusicApp")
        ; Zamanlama değerleri config.ini'de sabit korunur (UI'dan kaldırılmıştır)
        IniWrite(doubleTapThreshold, configFile, "Settings", "DoubleTapMs")
        IniWrite(holdThreshold, configFile, "Settings", "HoldMs")
        IniWrite(newSpotCmd, configFile, "Settings", "SpotifyCmd")
        IniWrite(newSpotTitle, configFile, "Settings", "SpotifyWindowTitle")
        IniWrite(newSpotifyOsd, configFile, "Settings", "SpotifyTrackOsd")

        IniWrite(newTheme, configFile, "Settings", "Theme")
        IniWrite(newOsdPos, configFile, "Settings", "OsdPosition")
        IniWrite(newOsdColor, configFile, "Settings", "OsdColor")
        IniWrite(newOsdSize, configFile, "Settings", "OsdFontSize")
        IniWrite(newOsdDur, configFile, "Settings", "OsdDurationMs")
        IniWrite(newFade, configFile, "Settings", "OsdFadeEnabled")

        IniWrite(ddlHold.Text, configFile, "Settings", "HoldAction")
        IniWrite(Trim(edtCustomApp.Value), configFile, "Settings", "CustomAppPath")
        newAutoStart := chkAutoStart.Value ? 1 : 0
        IniWrite(newAutoStart, configFile, "Settings", "AutoStart")
        SetAutoStartRegistry(newAutoStart)
        IniWrite(chkSoundFx.Value ? 1 : 0, configFile, "Settings", "SoundFxEnabled")
        IniWrite(chkTelemetry.Value ? 1 : 0, configFile, "Settings", "TelemetryEnabled")

        IniWrite(GetActionKey(ddlAct1.Text), configFile, "Settings", "Action1")
        IniWrite(GetActionKey(ddlAct2.Text), configFile, "Settings", "Action2")
        IniWrite(GetActionKey(ddlAct3.Text), configFile, "Settings", "Action3")
        IniWrite(GetActionKey(ddlAct4.Text), configFile, "Settings", "Action4")

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
