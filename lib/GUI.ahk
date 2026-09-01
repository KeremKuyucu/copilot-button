; ══════════════════════════════════════════
;  GUI, AYARLAR PANELİ & TEMA MODÜLÜ
; ══════════════════════════════════════════

; ══════════════════════════════════════════
;  WINDOWS BAŞLANGIÇ & BAŞLAT MENÜSÜ KISAYOLLARI
; ══════════════════════════════════════════
SetStartupShortcut(enable := true) {
    shortcutPath := A_Startup "\CopilotButton.lnk"
    if enable {
        try FileCreateShortcut(A_ScriptFullPath, shortcutPath, A_ScriptDir)
    } else {
        if FileExist(shortcutPath) {
            try FileDelete(shortcutPath)
        }
    }
}

CreateStartMenuShortcut(targetPath := "") {
    if (targetPath = "")
        targetPath := A_ScriptFullPath
    startMenuPath := A_Programs "\CopilotButton.lnk"
    try {
        iconPath := A_ScriptDir "\logo.ico"
        if FileExist(iconPath)
            FileCreateShortcut(targetPath, startMenuPath, A_ScriptDir, , "Copilot Tuşu — Medya & Mikrofon Kontrolü",
                iconPath)
        else
            FileCreateShortcut(targetPath, startMenuPath, A_ScriptDir, , "Copilot Tuşu — Medya & Mikrofon Kontrolü")
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
        customMacro1, customMacro2, customMacro3, customMacro4

    if (IsObject(settingsGui)) {
        settingsGui.Show()
        return
    }

    isDark := (GetEffectiveTheme() = "Dark")

    ; Modern Mavi Vurgulu Renk Paleti (Deep Navy & Windows 11 Fluent Blue)
    if (isDark) {
        bgColor := "0E121B"       ; Derin modern lacivert-gri pencere arka planı
        cardBgColor := "161C2A"   ; Kart arka planı
        textColor := "FFFFFF"     ; Beyaz ana metin
        subTextColor := "8FA8C8"  ; Yumuşak mavi-gri ikincil metin
        dimTextColor := "5D7699"  ; Açıklama metni
        accentBlue := "0078D4"    ; Windows Fluent Mavi (Ana Butonlar)
        darkBlueBtn := "0067C0"   ; Orta Mavi Buton
        navInactiveBg := "182132"   ; Pasif sekme arka planı
        navInactiveTxt := "8CB8EC"  ; Pasif sekme yazı rengi
        editBgColor := "182030"     ; Koyu input kutusu
        borderClr := "233046"       ; Ayrım çizgisi
    } else {
        bgColor := "F0F4FA"         ; Açık modern gri-mavi arka plan
        cardBgColor := "FFFFFF"     ; Beyaz kart
        textColor := "0F172A"       ; Koyu mavi-gri metin
        subTextColor := "334155"    ; İkincil metin
        dimTextColor := "64748B"    ; Açıklama metni
        accentBlue := "0078D4"      ; Windows Fluent Mavi
        darkBlueBtn := "0067C0"     ; Orta Mavi
        navInactiveBg := "E2EAF4"   ; Pasif sekme arka planı
        navInactiveTxt := "1E3A5F"  ; Pasif sekme yazı rengi
        editBgColor := "FFFFFF"   ; Beyaz input kutusu
        borderClr := "CBD5E1"     ; Açık ayrım çizgisi
    }
    editOpt := "Background" editBgColor " c" textColor

    settingsGui := Gui("+AlwaysOnTop +Owner -MinimizeBox", "Copilot Button — Yapılandırma ve Ayarlar")
    settingsGui.BackColor := bgColor
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")

    ; DWM Windows 11 Başlık Çubuğu & Yuvarlatılmış Köşeler
    SetWindowDarkMode(settingsGui.Hwnd, isDark)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", settingsGui.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)

    ; Buton HWND Haritası (Hover el imleci için)
    buttonHwnds := Map()
    RegBtn(ctrl) => (buttonHwnds[ctrl.Hwnd] := true, ctrl)

    ; ══════════════════════════════════════════
    ;  ÜST HEADER (BAŞLIK & SÜRÜM ROZETİ)
    ; ══════════════════════════════════════════
    iconPath := A_ScriptDir "\logo.ico"
    if FileExist(iconPath)
        settingsGui.Add("Picture", "x22 y14 w36 h36", iconPath)

    settingsGui.SetFont("s13 bold c" textColor, "Segoe UI")
    settingsGui.Add("Text", "x68 y12 w320 h24", "Copilot Button")

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    settingsGui.Add("Text", "x68 y37 w350 h18", "Windows Copilot Tuşu & Medya Kontrol Merkezi")

    ; Sürüm Rozeti
    settingsGui.SetFont("s9 bold c00A3FF", "Segoe UI")
    settingsGui.Add("Text", "x520 y18 w175 h24 Right", "v" APP_VERSION "  ● Aktif")

    ; Üst Ayırıcı Çizgi
    settingsGui.Add("Text", "x0 y65 w720 h1 Background" borderClr)

    ; ══════════════════════════════════════════
    ;  SOL KENAR ÇUBUĞU (SIDEBAR MAVİ BUTONLAR)
    ; ══════════════════════════════════════════
    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")

    btnNav1 := RegBtn(settingsGui.Add("Text", "x16 y78 w172 h42 Background" accentBlue " cFFFFFF Center 0x200",
        "▶  ⚡  Tıklama Eylemleri"))
    btnNav2 := RegBtn(settingsGui.Add("Text", "x16 y126 w172 h42 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "    ⏱️  Zamanlama & Sistem"))
    btnNav3 := RegBtn(settingsGui.Add("Text", "x16 y174 w172 h42 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "    🎨  OSD & Görünüm"))
    btnNav4 := RegBtn(settingsGui.Add("Text", "x16 y222 w172 h42 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "    🎵  Medya & Bas-Konuş"))
    btnNav5 := RegBtn(settingsGui.Add("Text", "x16 y270 w172 h42 Background" navInactiveBg " c" navInactiveTxt " Center 0x200",
        "    ℹ️  Hakkında & Bakım"))

    navButtons := [btnNav1, btnNav2, btnNav3, btnNav4, btnNav5]
    navLabels := [
        "⚡  Tıklama Eylemleri",
        "⏱️  Zamanlama & Sistem",
        "🎨  OSD & Görünüm",
        "🎵  Medya & Bas-Konuş",
        "ℹ️  Hakkında & Bakım"
    ]

    ; Sol Alt Bilgi Kutusu
    settingsGui.Add("GroupBox", "x16 y335 w172 h190", "💡 Hızlı İpucu")
    settingsGui.SetFont("s8 c" subTextColor, "Segoe UI")
    settingsGui.Add("Text", "x24 y360 w156 h155",
        "• 1 Tık: Mikrofon sustur/aç`n`n• 2 Tık: Şarkıyı duraklat/çal`n`n• 3 Tık: Sonraki şarkı`n`n• Basılı Tutma: Müzik uygulamasını öne getir"
    )

    ; Dikey Ayırıcı Çizgi
    settingsGui.Add("Text", "x196 y66 h474 w1 Background" borderClr)

    ; ══════════════════════════════════════════
    ;  SAYFA KONTROL KOLEKSİYONLARI
    ; ══════════════════════════════════════════
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

    ; Eylem Görüntüleme Listesi
    actionDisplayList := []
    for k in actionKeys {
        actionDisplayList.Push(actionDisplayMap[k])
    }

    ; ══════════════════════════════════════════
    ;  SAYFA 1: ⚡ TIKLAMA EYLEMLERİ
    ; ══════════════════════════════════════════
    settingsGui.SetFont("s10 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x212 y78 w485 h22", "⌨️ Tıklama Eylem Atamaları"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x212 y102 w485 h18",
        "Copilot tuşuna art arda basıldığında çalıştırılacak işlevleri belirleyin:"))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("GroupBox", "x212 y124 w485 h340", "⚡ Tık Fonksiyonları"))

    ; 1 Tık
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x228 y152 w130 h22", "1 Tık (Tek Basım):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct1 := AddP1(settingsGui.Add("DropDownList", "x365 y148 w315 r14 " editOpt, actionDisplayList))
    ddlAct1.Text := GetActionDisplay(action1)
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    lblMacro1 := AddP1(settingsGui.Add("Text", "x228 y175 w95 h18", "  Makro dizisi:"))
    settingsGui.SetFont("s8 c" textColor, "Segoe UI")
    edtMacro1 := AddP1(settingsGui.Add("Edit", "x325 y172 w270 h22 " editOpt, customMacro1))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnRec1 := RegBtn(AddP1(settingsGui.Add("Text", "x602 y172 w78 h22 Background" darkBlueBtn " cFFFFFF Center 0x200", "⏺️ Kaydet")))
    btnRec1.OnEvent("Click", (*) => OpenMacroRecorder(1, edtMacro1, settingsGui))

    ; 2 Tık
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x228 y204 w130 h22", "2 Tık (Çift Basım):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct2 := AddP1(settingsGui.Add("DropDownList", "x365 y200 w315 r14 " editOpt, actionDisplayList))
    ddlAct2.Text := GetActionDisplay(action2)
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    lblMacro2 := AddP1(settingsGui.Add("Text", "x228 y227 w95 h18", "  Makro dizisi:"))
    settingsGui.SetFont("s8 c" textColor, "Segoe UI")
    edtMacro2 := AddP1(settingsGui.Add("Edit", "x325 y224 w270 h22 " editOpt, customMacro2))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnRec2 := RegBtn(AddP1(settingsGui.Add("Text", "x602 y224 w78 h22 Background" darkBlueBtn " cFFFFFF Center 0x200", "⏺️ Kaydet")))
    btnRec2.OnEvent("Click", (*) => OpenMacroRecorder(2, edtMacro2, settingsGui))

    ; 3 Tık
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x228 y256 w130 h22", "3 Tık (Üç Basım):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct3 := AddP1(settingsGui.Add("DropDownList", "x365 y252 w315 r14 " editOpt, actionDisplayList))
    ddlAct3.Text := GetActionDisplay(action3)
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    lblMacro3 := AddP1(settingsGui.Add("Text", "x228 y279 w95 h18", "  Makro dizisi:"))
    settingsGui.SetFont("s8 c" textColor, "Segoe UI")
    edtMacro3 := AddP1(settingsGui.Add("Edit", "x325 y276 w270 h22 " editOpt, customMacro3))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnRec3 := RegBtn(AddP1(settingsGui.Add("Text", "x602 y276 w78 h22 Background" darkBlueBtn " cFFFFFF Center 0x200", "⏺️ Kaydet")))
    btnRec3.OnEvent("Click", (*) => OpenMacroRecorder(3, edtMacro3, settingsGui))

    ; 4 Tık
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x228 y308 w130 h22", "4 Tık (Dört Basım):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct4 := AddP1(settingsGui.Add("DropDownList", "x365 y304 w315 r14 " editOpt, actionDisplayList))
    ddlAct4.Text := GetActionDisplay(action4)
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    lblMacro4 := AddP1(settingsGui.Add("Text", "x228 y331 w95 h18", "  Makro dizisi:"))
    settingsGui.SetFont("s8 c" textColor, "Segoe UI")
    edtMacro4 := AddP1(settingsGui.Add("Edit", "x325 y328 w270 h22 " editOpt, customMacro4))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnRec4 := RegBtn(AddP1(settingsGui.Add("Text", "x602 y328 w78 h22 Background" darkBlueBtn " cFFFFFF Center 0x200", "⏺️ Kaydet")))
    btnRec4.OnEvent("Click", (*) => OpenMacroRecorder(4, edtMacro4, settingsGui))

    ; Makro alanlarının görünürlüğünü kontrol eden fonksiyon
    UpdateMacroVisibility(ddl, lblMacro, edtMacro, btnRec) {
        isMacro := (GetActionKey(ddl.Text) = "CustomMacro")
        lblMacro.Visible := isMacro
        edtMacro.Visible := isMacro
        btnRec.Visible := isMacro
    }

    ; Başlangıçta makro alanlarını güncelle
    UpdateMacroVisibility(ddlAct1, lblMacro1, edtMacro1, btnRec1)
    UpdateMacroVisibility(ddlAct2, lblMacro2, edtMacro2, btnRec2)
    UpdateMacroVisibility(ddlAct3, lblMacro3, edtMacro3, btnRec3)
    UpdateMacroVisibility(ddlAct4, lblMacro4, edtMacro4, btnRec4)

    ; Dropdown değiştiğinde makro alanını göster/gizle
    ddlAct1.OnEvent("Change", (*) => UpdateMacroVisibility(ddlAct1, lblMacro1, edtMacro1, btnRec1))
    ddlAct2.OnEvent("Change", (*) => UpdateMacroVisibility(ddlAct2, lblMacro2, edtMacro2, btnRec2))
    ddlAct3.OnEvent("Change", (*) => UpdateMacroVisibility(ddlAct3, lblMacro3, edtMacro3, btnRec3))
    ddlAct4.OnEvent("Change", (*) => UpdateMacroVisibility(ddlAct4, lblMacro4, edtMacro4, btnRec4))

    ; Açıklamalar Kartı
    AddP1(settingsGui.Add("GroupBox", "x212 y472 w485 h55", "ℹ️ Makro Formatı & Kaydedici"))
    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x228 y490 w455 h32",
        "Kısayolları '⏺️ Kaydet' butonuna basarak klavyenizden otomatik yakalayabilir veya elle yazabilirsiniz (Örn: ^c = Ctrl+C, !{F4} = Alt+F4, #+s = Win+Shift+S)."))

    ; ══════════════════════════════════════════
    ;  SAYFA 2: ⏱️ ZAMANLAMA & SİSTEM
    ; ══════════════════════════════════════════
    settingsGui.SetFont("s10 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x212 y78 w485 h22", "⏱️ Zamanlama & Sistem Seçenekleri"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x212 y102 w485 h18",
        "Tıklama algılama sürelerini ve sistem entegrasyonlarını yapılandırın:"))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("GroupBox", "x212 y124 w485 h180", "⏱️ Algılama Eşik Süreleri"))

    ; Çift Tık Bekleme Süresi
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x228 y152 w220 h22", "Çoklu Tık Bekleme Süresi (ms):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtDoubleTap := AddP2(settingsGui.Add("Edit", "x450 y148 w75 h24 Number " editOpt, doubleTapThreshold))

    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnDT150 := RegBtn(AddP2(settingsGui.Add("Text", "x532 y148 w45 h24 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "150")))
    btnDT250 := RegBtn(AddP2(settingsGui.Add("Text", "x581 y148 w52 h24 Background" accentBlue " cFFFFFF Center 0x200",
        "250★")))
    btnDT350 := RegBtn(AddP2(settingsGui.Add("Text", "x637 y148 w45 h24 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "350")))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x228 y176 w450 h16",
        "İki tık arasındaki maksimum bekleme süresidir (Varsayılan: 250 ms)."))

    ; Basılı Tutma Eşik Süresi
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x228 y206 w220 h22", "Basılı Tutma Eşik Süresi (ms):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtHold := AddP2(settingsGui.Add("Edit", "x450 y202 w75 h24 Number " editOpt, holdThreshold))

    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnHold200 := RegBtn(AddP2(settingsGui.Add("Text", "x532 y202 w45 h24 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "200")))
    btnHold250 := RegBtn(AddP2(settingsGui.Add("Text", "x581 y202 w52 h24 Background" accentBlue " cFFFFFF Center 0x200",
        "250★")))
    btnHold400 := RegBtn(AddP2(settingsGui.Add("Text", "x637 y202 w45 h24 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "400")))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x228 y230 w450 h16",
        "Basılı tutma eyleminin tetikleneceği süredir (Varsayılan: 250 ms)."))

    ; Mikrofon Cihaz Seçimi
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("GroupBox", "x212 y312 w485 h70", "🎙️ Mikrofon Cihaz Seçimi"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x228 y338 w130 h22", "Mikrofon Cihazı:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")

    ; Capture cihazlarını listele
    captureDevices := EnumerateCaptureDevices()
    micDeviceList := ["🔄 Otomatik Algıla (Auto)"]
    for _, devName in captureDevices {
        micDeviceList.Push(devName)
    }
    ddlMicDevice := AddP2(settingsGui.Add("DropDownList", "x365 y334 w315 r6 " editOpt, micDeviceList))
    ; Seçili cihazı ayarla
    if (micDevice = "Auto" || micDevice = "")
        ddlMicDevice.Text := "🔄 Otomatik Algıla (Auto)"
    else
        try ddlMicDevice.Text := micDevice

    ; Sistem & Bildirimler
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("GroupBox", "x212 y390 w485 h135", "⚙️ Sistem & Geri Bildirim"))

    chkAuto := AddP2(settingsGui.Add("Checkbox", "x228 y414 w455 h22 Checked" (autoStart ? "1" : "0"),
    "🚀  Windows açıldığında otomatik olarak başlat"))

    chkTrayMic := AddP2(settingsGui.Add("Checkbox", "x228 y440 w455 h22 Checked" (trayIconMicState ? "1" : "0"),
    "🎙️  Mikrofon durumuna göre görev çubuğu simgesini değiştir (Mute ikonu)"))

    chkSoundFx := AddP2(settingsGui.Add("Checkbox", "x228 y466 w455 h22 Checked" (soundFxEnabled ? "1" : "0"),
    "🔊  Mikrofon susturulduğunda / açıldığında hafif ses efekti çal"))

    chkTelemetry := AddP2(settingsGui.Add("Checkbox", "x228 y492 w455 h22 Checked" (telemetryEnabled ? "1" : "0"),
    "📊  Anonim açılış telemetri ve kullanım loglarını gönder"))

    ; ══════════════════════════════════════════
    ;  SAYFA 3: 🎨 OSD & GÖRÜNÜM
    ; ══════════════════════════════════════════
    settingsGui.SetFont("s10 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x212 y78 w485 h22", "🎨 OSD Bildirim & Görünüm"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x212 y102 w485 h18",
        "Ekran üstü bildirimlerin (OSD) temasını, rengini ve boyutunu özelleştirin:"))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("GroupBox", "x212 y124 w485 h118", "🎨 Tema & Bildirim Konumu"))

    ; Tema
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x228 y148 w120 h22", "Arayüz Teması:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlTheme := AddP3(settingsGui.Add("DropDownList", "x350 y144 w150 r3 " editOpt, ["Dark", "Light", "Auto"]))
    ddlTheme.Text := themeMode
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x508 y148 w175 h20", "(Karanlık / Aydınlık / Sistem)"))

    ; Konum
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x228 y184 w120 h22", "OSD Konumu:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlPos := AddP3(settingsGui.Add("DropDownList", "x350 y180 w150 r5 " editOpt, ["TopLeft", "TopRight", "BottomLeft",
        "BottomRight", "Center"]))
    ddlPos.Text := osdPosition
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x508 y184 w175 h20", "(Sol Üst / Sağ Üst / Merkez)"))

    ; Tipografi & Renk
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("GroupBox", "x212 y250 w485 h275", "💬 Metin Rengi, Tipografi ve Canlı Test"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x228 y276 w120 h22", "Metin Rengi (Hex):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtOsdColor := AddP3(settingsGui.Add("Edit", "x350 y272 w80 h24 " editOpt, osdColor))

    ; Hızlı Renk Paleti Çipleri (Mavi zeminli)
    settingsGui.SetFont("s9 cFFFFFF", "Segoe UI")
    btnClr1 := RegBtn(AddP3(settingsGui.Add("Text", "x436 y272 w36 h24 Background1C283C Center 0x200", "🟦")))  ; Cyan
    btnClr2 := RegBtn(AddP3(settingsGui.Add("Text", "x476 y272 w36 h24 Background1C283C Center 0x200", "🟩")))  ; Green
    btnClr3 := RegBtn(AddP3(settingsGui.Add("Text", "x516 y272 w36 h24 Background1C283C Center 0x200", "🟪")))  ; Purple
    btnClr4 := RegBtn(AddP3(settingsGui.Add("Text", "x556 y272 w36 h24 Background1C283C Center 0x200", "🟧")))  ; Amber
    btnClr5 := RegBtn(AddP3(settingsGui.Add("Text", "x596 y272 w36 h24 Background1C283C Center 0x200", "🟥")))  ; Red
    btnClr6 := RegBtn(AddP3(settingsGui.Add("Text", "x636 y272 w36 h24 Background1C283C Center 0x200", "⬜")))  ; White

    ; Font Boyutu
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x228 y312 w120 h22", "Font Boyutu (pt):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtOsdSize := AddP3(settingsGui.Add("Edit", "x350 y308 w80 h24 Number " editOpt, osdFontSize))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x438 y312 w240 h20", "pt (Varsayılan: 10, Önerilen: 9 - 14)"))

    ; Gösterim Süresi
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x228 y348 w120 h22", "Gösterim Süresi:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    edtOsdDur := AddP3(settingsGui.Add("Edit", "x350 y344 w80 h24 Number " editOpt, osdDurationMs))
    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x438 y348 w240 h20", "ms (Varsayılan: 1500)"))

    ; Animasyon
    chkFade := AddP3(settingsGui.Add("Checkbox", "x228 y382 w455 h22 Checked" (osdFadeEnabled ? "1" : "0"),
    "✨  Fade-in / Fade-out (Yumuşak solma animasyonu kullan)"))

    ; Canlı Test Mavi Butonu
    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnTestOsd := RegBtn(AddP3(settingsGui.Add("Text", "x228 y420 w454 h36 Background" accentBlue " cFFFFFF Center 0x200",
        "👁️  OSD Bildirimini Şimdi Ekranda Test Et")))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP3(settingsGui.Add("Text", "x228 y465 w454 h45",
        "Yukarıdaki ayarları ekranda hemen görmek için 'OSD Test Et' butonuna tıklayabilirsiniz. Ayarları beğenirseniz alttaki 'Kaydet' butonuyla kalıcı yapın."
    ))

    ; ══════════════════════════════════════════
    ;  SAYFA 4: 🎵 MEDYA & BAS-KONUŞ
    ; ══════════════════════════════════════════
    settingsGui.SetFont("s10 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x212 y78 w485 h22", "🎵 Medya Denetimi & Basılı Tutma"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x212 y102 w485 h18", "Müzik uygulaması ve basılı tutma modlarını yapılandırın:"))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("GroupBox", "x212 y124 w485 h188", "🎵 Hedef Müzik Oynatıcı"))

    radSpotify := AddP4(settingsGui.Add("Radio", "x228 y148 w140 h22 Checked" (musicApp = "Spotify" ? "1" : "0"),
    " Spotify"))
    radYtm := AddP4(settingsGui.Add("Radio", "x385 y148 w160 h22 Checked" (musicApp = "YTM" ? "1" : "0"),
    " YouTube Music"))

    ; Spotify Alanları
    settingsGui.SetFont("s8.5 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x228 y180 w100 h20", "Spotify Komut:"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    edtSpotCmd := AddP4(settingsGui.Add("Edit", "x330 y176 w350 h22 " editOpt, spotifyCmd))

    settingsGui.SetFont("s8.5 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x228 y208 w100 h20", "Spotify Başlık:"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    edtSpotTitle := AddP4(settingsGui.Add("Edit", "x330 y204 w350 h22 " editOpt, spotifyTitle))

    ; YTM Alanları
    settingsGui.SetFont("s8.5 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x228 y236 w100 h20", "YTM URL:"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    edtYtmUrl := AddP4(settingsGui.Add("Edit", "x330 y232 w350 h22 " editOpt, ytmUrl))

    settingsGui.SetFont("s8.5 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x228 y264 w100 h20", "YTM Başlık:"))
    settingsGui.SetFont("s8.5 c" textColor, "Segoe UI")
    edtYtmTitle := AddP4(settingsGui.Add("Edit", "x330 y260 w350 h22 " editOpt, ytmTitle))

    ; Basılı Tutma Kartı
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("GroupBox", "x212 y320 w485 h205", "🎤 Basılı Tutma Eylemi (Hold Action)"))

    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x228 y346 w130 h22", "Basılı Tutma Modu:"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlHold := AddP4(settingsGui.Add("DropDownList", "x365 y342 w315 r3 " editOpt, ["MusicApp", "PushToTalk",
        "CustomApp"]))
    ddlHold.Text := holdAction

    settingsGui.SetFont("s8.5 bold c" textColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x228 y380 w450 h18", "Özel Uygulama Yolu veya Web URL (CustomApp seçildiğinde):"))
    edtCustomApp := AddP4(settingsGui.Add("Edit", "x228 y402 w370 h26 " editOpt, customAppPath))
    settingsGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnBrowse := RegBtn(AddP4(settingsGui.Add("Text", "x604 y402 w78 h26 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "📁 Gözat")))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP4(settingsGui.Add("Text", "x228 y438 w454 h70",
        "• MusicApp: Basılı tutulduğunda Spotify veya YouTube Music'i açar veya öne getirir.`n"
        . "• PushToTalk: Tuşa basılı tuttuğunuz sürece mikrofon açılır, bırakınca susturulur.`n"
        . "• CustomApp: Belirttiğiniz programı (Discord, Slack, vb.) veya web sayfasını açar."))

    ; ══════════════════════════════════════════
    ;  SAYFA 5: ℹ️ HAKKINDA & BAKIM
    ; ══════════════════════════════════════════
    settingsGui.SetFont("s10 bold c" textColor, "Segoe UI")
    AddP5(settingsGui.Add("Text", "x212 y78 w485 h22", "ℹ️ Uygulama Bilgileri & Bakım"))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP5(settingsGui.Add("Text", "x212 y102 w485 h18", "Sürüm detayları, güncelleme kontrolü ve yönetim araçları:"))

    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP5(settingsGui.Add("GroupBox", "x212 y124 w485 h180", "ℹ️ Copilot Button Controller"))

    settingsGui.SetFont("s10 bold c" textColor, "Segoe UI")
    AddP5(settingsGui.Add("Text", "x228 y150 w450 h22", "Copilot Button Controller — v" APP_VERSION))

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP5(settingsGui.Add("Text", "x228 y178 w450 h42",
        "Windows klavyelerindeki Copilot donanım tuşunu tam donanımlı bir medya, mikrofon susturma ve üretkenlik kısayoluna dönüştürür."
    ))

    AddP5(settingsGui.Add("Text", "x228 y226 w450 h20", "• Geliştirici: Kerem Kuyucu (c) 2026 Tüm Hakları Saklıdır."))
    AddP5(settingsGui.Add("Text", "x228 y250 w450 h20", "• Açık Kaynak: https://github.com/KeremKuyucu/copilot-button"))
    AddP5(settingsGui.Add("Text", "x228 y274 w450 h20", "• Taban: AutoHotkey v2 Native Architecture"))

    ; Hızlı Araçlar Mavi Butonlar
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP5(settingsGui.Add("GroupBox", "x212 y312 w485 h213", "🛠️ Sistem ve Bakım Araçları"))

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnCheckUpdate := RegBtn(AddP5(settingsGui.Add("Text", "x228 y340 w220 h36 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "🔄  Güncellemeleri Denetle")))
    btnReloadScript := RegBtn(AddP5(settingsGui.Add("Text", "x460 y340 w220 h36 Background" darkBlueBtn " cFFFFFF Center 0x200",
        "🔄  Uygulamayı Yeniden Başlat")))
    btnUninstall := RegBtn(AddP5(settingsGui.Add("Text", "x228 y390 w454 h36 Background8B1A1A cFFFFFF Center 0x200",
        "🗑️  Uygulamayı ve Ayarları Tamamen Kaldır")))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP5(settingsGui.Add("Text", "x228 y440 w454 h65",
        "Kaldırma işlemi uygulamanın başlangıç kısayolunu, kayıtlı ayarlarını ve Inno Setup kurulum dosyalarını sistemden temizler."
    ))

    ; ══════════════════════════════════════════
    ;  ALT FOOTER BAR (MAVİ KAYDET & İPTAL)
    ; ══════════════════════════════════════════
    settingsGui.Add("Text", "x0 y540 w720 h1 Background" borderClr)

    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    settingsGui.Add("Text", "x20 y556 w380 h24", "💾 Değişikliklerin geçerli olması için kaydedip yenileyin.")

    settingsGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnCancel := RegBtn(settingsGui.Add("Text", "x430 y550 w120 h36 Background233046 cA0C4FF Center 0x200", "❌  İptal"))
    btnCancel.OnEvent("Click", (*) => CleanAndClose())

    btnSave := RegBtn(settingsGui.Add("Text", "x560 y550 w145 h36 Background" accentBlue " cFFFFFF Center 0x200",
        "💾  Kaydet & Uygula"))
    btnSave.OnEvent("Click", (*) => SaveAndReload())

    ; ══════════════════════════════════════════
    ;  TAB VE ETKİLEŞİM YÖNETİMİ
    ; ══════════════════════════════════════════
    SwitchTab(tabIndex) {
        for idx, ctrlList in [page1, page2, page3, page4, page5] {
            isCurrent := (idx = tabIndex)
            for _, ctrl in ctrlList {
                ctrl.Visible := isCurrent
            }
        }
        for idx, btn in navButtons {
            if (idx = tabIndex) {
                btn.Opt("Background" accentBlue " cFFFFFF")
                btn.Text := "▶  " navLabels[idx]
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

    ; Sayfa 2 Preset Butonları
    btnDT150.OnEvent("Click", (*) => (edtDoubleTap.Value := "150"))
    btnDT250.OnEvent("Click", (*) => (edtDoubleTap.Value := "250"))
    btnDT350.OnEvent("Click", (*) => (edtDoubleTap.Value := "350"))

    btnHold200.OnEvent("Click", (*) => (edtHold.Value := "200"))
    btnHold250.OnEvent("Click", (*) => (edtHold.Value := "250"))
    btnHold400.OnEvent("Click", (*) => (edtHold.Value := "400"))

    ; Sayfa 3 Renk Preset Butonları
    btnClr1.OnEvent("Click", (*) => (edtOsdColor.Value := "00E5FF"))  ; Cyan
    btnClr2.OnEvent("Click", (*) => (edtOsdColor.Value := "00E676"))  ; Green
    btnClr3.OnEvent("Click", (*) => (edtOsdColor.Value := "B388FF"))  ; Purple
    btnClr4.OnEvent("Click", (*) => (edtOsdColor.Value := "FFB300"))  ; Amber
    btnClr5.OnEvent("Click", (*) => (edtOsdColor.Value := "FF5252"))  ; Red
    btnClr6.OnEvent("Click", (*) => (edtOsdColor.Value := "FFFFFF"))  ; White

    ; Sayfa 3 Canlı OSD Testi
    btnTestOsd.OnEvent("Click", ShowTestOsd)

    ; Sayfa 4 ve 5 Buton Olayları
    btnBrowse.OnEvent("Click", (*) => BrowseCustomApp(edtCustomApp))
    btnCheckUpdate.OnEvent("Click", (*) => CheckForUpdates(false))
    btnReloadScript.OnEvent("Click", (*) => Reload())
    btnUninstall.OnEvent("Click", (*) => UninstallApp())

    ; Mouse Hover Hand Cursor (WM_MOUSEMOVE)
    GuiMouseMove(wParam, lParam, msg, hwnd) {
        if (buttonHwnds.Has(hwnd)) {
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))  ; IDC_HAND
        }
    }
    OnMessage(0x0200, GuiMouseMove)

    CleanAndClose() {
        try OnMessage(0x0200, GuiMouseMove, 0)
        if (IsObject(settingsGui)) {
            settingsGui.Destroy()
            settingsGui := 0
        }
    }

    ; Kapatma ve ESC olayları
    settingsGui.OnEvent("Close", (*) => CleanAndClose())
    settingsGui.OnEvent("Escape", (*) => CleanAndClose())

    ; Kontrol Temalarını Uygula
    ApplyThemeToControls(settingsGui, isDark)

    ; Varsayılan olarak Sayfa 1'i aç
    SwitchTab(1)

    ; Pencereyi Göster
    settingsGui.Show("w720 h600")

    ; ══════════════════════════════════════════
    ;  İÇ YARDIMCI FONKSİYONLAR
    ; ══════════════════════════════════════════
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

        ; Geçici olarak OSD parametrelerini ayarla
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

        ; Eski pencere varsa sıfırla ki yeni font/renk anında işlensin
        if (IsObject(tipGui)) {
            try tipGui.Destroy()
            tipGui := 0
        }

        ShowTip("✨ Copilot Tuşu OSD Önizleme ✨`nKonum: " testPos " | Renk: #" testColor, testDur)

        ; Parametreleri geri yükle (kaydet butonuna basılana kadar orijinal kalsın)
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
        newAuto := chkAuto.Value ? 1 : 0
        newYtmUrl := Trim(edtYtmUrl.Value)
        newYtmTitle := Trim(edtYtmTitle.Value)
        newSpotCmd := Trim(edtSpotCmd.Value)
        newSpotTitle := Trim(edtSpotTitle.Value)

        ; OSD & Tema Ayarları
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
        IniWrite(newAuto, configFile, "Settings", "AutoStart")
        IniWrite(newYtmUrl, configFile, "Settings", "YtmURL")
        IniWrite(newYtmTitle, configFile, "Settings", "YtmWindowTitle")
        IniWrite(newSpotCmd, configFile, "Settings", "SpotifyCmd")
        IniWrite(newSpotTitle, configFile, "Settings", "SpotifyWindowTitle")

        ; OSD & Tema Ayarları kaydet
        IniWrite(newTheme, configFile, "Settings", "Theme")
        IniWrite(newOsdPos, configFile, "Settings", "OsdPosition")
        IniWrite(newOsdColor, configFile, "Settings", "OsdColor")
        IniWrite(newOsdSize, configFile, "Settings", "OsdFontSize")
        IniWrite(newOsdDur, configFile, "Settings", "OsdDurationMs")
        IniWrite(newFade, configFile, "Settings", "OsdFadeEnabled")

        ; Basılı Tutma & Tray İkonu & Ses Efektleri kaydet
        IniWrite(ddlHold.Text, configFile, "Settings", "HoldAction")
        IniWrite(Trim(edtCustomApp.Value), configFile, "Settings", "CustomAppPath")
        IniWrite(chkTrayMic.Value ? 1 : 0, configFile, "Settings", "TrayIconMicState")
        IniWrite(chkSoundFx.Value ? 1 : 0, configFile, "Settings", "SoundFxEnabled")
        IniWrite(chkTelemetry.Value ? 1 : 0, configFile, "Settings", "TelemetryEnabled")

        ; Eylem Atamaları kaydet (Display String -> Key)
        IniWrite(GetActionKey(ddlAct1.Text), configFile, "Settings", "Action1")
        IniWrite(GetActionKey(ddlAct2.Text), configFile, "Settings", "Action2")
        IniWrite(GetActionKey(ddlAct3.Text), configFile, "Settings", "Action3")
        IniWrite(GetActionKey(ddlAct4.Text), configFile, "Settings", "Action4")

        ; Özel Makro dizileri kaydet
        IniWrite(Trim(edtMacro1.Value), configFile, "Settings", "CustomMacro1")
        IniWrite(Trim(edtMacro2.Value), configFile, "Settings", "CustomMacro2")
        IniWrite(Trim(edtMacro3.Value), configFile, "Settings", "CustomMacro3")
        IniWrite(Trim(edtMacro4.Value), configFile, "Settings", "CustomMacro4")

        ; Mikrofon cihaz seçimi kaydet
        selectedMic := ddlMicDevice.Text
        if (selectedMic = "🔄 Otomatik Algıla (Auto)")
            IniWrite("Auto", configFile, "Settings", "MicDevice")
        else
            IniWrite(selectedMic, configFile, "Settings", "MicDevice")

        SetStartupShortcut(newAuto)

        settingsGui.Destroy()
        settingsGui := 0
        ShowTip("✅ Ayarlar kaydedildi! Yenileniyor...")
        Sleep 500
        Reload()
    }
}

; ══════════════════════════════════════════
;  UYGULAMAYI KALDIRMA (UNINSTALL)
; ══════════════════════════════════════════
UninstallApp() {
    global settingsGui, configFile

    uninstallerPath := A_ScriptDir "\unins000.exe"
    if FileExist(uninstallerPath) {
        result := MsgBox(
            "Copilot Button uygulamasını sistemden tamamen kaldırmak istiyor musunuz?",
            "🗑️ Uygulamayı Kaldır — Copilot Button",
            "YesNo Icon? Default2"
        )
        if (result != "Yes")
            return

        if (IsObject(settingsGui)) {
            settingsGui.Destroy()
            settingsGui := 0
        }

        try Run('"' uninstallerPath '"')
        ExitApp()
        return
    }

    result := MsgBox(
        "Copilot Button uygulaması kaldırılacak!`n`n"
        . "Windows başlangıç kısayolu ve ayarlar silinecek.`n`n"
        . "Devam etmek istiyor musunuz?",
        "🗑️ Uygulamayı Kaldır — Copilot Button",
        "YesNo Icon! Default2"
    )

    if (result != "Yes")
        return

    if (IsObject(settingsGui)) {
        settingsGui.Destroy()
        settingsGui := 0
    }

    try SetStartupShortcut(false)
    try RemoveStartMenuShortcut()
    if FileExist(configFile)
        try FileDelete(configFile)

    ExitApp()
}
