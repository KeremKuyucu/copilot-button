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
global actionKeys := ["MicMute", "PlayPause", "NextTrack", "PrevTrack", "VolumeUp", "VolumeDown", "MasterMute",
    "ToggleDeafen", "VoiceTyping", "Screenshot", "TaskView", "LockScreen", "CommandPalette", "CustomMacro", "TextTemplate", "None"]

global actionDisplayMap := Map(
    "MicMute", "🎙️  Mikrofonu Sustur / Aç",
    "PlayPause", "⏯️  Oynat / Duraklat",
    "NextTrack", "⏭️  Sonraki Şarkı",
    "PrevTrack", "⏮️  Önceki Şarkı",
    "VolumeUp", "🔊  Ses Artır (OSD Çubuk)",
    "VolumeDown", "🔉  Ses Azalt (OSD Çubuk)",
    "MasterMute", "🔇  Genel Sesi Kapat (Mute)",
    "ToggleDeafen", "🔕  Sağırlaştır (Kulaklık & Mic)",
    "VoiceTyping", "🗣️  Windows Sesle Yazma",
    "Screenshot", "📸  Ekran Alıntısı Aracı",
    "TaskView", "🗂️  Görev Görünümü (Win+Tab)",
    "LockScreen", "🔒  Ekranı Kilitle",
    "CommandPalette", "⚡  Hızlı Komut Paleti (Spotlight)",
    "CustomMacro", "🎹  Özel Tuş Makrosu",
    "TextTemplate", "📝  Metin Şablonu Yapıştır",
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
        customMacro1, customMacro2, customMacro3, customMacro4, customMacroHold,
        textTemplate1, textTemplate2, textTemplate3, textTemplate4

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

    AddP1(ctrl) => (page1.Push(ctrl), ctrl)
    AddP2(ctrl) => (page2.Push(ctrl), ctrl)
    AddP3(ctrl) => (page3.Push(ctrl), ctrl)
    AddP4(ctrl) => (page4.Push(ctrl), ctrl)

    ; ═════════════════════════════════════════════════════════════
    ; ═════════════════════════════════════════════════════════════
    ;  HEADER
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
    ;  SIDEBAR
    ; ═════════════════════════════════════════════════════════════
    settingsGui.Add("Text", "x0 y57 w210 h413 Background" sidebarBg)

    settingsGui.SetFont("s8 bold c" dimTextColor, "Segoe UI")
    settingsGui.Add("Text", "x20 y70 w170 h18", "AYARLAR")

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnNav1 := RegBtn(settingsGui.Add("Text", "x15 y92 w180 h36 Background" accentBlue " cFFFFFF Center 0x200",
        "⚡  Tıklama Eylemleri"))
    btnNav2 := RegBtn(settingsGui.Add("Text", "x15 y134 w180 h36 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "⏱  Zamanlama & Sistem"))
    btnNav3 := RegBtn(settingsGui.Add("Text", "x15 y176 w180 h36 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "🎨  OSD & Görünüm"))
    btnNav4 := RegBtn(settingsGui.Add("Text", "x15 y218 w180 h36 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "ℹ  Hakkında & Bakım"))

    navButtons := [btnNav1, btnNav2, btnNav3, btnNav4]
    navLabels := [
        "⚡  Tıklama Eylemleri",
        "⏱  Zamanlama & Sistem",
        "🎨  OSD & Görünüm",
        "ℹ  Hakkında & Bakım"
    ]

    ; Sidebar bilgi kartı
    settingsGui.Add("GroupBox", "x15 y265 w180 h195", "Hızlı Bilgi")
    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    settingsGui.Add("Text", "x24 y287 w162 h165",
        "Copilot tuşu için farklı basma`n"
        . "senaryoları atayabilirsiniz.`n`n"
        . "• 1-4 Tık → Eylem / Makro`n"
        . "• Basılı Tutma → Özel işlev`n`n"
        . "Değişiklikler Kaydet & Uygula`n"
        . "ile geçerli olur."
    )

    ; İçerik alanı ayırıcı
    settingsGui.Add("Text", "x210 y57 w1 h413 Background" borderClr)

    ; ═════════════════════════════════════════════════════════════
    ;  PAGE 1 — CLICK ACTIONS
    ; ═════════════════════════════════════════════════════════════
    settingsGui.SetFont("s12 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x230 y68 w615 h24", "Tıklama Eylemleri"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x230 y92 w615 h16",
        "Copilot tuşuna basılma sayısına ve basılı tutmaya göre eylemleri belirleyin."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("GroupBox", "x230 y112 w615 h192", "Tıklama Eylemleri (1 - 4 Tık)"))

    actionDisplayList := []
    for k in actionKeys
        actionDisplayList.Push(actionDisplayMap[k])

    ; Row 1
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x245 y138 w50 h24", "1 Tık"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct1 := AddP1(settingsGui.Add("DropDownList", "x300 y134 w240 r12 " editOpt, actionDisplayList))
    ddlAct1.Text := GetActionDisplay(action1)

    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    lblMacro1 := AddP1(settingsGui.Add("Text", "x550 y138 w42 h20 Hidden", "Makro:"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    edtMacro1 := AddP1(settingsGui.Add("Edit", "x595 y135 w180 h24 Hidden " editOpt,
        (action1 = "TextTemplate") ? textTemplate1 : customMacro1))
    settingsGui.SetFont("s8 bold cFFFFFF", "Segoe UI")
    btnRec1 := RegBtn(AddP1(settingsGui.Add("Text", "x780 y135 w55 h24 Hidden Background" darkBlueBtn " cFFFFFF Center 0x200",
        "⏺ Kayıt")))
    btnRec1.OnEvent("Click", (*) => OpenMacroRecorder(1, edtMacro1, settingsGui))

    ; Row 2
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x245 y174 w50 h24", "2 Tık"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct2 := AddP1(settingsGui.Add("DropDownList", "x300 y170 w240 r12 " editOpt, actionDisplayList))
    ddlAct2.Text := GetActionDisplay(action2)

    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    lblMacro2 := AddP1(settingsGui.Add("Text", "x550 y174 w42 h20 Hidden", "Makro:"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    edtMacro2 := AddP1(settingsGui.Add("Edit", "x595 y171 w180 h24 Hidden " editOpt,
        (action2 = "TextTemplate") ? textTemplate2 : customMacro2))
    settingsGui.SetFont("s8 bold cFFFFFF", "Segoe UI")
    btnRec2 := RegBtn(AddP1(settingsGui.Add("Text", "x780 y171 w55 h24 Hidden Background" darkBlueBtn " cFFFFFF Center 0x200",
        "⏺ Kayıt")))
    btnRec2.OnEvent("Click", (*) => OpenMacroRecorder(2, edtMacro2, settingsGui))

    ; Row 3
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x245 y210 w50 h24", "3 Tık"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct3 := AddP1(settingsGui.Add("DropDownList", "x300 y206 w240 r12 " editOpt, actionDisplayList))
    ddlAct3.Text := GetActionDisplay(action3)

    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    lblMacro3 := AddP1(settingsGui.Add("Text", "x550 y210 w42 h20 Hidden", "Makro:"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    edtMacro3 := AddP1(settingsGui.Add("Edit", "x595 y207 w180 h24 Hidden " editOpt,
        (action3 = "TextTemplate") ? textTemplate3 : customMacro3))
    settingsGui.SetFont("s8 bold cFFFFFF", "Segoe UI")
    btnRec3 := RegBtn(AddP1(settingsGui.Add("Text", "x780 y207 w55 h24 Hidden Background" darkBlueBtn " cFFFFFF Center 0x200",
        "⏺ Kayıt")))
    btnRec3.OnEvent("Click", (*) => OpenMacroRecorder(3, edtMacro3, settingsGui))

    ; Row 4
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x245 y246 w50 h24", "4 Tık"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct4 := AddP1(settingsGui.Add("DropDownList", "x300 y242 w240 r12 " editOpt, actionDisplayList))
    ddlAct4.Text := GetActionDisplay(action4)

    settingsGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    lblMacro4 := AddP1(settingsGui.Add("Text", "x550 y246 w42 h20 Hidden", "Makro:"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    edtMacro4 := AddP1(settingsGui.Add("Edit", "x595 y243 w180 h24 Hidden " editOpt,
        (action4 = "TextTemplate") ? textTemplate4 : customMacro4))
    settingsGui.SetFont("s8 bold cFFFFFF", "Segoe UI")
    btnRec4 := RegBtn(AddP1(settingsGui.Add("Text", "x780 y243 w55 h24 Hidden Background" darkBlueBtn " cFFFFFF Center 0x200",
        "⏺ Kayıt")))
    btnRec4.OnEvent("Click", (*) => OpenMacroRecorder(4, edtMacro4, settingsGui))

    UpdateMacroVisibility(ddl, lblMacro, edtMacro, btnRec) {
        actionKey := GetActionKey(ddl.Text)
        isMacro := (actionKey = "CustomMacro")
        isTmpl  := (actionKey = "TextTemplate")
        lblMacro.Text := isTmpl ? "Metin:" : "Makro:"
        lblMacro.Visible := (isMacro || isTmpl)
        edtMacro.Visible := (isMacro || isTmpl)
        btnRec.Visible   := isMacro
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
    AddP1(settingsGui.Add("Text", "x245 y278 w585 h18",
        "Özel Makro veya Metin Şablonu seçildiğinde kutucuk satırda görünür."))

    ; ── BASILI TUTMA EYLEMİ (Page 1 altı) ──
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("GroupBox", "x230 y312 w615 h152", "Basılı Tutma Eylemi"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x245 y334 w125 h20", "Basılı Tutma Modu:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlHold := AddP1(settingsGui.Add("DropDownList", "x375 y330 w240 r8 " editOpt,
        ["MusicApp", "PushToTalk", "CustomApp", "CustomMacro", "CommandPalette"]))
    ddlHold.Text := holdAction

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x625 y334 w205 h20", "Örn: Bas-konuş, spotlight"))

    ; Bilgi notu (MusicApp veya PushToTalk seçiliyken)
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    lblHoldInfo := AddP1(settingsGui.Add("Text", "x245 y370 w585 h20", ""))

    ; CustomApp
    edtCustomApp := AddP1(settingsGui.Add("Edit", "x245 y366 w390 h26 Hidden " editOpt, customAppPath))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnPickApp := RegBtn(AddP1(settingsGui.Add("Text", "x645 y366 w110 h26 Hidden Background" accentBlue " cFFFFFF Center 0x200",
        "🚀 Uygulama Seç")))
    btnBrowse := RegBtn(AddP1(settingsGui.Add("Text", "x760 y366 w75 h26 Hidden Background" darkBlueBtn " cFFFFFF Center 0x200",
        "📁 Gözat")))

    ; CustomMacro
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtHoldMacro := AddP1(settingsGui.Add("Edit", "x245 y366 w475 h26 Hidden " editOpt, customMacroHold))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnRecHold := RegBtn(AddP1(settingsGui.Add("Text", "x725 y366 w110 h26 Hidden Background" darkBlueBtn " cFFFFFF Center 0x200",
        "⏺ Makro Kaydet")))
    btnRecHold.OnEvent("Click", (*) => OpenMacroRecorder(0, edtHoldMacro, settingsGui))

    UpdateHoldVisibility(*) {
        mode := ddlHold.Text
        isCustomApp := (mode = "CustomApp")
        isCustomMacro := (mode = "CustomMacro")

        lblHoldInfo.Visible := (!isCustomApp && !isCustomMacro)
        if (mode = "MusicApp")
            lblHoldInfo.Text := "🎵 Spotify veya YouTube Music'i otomatik olarak açar veya öne getirir."
        else if (mode = "PushToTalk")
            lblHoldInfo.Text := "🎙 Tuş basılıyken mikrofonu açar, bırakınca susturur (Bas-Konuş)."
        else if (mode = "CommandPalette")
            lblHoldInfo.Text := "⚡ Raycast / Spotlight tarzı hızlı komut ve arama paletini açar."
        else
            lblHoldInfo.Text := ""

        edtCustomApp.Visible := isCustomApp
        btnPickApp.Visible := isCustomApp
        btnBrowse.Visible := isCustomApp

        edtHoldMacro.Visible := isCustomMacro
        btnRecHold.Visible := isCustomMacro
    }

    UpdateHoldVisibility()
    ddlHold.OnEvent("Change", UpdateHoldVisibility)

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x245 y405 w590 h48",
        "• MusicApp: Müzik çaları açar / öne getirir  • PushToTalk: Bas-konuş mikrofon`n"
        . "• CustomApp: Seçilen programı/URL açar  • CustomMacro: Özel tuş makrosu`n"
        . "• CommandPalette: Raycast tarzı akıllı komut ve hesaplama paleti"
    ))

    ; ═════════════════════════════════════════════════════════════
    ;  PAGE 2 — TIMING / SYSTEM
    ; ═════════════════════════════════════════════════════════════
    settingsGui.SetFont("s12 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x230 y68 w615 h24", "Zamanlama & Sistem"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x230 y92 w615 h16",
        "Tıklama algılama hassasiyetini, mikrofonu ve sistem davranışlarını ayarlayın."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("GroupBox", "x230 y112 w615 h112", "Algılama Eşik Süreleri"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x245 y134 w160 h20", "Çoklu Tık Bekleme:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtDoubleTap := AddP2(settingsGui.Add("Edit", "x410 y130 w65 h24 Number " editOpt, doubleTapThreshold))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnDT150 := RegBtn(AddP2(settingsGui.Add("Text", "x485 y130 w55 h24 Background" darkBlueBtn " cFFFFFF Center 0x200", "150 ms")))
    btnDT250 := RegBtn(AddP2(settingsGui.Add("Text", "x545 y130 w55 h24 Background" accentBlue " cFFFFFF Center 0x200", "250 ms")))
    btnDT350 := RegBtn(AddP2(settingsGui.Add("Text", "x605 y130 w55 h24 Background" darkBlueBtn " cFFFFFF Center 0x200", "350 ms")))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x670 y134 w160 h20", "Önerilen: 250 ms"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x245 y170 w160 h20", "Basılı Tutma Süresi:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtHold := AddP2(settingsGui.Add("Edit", "x410 y166 w65 h24 Number " editOpt, holdThreshold))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnHold200 := RegBtn(AddP2(settingsGui.Add("Text", "x485 y166 w55 h24 Background" darkBlueBtn " cFFFFFF Center 0x200", "200 ms")))
    btnHold250 := RegBtn(AddP2(settingsGui.Add("Text", "x545 y166 w55 h24 Background" accentBlue " cFFFFFF Center 0x200", "250 ms")))
    btnHold400 := RegBtn(AddP2(settingsGui.Add("Text", "x605 y166 w55 h24 Background" darkBlueBtn " cFFFFFF Center 0x200", "400 ms")))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x670 y170 w160 h20", "Önerilen: 250 ms"))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x245 y200 w585 h18",
        "İki tık arasındaki maksimum süre ve basılı tutma eşiğidir."))

    ; Mikrofon & Müzik
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("GroupBox", "x230 y230 w615 h96", "Mikrofon & Müzik Çalar"))

    captureDevices := EnumerateCaptureDevices()
    micDeviceList := ["🔄  Otomatik Algıla"]
    for _, devName in captureDevices
        micDeviceList.Push(devName)

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x245 y252 w115 h20", "Mikrofon Cihazı:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlMicDevice := AddP2(settingsGui.Add("DropDownList", "x365 y248 w465 r8 " editOpt, micDeviceList))
    if (micDevice = "Auto" || micDevice = "")
        ddlMicDevice.Text := "🔄  Otomatik Algıla"
    else
        try ddlMicDevice.Text := micDevice

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x245 y290 w115 h20", "Müzik Uygulaması:"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    radSpotify := AddP2(settingsGui.Add("Radio", "x365 y290 w120 h20 Checked" (musicApp = "Spotify" ? "1" : "0"), " Spotify"))
    radYtm := AddP2(settingsGui.Add("Radio", "x500 y290 w150 h20 Checked" (musicApp = "YTM" ? "1" : "0"), " YouTube Music"))

    ; Sistem & Geri Bildirim
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("GroupBox", "x230 y334 w615 h130", "Sistem & Geri Bildirim"))

    chkAutoStart := AddP2(settingsGui.Add("Checkbox", "x245 y356 w275 h22 Checked" (autoStart ? "1" : "0"),
        "🚀  Windows ile otomatik başlat"))
    chkTrayMic := AddP2(settingsGui.Add("Checkbox", "x535 y356 w295 h22 Checked" (trayIconMicState ? "1" : "0"),
        "🎙  Mikrofon simgesi göster"))
    chkSoundFx := AddP2(settingsGui.Add("Checkbox", "x245 y388 w275 h22 Checked" (soundFxEnabled ? "1" : "0"),
        "🔊  Susturma / açma ses efekti"))
    chkTelemetry := AddP2(settingsGui.Add("Checkbox", "x535 y388 w295 h22 Checked" (telemetryEnabled ? "1" : "0"),
        "📊  Anonim kullanım telemetrisi"))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x245 y424 w585 h20",
        "Seçenekler 'Kaydet & Uygula' butonuna tıklandığında hemen devreye girer."))

    ; ═════════════════════════════════════════════════════════════
    ;  PAGE 3 — OSD / APPEARANCE
    ; ═════════════════════════════════════════════════════════════
    settingsGui.SetFont("s12 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x230 y68 w615 h24", "OSD & Görünüm"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x230 y92 w615 h16",
        "Ekran üstü bildirimlerin konumunu, rengini ve tipografisini özelleştirin."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("GroupBox", "x230 y112 w615 h84", "Tema & Bildirim Konumu"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x245 y134 w100 h20", "Arayüz Teması:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlTheme := AddP3(settingsGui.Add("DropDownList", "x350 y130 w120 r7 " editOpt, ["Dark", "Light", "Auto"]))
    ddlTheme.Text := themeMode

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x495 y134 w95 h20", "OSD Konumu:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlPos := AddP3(settingsGui.Add("DropDownList", "x595 y130 w150 r7 " editOpt,
        ["TopLeft", "TopRight", "BottomLeft", "BottomRight", "Center"]))
    ddlPos.Text := osdPosition

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x245 y168 w585 h18", "Koyu/Açık tema ve ekran üzerindeki bildirim pozisyonu."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("GroupBox", "x230 y202 w615 h262", "OSD Biçimlendirme & Önizleme"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x245 y226 w85 h20", "Metin Rengi:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtOsdColor := AddP3(settingsGui.Add("Edit", "x335 y222 w75 h24 " editOpt, osdColor))

    settingsGui.SetFont("s9 cFFFFFF", "Segoe UI")
    btnClr1 := RegBtn(AddP3(settingsGui.Add("Text", "x418 y222 w36 h24 Background1C283C Center 0x200", "🟦")))
    btnClr2 := RegBtn(AddP3(settingsGui.Add("Text", "x458 y222 w36 h24 Background1C283C Center 0x200", "🟩")))
    btnClr3 := RegBtn(AddP3(settingsGui.Add("Text", "x498 y222 w36 h24 Background1C283C Center 0x200", "🟣")))
    btnClr4 := RegBtn(AddP3(settingsGui.Add("Text", "x538 y222 w36 h24 Background1C283C Center 0x200", "🟧")))
    btnClr5 := RegBtn(AddP3(settingsGui.Add("Text", "x578 y222 w36 h24 Background1C283C Center 0x200", "🟥")))
    btnClr6 := RegBtn(AddP3(settingsGui.Add("Text", "x618 y222 w36 h24 Background1C283C Center 0x200", "⬜")))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x245 y262 w85 h20", "Font Boyutu:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtOsdSize := AddP3(settingsGui.Add("Edit", "x335 y258 w75 h24 Number " editOpt, osdFontSize))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x418 y262 w110 h20", "pt (Örn: 9-14)"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x535 y262 w75 h20", "Süre (ms):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtOsdDur := AddP3(settingsGui.Add("Edit", "x615 y258 w75 h24 Number " editOpt, osdDurationMs))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x698 y262 w80 h20", "ms (1500)"))

    chkFade := AddP3(settingsGui.Add("Checkbox", "x245 y298 w570 h22 Checked" (osdFadeEnabled ? "1" : "0"),
        "✨  Yumuşak Fade-in / Fade-out animasyonu kullan"))

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnTestOsd := RegBtn(AddP3(settingsGui.Add("Text", "x245 y334 w585 h36 Background" accentBlue " cFFFFFF Center 0x200",
        "👁  OSD Bildirimini Şimdi Önizle")))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x245 y380 w585 h36",
        "OSD ekran bildirimleri mikrofon veya medya değiştiğinde belirir.`n"
        . "Yukarıdaki renk butonlarıyla hızlı palet seçimi yapabilirsiniz."))

    ; ═════════════════════════════════════════════════════════════
    ;  PAGE 4 — ABOUT / MAINTENANCE
    ; ═════════════════════════════════════════════════════════════
    settingsGui.SetFont("s12 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x230 y68 w615 h24", "Hakkında & Bakım"))
    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x230 y92 w615 h16",
        "Uygulama sürümü, proje bilgileri ve bakım araçları."))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("GroupBox", "x230 y112 w615 h180", "Copilot Button Controller"))

    if FileExist(iconPath)
        AddP4(settingsGui.Add("Picture", "x248 y135 w36 h36", iconPath))

    settingsGui.SetFont("s11 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x295 y133 w530 h22", "Copilot Button Controller"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x295 y158 w530 h34",
        "Windows Copilot donanım tuşunu medya, mikrofon ve üretkenlik"
        . "`n" . "kısayolları için özelleştirilebilir bir kontrol merkezine dönüştürür."
    ))

    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x248 y204 w260 h18", "Sürüm:  v" APP_VERSION))
    AddP4(settingsGui.Add("Text", "x520 y204 w300 h18", "Geliştirici:  Kerem Kuyucu"))
    AddP4(settingsGui.Add("Text", "x248 y226 w260 h18", "Altyapı:  AutoHotkey v2 Native"))
    AddP4(settingsGui.Add("Text", "x520 y226 w300 h18", "Lisans:  Açık Kaynak (MIT)"))
    AddP4(settingsGui.Add("Text", "x248 y248 w570 h18", "GitHub:  https://github.com/KeremKuyucu/copilot-button"))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("GroupBox", "x230 y300 w615 h164", "Bakım & Yönetim Araçları"))

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnCheckUpdate := RegBtn(AddP4(settingsGui.Add("Text", "x248 y326 w280 h38 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "🔄  Güncellemeleri Denetle")))
    btnReloadScript := RegBtn(AddP4(settingsGui.Add("Text", "x540 y326 w280 h38 Background" accentBlue " cFFFFFF Center 0x200",
        "↻  Uygulamayı Yeniden Başlat")))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x248 y376 w575 h40",
        "Ayarlar config.ini dosyasında saklanır.`n"
        . "Yeniden başlatma tüm klavye ve fare dinleyicilerini sıfırdan yükler."
    ))

    ; ═════════════════════════════════════════════════════════════
    ;  FOOTER
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
    ;  TAB / INTERACTION MANAGEMENT
    ; ═════════════════════════════════════════════════════════════
    SwitchTab(tabIndex) {
        pageLists := [page1, page2, page3, page4]

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

    ; Basılı tutma & Hakkında butonları
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

    settingsGui.Show("w860 h530")

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
        newYtmUrl := ytmUrl
        newYtmTitle := ytmTitle
        newSpotCmd := spotifyCmd
        newSpotTitle := spotifyTitle

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
        newAutoStart := chkAutoStart.Value ? 1 : 0
        IniWrite(newAutoStart, configFile, "Settings", "AutoStart")
        SetAutoStartRegistry(newAutoStart)
        IniWrite(chkTrayMic.Value ? 1 : 0, configFile, "Settings", "TrayIconMicState")
        IniWrite(chkSoundFx.Value ? 1 : 0, configFile, "Settings", "SoundFxEnabled")
        IniWrite(chkTelemetry.Value ? 1 : 0, configFile, "Settings", "TelemetryEnabled")

        IniWrite(GetActionKey(ddlAct1.Text), configFile, "Settings", "Action1")
        IniWrite(GetActionKey(ddlAct2.Text), configFile, "Settings", "Action2")
        IniWrite(GetActionKey(ddlAct3.Text), configFile, "Settings", "Action3")
        IniWrite(GetActionKey(ddlAct4.Text), configFile, "Settings", "Action4")

        SaveActionData(actKey, val, idx) {
            key := GetActionKey(actKey)
            if (key = "TextTemplate") {
                IniWrite(val, configFile, "Settings", "TextTemplate" idx)
                IniWrite("", configFile, "Settings", "CustomMacro" idx)
            } else {
                IniWrite(val, configFile, "Settings", "CustomMacro" idx)
                IniWrite("", configFile, "Settings", "TextTemplate" idx)
            }
        }

        SaveActionData(ddlAct1.Text, Trim(edtMacro1.Value), 1)
        SaveActionData(ddlAct2.Text, Trim(edtMacro2.Value), 2)
        SaveActionData(ddlAct3.Text, Trim(edtMacro3.Value), 3)
        SaveActionData(ddlAct4.Text, Trim(edtMacro4.Value), 4)

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
