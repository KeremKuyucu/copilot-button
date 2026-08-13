#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook

global APP_VERSION := "1.0.3"

SetTitleMatchMode 2

; ══════════════════════════════════════════
;  ÖZEL KLASÖRE YERLEŞTİRME & KURULUM
; ══════════════════════════════════════════
EnsureInstalledLocation()

; ══════════════════════════════════════════
;  AYARLAR — config.ini'den okunur
; ══════════════════════════════════════════
global configFile := A_ScriptDir "\config.ini"

; Config dosyası yoksa varsayılan değerlerle oluştur
if (!FileExist(configFile))
    CreateDefaultConfig(configFile)

try doubleTapThreshold := Integer(IniRead(configFile, "Settings", "DoubleTapMs", 250))
catch
    doubleTapThreshold := 250

try holdThreshold := Integer(IniRead(configFile, "Settings", "HoldMs", 250))
catch
    holdThreshold := 250

try autoStart := Integer(IniRead(configFile, "Settings", "AutoStart", 1))
catch
    autoStart := 1

global musicApp     := IniRead(configFile, "Settings", "MusicApp", "YTM")
global ytmUrl       := IniRead(configFile, "Settings", "YtmURL", "https://music.youtube.com")
global ytmTitle     := IniRead(configFile, "Settings", "YtmWindowTitle", "YouTube Music")
global spotifyCmd   := IniRead(configFile, "Settings", "SpotifyCmd", "spotify:")
global spotifyTitle := IniRead(configFile, "Settings", "SpotifyWindowTitle", "ahk_exe spotify.exe")

; OSD & Tema Ayarları
global themeMode      := IniRead(configFile, "Settings", "Theme", "Dark")
global osdPosition    := IniRead(configFile, "Settings", "OsdPosition", "TopLeft")
global osdColor       := IniRead(configFile, "Settings", "OsdColor", "00E5FF")

try osdFontSize := Integer(IniRead(configFile, "Settings", "OsdFontSize", 10))
catch
    osdFontSize := 10

try osdDurationMs := Integer(IniRead(configFile, "Settings", "OsdDurationMs", 1500))
catch
    osdDurationMs := 1500

try osdFadeEnabled := Integer(IniRead(configFile, "Settings", "OsdFadeEnabled", 1))
catch
    osdFadeEnabled := 1

; Basılı Tutma & Eylem Ayarları
global holdAction     := IniRead(configFile, "Settings", "HoldAction", "MusicApp")
global customAppPath  := IniRead(configFile, "Settings", "CustomAppPath", "")
global action1        := IniRead(configFile, "Settings", "Action1", "MicMute")
global action2        := IniRead(configFile, "Settings", "Action2", "PlayPause")
global action3        := IniRead(configFile, "Settings", "Action3", "NextTrack")
global action4        := IniRead(configFile, "Settings", "Action4", "PrevTrack")

try trayIconMicState := Integer(IniRead(configFile, "Settings", "TrayIconMicState", 1))
catch
    trayIconMicState := 1

global doubleTapThreshold, holdThreshold, autoStart
global osdFontSize, osdDurationMs, osdFadeEnabled, trayIconMicState, themeMode
global isKeyDown      := false
global holdTriggered  := false   ; Basılı tutma eyleminin tetiklenip tetiklenmediği
global tapCount       := 0       ; Arka arkaya tıklama sayısı
global settingsGui    := 0       ; GUI pencere nesnesi
global micOverlayGui  := 0       ; Mikrofon kapalı OSD penceresi
global fadeTimer      := 0       ; Fade animasyon zamanlayıcısı
global fadeAlpha      := 0       ; Mevcut saydamlık değeri (0-255)
global pttActive      := false   ; Push-to-Talk aktif mi

; Windows Başlangıç Kısayolu Ayarla
SetStartupShortcut(autoStart)

; ══════════════════════════════════════════
;  TRAY İKONU VE MENÜSÜ
; ══════════════════════════════════════════
if FileExist(A_ScriptDir "\logo.ico")
    TraySetIcon A_ScriptDir "\logo.ico"

activeAppName := (musicApp = "Spotify") ? "Spotify" : "YouTube Music"

A_IconTip := "Copilot Tuşu — " activeAppName " & Medya Kontrolü`n• 1 tık : Mikrofon Sustur / Aç`n• 2 tık : Şarkı Durdur / Oynat`n• 3 tık : Şarkı Geç`n• Basılı : " activeAppName " Aç / Öne Al"

A_TrayMenu.Delete()
A_TrayMenu.Add("⚙️  Ayarlar",         ShowSettingsGUI)
A_TrayMenu.Add("🔄 Güncelleme Kontrolü", (*) => CheckForUpdates(false))
A_TrayMenu.Add("🔄 Scripti Yenile",   (*) => Reload())
A_TrayMenu.Add()                         ; Ayırıcı
A_TrayMenu.Add("❌ Çıkış",            (*) => ExitApp())

global tipGui          := 0       ; Anlık bildirim OSD penceresi

; Başlangıçta mikrofon kapalıysa bildirim göster
CheckInitialMicState()

; Başlangıç bildirimi
holdLabel := (holdAction = "PushToTalk") ? "Push-to-Talk" : activeAppName
ShowTip("✅ Copilot Tuşu v" APP_VERSION " aktif — " holdLabel, 2500)

; Başlangıçta güncelleme kontrolü (sessiz)
SetTimer(StartupUpdateCheck, -5000)

; ══════════════════════════════════════════
;  YARDIMCI: Özelleştirilebilir OSD bildirim
; ══════════════════════════════════════════
GetOsdPosition() {
    global osdPosition

    ; Ekran boyutlarını al
    screenW := A_ScreenWidth
    screenH := A_ScreenHeight

    switch osdPosition {
        case "TopRight":
            return {x: screenW - 300, y: 45}
        case "BottomLeft":
            return {x: 20, y: screenH - 80}
        case "BottomRight":
            return {x: screenW - 300, y: screenH - 80}
        case "Center":
            return {x: (screenW // 2) - 150, y: (screenH // 2) - 20}
        default:  ; TopLeft
            return {x: 20, y: 45}
    }
}

ShowTip(msg, durationMs := 0) {
    global tipGui, osdColor, osdFontSize, osdDurationMs, osdFadeEnabled, fadeAlpha

    ; Varsayılan süre config'den gelir
    if (durationMs = 0)
        durationMs := osdDurationMs

    ; Önceki fade-out ve gizleme zamanlayıcılarını iptal et
    SetTimer(FadeOutTipStep, 0)
    SetTimer(HideTipGui, 0)

    if (!IsObject(tipGui)) {
        transColor := "010101"
        tipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "CopilotTipGui")
        tipGui.BackColor := transColor
        WinSetTransColor(transColor, tipGui)
        tipGui.SetFont("s" osdFontSize " bold c" osdColor, "Segoe UI")
        tipGui.Add("Text", "vTipText x0 y0", msg)
    } else {
        tipGui["TipText"].Value := msg
    }

    pos := GetOsdPosition()
    tipGui.Show("x" pos.x " y" pos.y " NoActivate AutoSize")

    ; Fade-in animasyonu
    if (osdFadeEnabled) {
        fadeAlpha := 0
        try WinSetTransparent(0, tipGui)
        SetTimer(FadeInTipStep, -10)
    } else {
        fadeAlpha := 255
        try WinSetTransparent(255, tipGui)
    }

    ; Süre sonunda fade-out veya gizleme
    if (osdFadeEnabled) {
        SetTimer(StartFadeOut, -durationMs)
    } else {
        SetTimer(HideTipGui, -durationMs)
    }
}

FadeInTipStep() {
    global tipGui, fadeAlpha
    if (!IsObject(tipGui))
        return
    fadeAlpha += 25
    if (fadeAlpha >= 255) {
        fadeAlpha := 255
        try WinSetTransparent(255, tipGui)
        return
    }
    try WinSetTransparent(fadeAlpha, tipGui)
    SetTimer(FadeInTipStep, -10)
}

StartFadeOut() {
    SetTimer(FadeOutTipStep, -10)
}

FadeOutTipStep() {
    global tipGui, fadeAlpha
    if (!IsObject(tipGui))
        return
    fadeAlpha -= 20
    if (fadeAlpha <= 0) {
        fadeAlpha := 0
        tipGui.Hide()
        try WinSetTransparent(255, tipGui)
        return
    }
    try WinSetTransparent(fadeAlpha, tipGui)
    SetTimer(FadeOutTipStep, -15)
}

HideTipGui() {
    global tipGui
    if (IsObject(tipGui)) {
        tipGui.Hide()
        try WinSetTransparent(255, tipGui)
    }
}

; ══════════════════════════════════════════
;  TUŞA BASILMA ANI (Down)
; ══════════════════════════════════════════
$*<+<#f23::
{
    global isKeyDown, holdTriggered, holdThreshold, holdAction, pttActive

    if (isKeyDown)
        return

    isKeyDown     := true
    holdTriggered := false

    ; Tıklama sayacı zamanlayıcısını geçici olarak durdur
    SetTimer(CheckMultiPress, 0)

    ; Basılı tutma zamanlayıcısını başlat
    SetTimer(CheckHoldTimer, -holdThreshold)
}

; ══════════════════════════════════════════
;  TUŞUN BIRAKILMA ANI (Up)
; ══════════════════════════════════════════
$*<+<#f23 Up::
{
    global isKeyDown, doubleTapThreshold, holdTriggered, tapCount, holdAction, pttActive

    if (!isKeyDown)
        return

    isKeyDown := false
    SetTimer(CheckHoldTimer, 0)   ; Tuş bırakıldıysa hold timer'ı iptal et

    ; Push-to-Talk: tuş bırakıldığında mikrofonu sustur
    if (pttActive) {
        pttActive := false
        SetMicMute(true)
        ShowTip("🎙️ PTT — Mikrofon Susturuldu")
        return
    }

    ; Eğer basılı tutma eylemi zaten çalıştıysa, tıklama işlemlerini atla
    if (holdTriggered) {
        tapCount := 0
        return
    }

    ; Tıklama sayısını artır ve zamanlayıcıyı başlat
    tapCount++
    SetTimer(CheckMultiPress, -doubleTapThreshold)
}

; ══════════════════════════════════════════
;  TIKLAMA EYLEMLERİ (Özelleştirilebilir)
; ══════════════════════════════════════════
CheckMultiPress() {
    global tapCount, action1, action2, action3, action4

    count := tapCount
    tapCount := 0   ; Sayacı sıfırla

    ; Copilot donanımsal Win+Shift takılmasını önle
    Send "{LWin up}{LShift up}{RWin up}{RShift up}"

    ; Tık sayısına göre atanmış eylemi çalıştır
    switch count {
        case 1: RunAction(action1)
        case 2: RunAction(action2)
        case 3: RunAction(action3)
        case 4: RunAction(action4)
        default:
            ShowTip("⚠️ " count " Tık (Atanmış eylem yok)")
    }
}

; ══════════════════════════════════════════
;  EYLEM DİSPATCH — Tek noktadan yönetim
; ══════════════════════════════════════════
RunAction(actionName) {
    switch actionName {
        case "MicMute":
            ToggleMicrophoneMute()
        case "PlayPause":
            Send "{Media_Play_Pause}"
            SetTimer(ShowPlayPauseTrackInfo, -400)
        case "NextTrack":
            Send "{Media_Next}"
            ; Kısa gecikme sonrası güncel şarkı bilgisini göster
            SetTimer(ShowNextTrackInfo, -600)
        case "PrevTrack":
            Send "{Media_Prev}"
            SetTimer(ShowPrevTrackInfo, -600)
        case "VolumeUp":
            ShowTip("🔊 Ses Artırıldı")
            Send "{Volume_Up 5}"
        case "VolumeDown":
            ShowTip("🔉 Ses Azaltıldı")
            Send "{Volume_Down 5}"
        case "None":
            ; Eylem yok
        default:
            ShowTip("⚠️ Bilinmeyen eylem: " actionName)
    }
}

ShowPlayPauseTrackInfo() {
    nowPlaying := GetNowPlaying()
    if (nowPlaying != "")
        ShowTip("⏯️ " nowPlaying)
    else
        ShowTip("⏯️ Oynat / Duraklat")
}

ShowNextTrackInfo() {
    nowPlaying := GetNowPlaying()
    if (nowPlaying != "")
        ShowTip("⏭️ " nowPlaying)
    else
        ShowTip("⏭️ Sonraki Parça")
}

ShowPrevTrackInfo() {
    nowPlaying := GetNowPlaying()
    if (nowPlaying != "")
        ShowTip("⏮️ " nowPlaying)
    else
        ShowTip("⏮️ Önceki Parça")
}

; ══════════════════════════════════════════
;  NOW PLAYING — Aktif müzik pencere başlığı
; ══════════════════════════════════════════
GetNowPlaying() {
    global musicApp, ytmTitle, spotifyTitle

    targetTitle := (musicApp = "Spotify") ? spotifyTitle : ytmTitle

    try {
        if WinExist(targetTitle) {
            fullTitle := WinGetTitle(targetTitle)

            ; Spotify: "Şarkı Adı - Sanatçı" veya "Spotify Premium" / "Spotify Free"
            ; YTM: "Şarkı Adı - Sanatçı - YouTube Music" veya sadece "YouTube Music"
            if (musicApp = "Spotify") {
                ; "Spotify" tek kelimesiyle başlıyorsa çalmıyor demektir
                if (fullTitle = "Spotify" || fullTitle = "Spotify Premium" || fullTitle = "Spotify Free")
                    return ""
                return fullTitle
            } else {
                ; YTM: Sondaki " - YouTube Music" kısmını kaldır
                cleaned := RegExReplace(fullTitle, "\s*-\s*YouTube Music$", "")
                if (cleaned = "" || cleaned = "YouTube Music")
                    return ""
                return cleaned
            }
        }
    }
    return ""
}

; ══════════════════════════════════════════
;  MİKROFON SUSTURMA / AÇMA & SAĞ ÜST OSD
; ══════════════════════════════════════════
ToggleMicrophoneMute() {
    isMuted := false
    try {
        SoundSetMute(-1, , "Microphone")
        isMuted := SoundGetMute(, "Microphone")
    } catch {
        try {
            SoundSetMute(-1, "Master", "Capture")
            isMuted := SoundGetMute("Master", "Capture")
        } catch as err {
            ShowTip("⚠️ Mikrofon erişim hatası: " . err.Message, 2000)
            return
        }
    }

    ; Discord benzeri yumuşak ses efekti
    PlayMicSound(isMuted)

    if isMuted {
        ShowTip("🎙️ Mikrofon Susturuldu (MUTE)")
    } else {
        ShowTip("🎙️ Mikrofon Açıldı (UNMUTE)")
    }

    UpdateMicOverlay(isMuted)
    UpdateTrayIcon(isMuted)
}

PlayMicSound(isMuted) {
    if isMuted {
        ; Discord tarzı Mute sesi (Speech Off / Hardware Remove / Pop-up Blocked)
        if FileExist(A_WinDir "\Media\Speech Off.wav")
            SoundPlay A_WinDir "\Media\Speech Off.wav"
        else if FileExist(A_WinDir "\Media\Windows Pop-up Blocked.wav")
            SoundPlay A_WinDir "\Media\Windows Pop-up Blocked.wav"
        else
            SoundPlay "*16"
    } else {
        ; Discord tarzı Unmute sesi (Speech On / Navigation Start / Hardware Insert)
        if FileExist(A_WinDir "\Media\Speech On.wav")
            SoundPlay A_WinDir "\Media\Speech On.wav"
        else if FileExist(A_WinDir "\Media\Windows Navigation Start.wav")
            SoundPlay A_WinDir "\Media\Windows Navigation Start.wav"
        else
            SoundPlay "*64"
    }
}

CheckInitialMicState() {
    try {
        isMuted := SoundGetMute(, "Microphone")
        UpdateMicOverlay(isMuted)
        UpdateTrayIcon(isMuted)
    } catch {
        try {
            isMuted := SoundGetMute("Master", "Capture")
            UpdateMicOverlay(isMuted)
            UpdateTrayIcon(isMuted)
        }
    }
}

; ══════════════════════════════════════════
;  MİKROFON DURUMUNA GÖRE TRAY İKONU
; ══════════════════════════════════════════
UpdateTrayIcon(isMuted) {
    global trayIconMicState
    if (!trayIconMicState)
        return

    if (isMuted) {
        if FileExist(A_ScriptDir "\logo_muted.ico")
            TraySetIcon A_ScriptDir "\logo_muted.ico"
    } else {
        if FileExist(A_ScriptDir "\logo.ico")
            TraySetIcon A_ScriptDir "\logo.ico"
    }
}

; ══════════════════════════════════════════
;  MİKROFON DOĞRUDAN AYARLAMA (PTT için)
; ══════════════════════════════════════════
SetMicMute(muteState) {
    try {
        SoundSetMute(muteState, , "Microphone")
    } catch {
        try {
            SoundSetMute(muteState, "Master", "Capture")
        }
    }
    UpdateMicOverlay(muteState)
    UpdateTrayIcon(muteState)
}

UpdateMicOverlay(isMuted) {
    global micOverlayGui

    if (isMuted) {
        if (!IsObject(micOverlayGui)) {
            transColor := "010101"
            micOverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "MicMuteOverlay")
            micOverlayGui.BackColor := transColor
            WinSetTransColor(transColor, micOverlayGui)
            micOverlayGui.SetFont("s11 bold cFF4444", "Segoe UI")
            micOverlayGui.Add("Text", "x0 y0", "🔴 MİKROFON KAPALI")
        }
        ; Sol üst köşede (x: 20, y: 15) arkaplansız saydam olarak göster
        micOverlayGui.Show("x20 y15 NoActivate AutoSize")
    } else {
        if (IsObject(micOverlayGui)) {
            micOverlayGui.Hide()
        }
    }
}

; ══════════════════════════════════════════
;  BASILI TUTMA — Müzik Uygulaması / PTT
; ══════════════════════════════════════════
CheckHoldTimer() {
    global holdTriggered, holdAction, pttActive
    global musicApp, ytmUrl, ytmTitle, spotifyCmd, spotifyTitle

    holdTriggered := true
    SetTimer(CheckHoldTimer, 0)

    ; Tuş takılmalarını önle
    Critical
    Send "{LWin up}{LShift up}{RWin up}{RShift up}"
    Critical False

    ; Push-to-Talk modu
    if (holdAction = "PushToTalk") {
        pttActive := true
        SetMicMute(false)
        PlayMicSound(false)
        ShowTip("🎙️ PTT — Mikrofon Açık (konuş...)")
        return
    }

    ; Özel uygulama / URL modu
    if (holdAction = "CustomApp") {
        if (customAppPath != "") {
            try {
                Run customAppPath
                ; Dosya adını veya URL'yi OSD'de göster
                displayName := RegExReplace(customAppPath, "^.*\\", "")  ; Son \\ sonrasını al
                if (displayName = "")
                    displayName := customAppPath
                ShowTip("🚀 " displayName " açılıyor...")
            } catch as err {
                ShowTip("⚠️ Açılamadı: " err.Message, 2500)
            }
        } else {
            ShowTip("⚠️ Özel uygulama yolu ayarlanmamış!", 2500)
        }
        return
    }

    ; Müzik uygulaması modu
    if (musicApp = "Spotify") {
        if WinExist(spotifyTitle) {
            WinActivate spotifyTitle
            ShowTip("🎧 Spotify öne getirildi")
        } else {
            try {
                Run spotifyCmd
            } catch {
                Run "spotify.exe"
            }
            ShowTip("🎧 Spotify açılıyor...")
        }
    } else {
        if WinExist(ytmTitle) {
            WinActivate ytmTitle
            ShowTip("🎵 YouTube Music öne getirildi")
        } else {
            Run ytmUrl
            ShowTip("🎵 YouTube Music açılıyor...")
        }
    }
}

; ══════════════════════════════════════════
;  WINDOWS BAŞLANGIÇ KISAYOLU
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
        appsUseLight := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
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
;  GÖRSEL AYARLAR PENCERESİ (AHK GUI)
; ══════════════════════════════════════════
ShowSettingsGUI(*) {
    global settingsGui, configFile, doubleTapThreshold, holdThreshold, musicApp, autoStart, ytmUrl, ytmTitle, spotifyCmd, spotifyTitle, osdPosition, osdColor, osdFontSize, osdDurationMs, osdFadeEnabled, holdAction, action1, action2, action3, action4, trayIconMicState, customAppPath, themeMode

    if (IsObject(settingsGui)) {
        settingsGui.Show()
        return
    }

    isDark := (GetEffectiveTheme() = "Dark")

    ; Renk Tanımları
    if (isDark) {
        bgColor     := "1E1E1E"   ; Koyu modern gri (Windows 11 Dark Mode)
        textColor   := "FFFFFF"   ; Beyaz metin
        editBgColor := "2B2B2B"   ; Koyu input arka planı
    } else {
        bgColor     := "F5F5F5"
        textColor   := "111111"
        editBgColor := "FFFFFF"
    }
    editOpt := "Background" editBgColor " c" textColor

    settingsGui := Gui("+AlwaysOnTop +Owner", "⚙️ Copilot Tuşu Ayarları")
    settingsGui.BackColor := bgColor
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")

    ; --- Müzik Uygulaması Seçimi ---
    settingsGui.Add("GroupBox", "x12 y10 w360 h60", "🎵 Hedef Müzik Uygulaması")
    radYtm     := settingsGui.Add("Radio", "x26 y32 w150 h20 Checked" (musicApp = "YTM" ? "1" : "0"), "YouTube Music")
    radSpotify := settingsGui.Add("Radio", "x180 y32 w150 h20 Checked" (musicApp = "Spotify" ? "1" : "0"), "Spotify")

    ; --- Tıklama & Başlangıç Ayarları ---
    settingsGui.Add("GroupBox", "x12 y75 w360 h120", "⏱️ Zamanlama & Başlangıç Ayarları")
    settingsGui.Add("Text",     "x26 y95 w180 h20", "Tıklama Bekleme Süresi (ms):")
    edtDoubleTap := settingsGui.Add("Edit", "x210 y92 w140 h22 Number " editOpt, doubleTapThreshold)
    
    settingsGui.Add("Text",     "x26 y130 w180 h20", "Basılı Tutma Eşik Süresi (ms):")
    edtHold := settingsGui.Add("Edit", "x210 y127 w140 h22 Number " editOpt, holdThreshold)

    chkAuto := settingsGui.Add("Checkbox", "x26 y162 w320 h20 Checked" (autoStart ? "1" : "0"), "Windows açıldığında otomatik başlat")

    ; --- Uygulama Özel Ayarları ---
    settingsGui.Add("GroupBox", "x12 y200 w360 h150", "⚙️ Uygulama Başlık & Komut Ayarları")
    
    settingsGui.Add("Text",     "x26 y225 w120 h20", "YTM URL / Komut:")
    edtYtmUrl := settingsGui.Add("Edit", "x150 y222 w200 h22 " editOpt, ytmUrl)

    settingsGui.Add("Text",     "x26 y255 w120 h20", "YTM Başlık:")
    edtYtmTitle := settingsGui.Add("Edit", "x150 y252 w200 h22 " editOpt, ytmTitle)

    settingsGui.Add("Text",     "x26 y285 w120 h20", "Spotify Komut:")
    edtSpotCmd := settingsGui.Add("Edit", "x150 y282 w200 h22 " editOpt, spotifyCmd)

    settingsGui.Add("Text",     "x26 y315 w120 h20", "Spotify Başlık:")
    edtSpotTitle := settingsGui.Add("Edit", "x150 y312 w200 h22 " editOpt, spotifyTitle)

    ; --- OSD Bildirim & Tema Ayarları ---
    settingsGui.Add("GroupBox", "x12 y355 w360 h205", "💬 OSD & Görünüm Ayarları")

    settingsGui.Add("Text", "x26 y378 w120 h20", "Arayüz Teması:")
    ddlTheme := settingsGui.Add("DropDownList", "x150 y375 w200 h22 " editOpt, ["Dark", "Light", "Auto"])
    ddlTheme.Text := themeMode

    settingsGui.Add("Text", "x26 y408 w120 h20", "OSD Konumu:")
    ddlPos := settingsGui.Add("DropDownList", "x150 y405 w200 h22 " editOpt, ["TopLeft", "TopRight", "BottomLeft", "BottomRight", "Center"])
    ddlPos.Text := osdPosition

    settingsGui.Add("Text", "x26 y438 w120 h20", "Metin Rengi (hex):")
    edtOsdColor := settingsGui.Add("Edit", "x150 y435 w200 h22 " editOpt, osdColor)

    settingsGui.Add("Text", "x26 y468 w120 h20", "Font Boyutu:")
    edtOsdSize := settingsGui.Add("Edit", "x150 y465 w200 h22 Number " editOpt, osdFontSize)

    settingsGui.Add("Text", "x26 y498 w120 h20", "Gösterim Süresi (ms):")
    edtOsdDur := settingsGui.Add("Edit", "x150 y495 w200 h22 Number " editOpt, osdDurationMs)

    chkFade := settingsGui.Add("Checkbox", "x26 y528 w320 h20 Checked" (osdFadeEnabled ? "1" : "0"), "Fade (solma) animasyonu kullan")

    ; --- Basılı Tutma & Tray İkonu ---
    settingsGui.Add("GroupBox", "x12 y565 w360 h105", "🎤 Basılı Tutma & Tray İkonu")

    settingsGui.Add("Text", "x26 y588 w120 h20", "Basılı Tutma:")
    ddlHold := settingsGui.Add("DropDownList", "x150 y585 w200 h22 " editOpt, ["MusicApp", "PushToTalk", "CustomApp"])
    ddlHold.Text := holdAction

    settingsGui.Add("Text", "x26 y618 w120 h20", "Uygulama / URL:")
    edtCustomApp := settingsGui.Add("Edit", "x150 y615 w200 h22 " editOpt, customAppPath)

    chkTrayMic := settingsGui.Add("Checkbox", "x26 y645 w320 h20 Checked" (trayIconMicState ? "1" : "0"), "Mikrofon durumuna göre tray ikonu değiştir")

    ; --- Eylem Atamaları ---
    actionList := ["MicMute", "PlayPause", "NextTrack", "PrevTrack", "VolumeUp", "VolumeDown", "None"]

    settingsGui.Add("GroupBox", "x12 y675 w360 h145", "⌨️ Tık Eylem Atamaları")

    settingsGui.Add("Text", "x26 y698 w120 h20", "1 Tık:")
    ddlAct1 := settingsGui.Add("DropDownList", "x150 y695 w200 h22 " editOpt, actionList)
    ddlAct1.Text := action1

    settingsGui.Add("Text", "x26 y728 w120 h20", "2 Tık:")
    ddlAct2 := settingsGui.Add("DropDownList", "x150 y725 w200 h22 " editOpt, actionList)
    ddlAct2.Text := action2

    settingsGui.Add("Text", "x26 y758 w120 h20", "3 Tık:")
    ddlAct3 := settingsGui.Add("DropDownList", "x150 y755 w200 h22 " editOpt, actionList)
    ddlAct3.Text := action3

    settingsGui.Add("Text", "x26 y788 w120 h20", "4 Tık:")
    ddlAct4 := settingsGui.Add("DropDownList", "x150 y785 w200 h22 " editOpt, actionList)
    ddlAct4.Text := action4

    ; --- Butonlar ---
    btnSave := settingsGui.Add("Button", "x140 y835 w110 h30 Default", "💾 Kaydet & Yenile")
    btnSave.OnEvent("Click", (*) => SaveAndReload())

    btnCancel := settingsGui.Add("Button", "x260 y835 w110 h30", "❌ İptal")
    btnCancel.OnEvent("Click", (*) => (settingsGui.Destroy(), settingsGui := 0))

    settingsGui.OnEvent("Close", (*) => (settingsGui.Destroy(), settingsGui := 0))

    ; Windows Dark Mode Başlık Çubuğu & Kontrol Teması Uygula
    SetWindowDarkMode(settingsGui.Hwnd, isDark)
    ApplyThemeToControls(settingsGui, isDark)

    settingsGui.Show("w384 h880")

    SaveAndReload() {
        newApp    := radSpotify.Value ? "Spotify" : "YTM"
        newDouble := Integer(edtDoubleTap.Value)
        newHold   := Integer(edtHold.Value)
        newAuto   := chkAuto.Value ? 1 : 0
        newYtmUrl := Trim(edtYtmUrl.Value)
        newYtmTitle  := Trim(edtYtmTitle.Value)
        newSpotCmd   := Trim(edtSpotCmd.Value)
        newSpotTitle := Trim(edtSpotTitle.Value)

        ; OSD & Tema Ayarları
        newTheme    := ddlTheme.Text
        newOsdPos   := ddlPos.Text
        newOsdColor := Trim(edtOsdColor.Value)
        newOsdSize  := Integer(edtOsdSize.Value)
        newOsdDur   := Integer(edtOsdDur.Value)
        newFade     := chkFade.Value ? 1 : 0

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

        IniWrite(newApp,       configFile, "Settings", "MusicApp")
        IniWrite(newDouble,    configFile, "Settings", "DoubleTapMs")
        IniWrite(newHold,      configFile, "Settings", "HoldMs")
        IniWrite(newAuto,      configFile, "Settings", "AutoStart")
        IniWrite(newYtmUrl,    configFile, "Settings", "YtmURL")
        IniWrite(newYtmTitle,  configFile, "Settings", "YtmWindowTitle")
        IniWrite(newSpotCmd,   configFile, "Settings", "SpotifyCmd")
        IniWrite(newSpotTitle, configFile, "Settings", "SpotifyWindowTitle")

        ; OSD & Tema Ayarları kaydet
        IniWrite(newTheme,     configFile, "Settings", "Theme")
        IniWrite(newOsdPos,    configFile, "Settings", "OsdPosition")
        IniWrite(newOsdColor,  configFile, "Settings", "OsdColor")
        IniWrite(newOsdSize,   configFile, "Settings", "OsdFontSize")
        IniWrite(newOsdDur,    configFile, "Settings", "OsdDurationMs")
        IniWrite(newFade,      configFile, "Settings", "OsdFadeEnabled")

        ; Basılı Tutma & Tray İkonu kaydet
        IniWrite(ddlHold.Text,              configFile, "Settings", "HoldAction")
        IniWrite(Trim(edtCustomApp.Value),  configFile, "Settings", "CustomAppPath")
        IniWrite(chkTrayMic.Value ? 1 : 0,  configFile, "Settings", "TrayIconMicState")

        ; Eylem Atamaları kaydet
        IniWrite(ddlAct1.Text, configFile, "Settings", "Action1")
        IniWrite(ddlAct2.Text, configFile, "Settings", "Action2")
        IniWrite(ddlAct3.Text, configFile, "Settings", "Action3")
        IniWrite(ddlAct4.Text, configFile, "Settings", "Action4")

        SetStartupShortcut(newAuto)

        settingsGui.Destroy()
        settingsGui := 0
        ShowTip("✅ Ayarlar kaydedildi! Yenileniyor...")
        Sleep 500
        Reload()
    }
}

; ══════════════════════════════════════════
;  VARSAYILAN CONFIG DOSYASI OLUŞTURMA
; ══════════════════════════════════════════
CreateDefaultConfig(path) {
    defaultConfig := "
    (LTrim
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

    ; ── OSD & Görünüm Ayarları ──

    ; Arayüz Teması: Dark (Karanlık), Light (Aydınlık), Auto (Sistem Teması)
    Theme=Dark

    ; OSD Konumu: TopLeft, TopRight, BottomLeft, BottomRight, Center
    OsdPosition=TopLeft

    ; OSD Metin Rengi (hex, # olmadan)
    OsdColor=00E5FF

    ; OSD Font Boyutu (varsayılan: 10)
    OsdFontSize=10

    ; OSD Gösterim Süresi (milisaniye, varsayılan: 1500)
    OsdDurationMs=1500

    ; OSD Fade Animasyonu (1 = Açık, 0 = Kapalı)
    OsdFadeEnabled=1

    ; ── Basılı Tutma Eylemi ──

    ; HoldAction: MusicApp (müzik uygulamasını aç), PushToTalk (bas-konuş), CustomApp (özel uygulama/URL)
    HoldAction=MusicApp

    ; CustomApp seçildiğinde açılacak uygulama yolu veya URL
    ; Örnek: C:\Program Files\Discord\Discord.exe veya https://google.com
    CustomAppPath=

    ; ── Tık Eylem Atamaları ──
    ; Seçenekler: MicMute, PlayPause, NextTrack, PrevTrack, VolumeUp, VolumeDown, None

    ; 1 Tık Eylemi
    Action1=MicMute

    ; 2 Tık Eylemi
    Action2=PlayPause

    ; 3 Tık Eylemi
    Action3=NextTrack

    ; 4 Tık Eylemi
    Action4=PrevTrack

    ; ── Tray İkonu ──

    ; Mikrofon durumuna göre tray ikonu değiştir (1 = Açık, 0 = Kapalı)
    TrayIconMicState=1
    )"

    try FileAppend(defaultConfig, path)
}

; ══════════════════════════════════════════
;  ÖZEL KLASÖR KURULUM FONKSİYONU
; ══════════════════════════════════════════
EnsureInstalledLocation() {
    localAppData := EnvGet("LOCALAPPDATA")
    if (localAppData = "")
        localAppData := A_AppData "\..\Local"
    installDir := localAppData "\CopilotButton"
    
    ; Zaten özel klasördeyse ikonları kontrol et ve çık
    if (StrLower(A_ScriptDir) = StrLower(installDir)) {
        EnsureDefaultIcons(installDir)
        return
    }

    try {
        if (!DirExist(installDir))
            DirCreate(installDir)

        targetFile := installDir "\" A_ScriptName

        ; Çalışan dosyayı özel klasöre kopyala
        FileCopy(A_ScriptFullPath, targetFile, true)

        ; Varsa ikonları kopyala
        if FileExist(A_ScriptDir "\logo.ico")
            FileCopy(A_ScriptDir "\logo.ico", installDir "\logo.ico", true)
        if FileExist(A_ScriptDir "\logo_muted.ico")
            FileCopy(A_ScriptDir "\logo_muted.ico", installDir "\logo_muted.ico", true)
        if FileExist(A_ScriptDir "\config.ini") && !FileExist(installDir "\config.ini")
            FileCopy(A_ScriptDir "\config.ini", installDir "\config.ini", true)

        ; Eksik ikonları gömülü Base64'ten otomatik üret
        EnsureDefaultIcons(installDir)

        ; Başlangıç kısayolunu güncelle
        shortcutPath := A_Startup "\CopilotButton.lnk"
        if FileExist(shortcutPath)
            try FileCreateShortcut(targetFile, shortcutPath, installDir)

        ; Yeni konumdan çalıştır ve mevcut örneği kapat
        Run('"' . targetFile . '"', installDir)
        ExitApp()
    }
}

; ══════════════════════════════════════════
;  GÖMÜLÜ İKONLARI DOSYAYA ÇIKARMA
; ══════════════════════════════════════════
EnsureDefaultIcons(dir) {
    logoPath := dir "\logo.ico"
    mutedPath := dir "\logo_muted.ico"

    if (!FileExist(logoPath)) {
        b64Logo := "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sJ0GTSQ9zU7Jr0+ZIOEVKd15G9bR4zjbB6Eta+5aJFx1deHd/3WCxd2I6ZciiuD8dQjnmQ0Q5JHhDERmRuSIUUBqNPTUJqg3gSiVKX/iepzd+xCFAtptj0+SyVLYsA7/6vm4I2XkWY11egL3sR8y8Y07COfPx/3XKVp1tr0HA1sVb0d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2/W08g7fAynwBAAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAyNi0wOC0xM1QxOTozMjozNCswMzowMMeSbhAAAAAldEVYdGRhdGU6bW9kaWZ5ADIwMjYtMDgtMTNUMTk6MzI6MzQrMDM6MDD31FwYAAAAAElFTkSuQmCC"
        SaveBase64ToFile(b64Logo, logoPath)
    }

    if (!FileExist(mutedPath)) {
        b64Muted := "AAABAAQAEBAAAAAAIABtAgAARgAAABgYAAAAACAAVAQAALMCAAAgIAAAAAAgAJEGAAAHBwAAMDAAAAAAIACiCwAAmA0AAIlQTkcNChoKAAAADUlIRFIAAAAQAAAAEAgGAAAAH/P/YQAAAjRJREFUeJylk71rFEEYh5+Z3b29vVy+jSKiJFrY+FEY/D8sFDQgsdTGIvkXxDI2FsFKRQQbS1uRVEEbW4WAGoJg4iUxd7vz9cpsLrmzdmCHgf39nnfej1EiIvzHSqNfKcWr12/5+OkzraIgy1LyRoNGlgKCsY7SGJx1dLs95uevsnD7BtGbRvPzF29YXHzI2NQkeSOnKHIaeQ5ZVkeRaK4q9nsV1lQ8WVnFWsvi3VvoKPiwtk7WKpiammB8bIRmq8VMq8nCdM6dEzmn2gVSFJycGOX09CRZUbC2tl7Ddb0lmuA9ZVlRliW/D7pckwPO9DrM9jpctH+Y9Jbl0UBZlXjv0UlyWAOA4AMhSA0xHpwKaOPpqoSeCDPA0njKytY+u06DCCH4AUAk1F+IDQmBSgIHpcd7YUs019tNHm/u8cXAZCrsRm2QYYDUVAkBH4QM4d1eYGQ85fJIyqPNfb4aGNdgQ2049BzVQPo9FQQtnq73NLXmUp7wq2f4bgJtFbBSu/vioRsQBrROgPOZ4l47UJiSKwpCjVaD6Yny4RvQ/10KXEjhQcvydMfijKFjDFUA3U9T1cEicAigol2ENsLNrGR1T/gRUoKzdK3D96OroaGPA3icgnWu7muSaJ5VTUqtaWnFe5fW1maSoLXUgCTqdIK1bgCYmz2LNzv83FE474kjEoO97EfUqmI7nhWkSYK327Xn+DEtL93HGMPGxjfSLP23RUc1VoepOueYmztXe6JM/e9z/gtxNTGne5yCOgAAAABJRU5ErkJggolQTkcNChoKAAAADUlIRFIAAAAYAAAAGAgGAAAA4Hc9+AAABBtJREFUeJyllc+LHEUUxz9V3T0zu9lhdjc/FKLGPyDgj0OUBLyJguJFJHgU0eSgKDGrtxBIAnrw15KDXrx41EsgB0/qyYMgLAGP7mqMgWx2duPuTs9M1y+p192TmdnFgxZTU1Vdr77vve979UqFEAJVc86RJAn/p7kpDDWuoBYYDIYopUB+qhSUoZxDIJ4KyF/5JQRareYeA9MaP47LV7/im2+v45wna2RkWUYzy2TeiOtEi6yxjsIYisIwLAw2zo0R8FdefoF33n69NDAq8N7LxseffsnS+5c4eOhgCVYDZ3VPCUqJwdoHCmsZFoUA28JgjJX5ufcuCgvnz52VUSiKlDx18kX+uPkXc+05tFICmmap9CxJsVpzuJEKV3eHhsQ78cRbS78wMkYWtnd2efTYUX7+6TrNZpM0upHnffJ+Xyi21qB1IpxHa+Ohgfa81Ml4rOVkfUNprm0VNL3nXmFoRxnnKKLFSpHnA3q9XBSUpAoQBB/wPohr1kXrDNtDw3FteEbn3N3Zobvb45Tv8Xji+K034ERL8/XRDOUtNsTg+yrwVQzqrIixEIvjqBTWxhSDAk/be24NFbmDoKAb+R5YTsxkXD2S8sbaJl0DB7SiCB4fnGCOFIj1wYv79TzuWwI2KJT1NFxCOyhmlaZbWI41Ez5ZzHhtdZMfcjikwfp4TuErnAkPynQNshmbx6OtFiW7hcckjq6DVWvZ0A0uPNji7GqXH/uKIwkM/X2uI9W1BxKDOC21lhtxjGsbPGnw3OhbkuDRzpDrjIsPzPLWWmn5YQ0DV3FPpDn2+3e3DHKZLpUBkaroaqkkDZ7bBr7YMqyrjDcXm5xZ2+T7XhBaBkJLeWZUFPajaLLV3iClou8CndkGp9sJ323lWDQzypecT9hbZc/YhxFFUyWp1K6g6zynZlOuLMC1rT6vzig6wVFUdE63mHlIRob9KRoH37SBp2cSrsw7PlrvcboJbTPgtg1ke6Ar8CmP0innpMV62LWBE62ED9uGd+841n3Cghtyx0HfJ+igS8PkyocSvAYYq7Kjm1x7oUMgd4GTTcWl2T5LG5YV26AhHjn61pF7SCJYAOUr8IkI/osHLkBHw5lGzoV7ml98i0Ud2A2xTFuRG4SGyMZbXYNNK5lUEF2shOPBWFOWdjK2yVhQgXjxi6D43TjZH6CExjBOz5iRMfPqSIgCnSaS8zrRUqodGqs0B+TqlG9aohQfDOdKXpUugeqiVnEfK6nWWupaWr1sOi4WFjo8+cRxtjc3ZNM7R6jKur616XPe8lh7nbqzXMvHs31sbgjU/3ykV1RYtf3ZZnsCVlV/Fi/0pDZX7e1tkKwI+9/yzLH9+eeTJnkf/5p+3yo0yjPtBjb5PZGaca80jDz80KV0riA+N1uPi/72NY/0Dc2+mMF1WxzAAAAAASUVORK5CYIKJUE5HDQoaCgAAAA1JSERSAAAAIAAAACAIBgAAAHN6evQAAAbcSURBVHicxZcNjFxVFcd/976P2Znddi3Wli1dCdlqKIYgLXSlK7aEsMRSjOAqfgSMhk0xYjGCEqltqkbSxI80GooFFCSRNAEhqVpoScsuraWtWqItibWlpF36sduv7c7svpk3791r7nvz8ebtLCaGxDvZnTv343/+95xzzz1HaK01iWZ+KRVG30LwvrQqlpQSkQIVSQKmm17wfre0DLvZxJ/+vI3Xd75BPj9eGTMcq5uS/f/+2+BOa2vlUzfewPLlvRFeUpYwGqgOnD17jv4VD7Lt1YHot/k02KdJq9KL+hW5kU6FAY+/tdKYT+8tS3ly48+ZOfODKKWRUiCUUrpq98/fdS9bXt5OR8dstFYxUEJQ9V/Nakml1EhUTpgiJoTk1Klhli27mec3PYWUVkRAhibMuq9sfY1trw4yp2M25XKZMAwn/QVBSGD6QKg0YRASlkNCrStjiiAI4rWpfQbTYG/bOsArW3dEMs2crNIcfP0vEVOlVF2NKcsiLSgHiPOjCM8DywbbRkwUEecvgh/Ea6ZoBltIwcDg7poMu+oM+XwhVt9Uu80VGssTfqSL0pfuIOhegGpvj1U8Noazdz8tm15CHj6Kbs0Z54rsnj6EkWFkVU1jp6zcvAkJEyW8b99HccU9WAcP4W7ZgTx+Ij5Z5xz83qWM3v0FWtc/hfub36Eto4mkJyTx6l170lzkMAlHMyefKDH+s7X4vTfRdv/3sXfugdCoW9Ycs+WJZ5n45U/xfvQQom0uzq8ejc2RtmWq2ekBs74u3EKMFSiu7Mdf3kt7712IoSF0LovAjdn65cgv0Ao5WsJ6O6D86S8iDp/E3rwRsq0QhikFNwlEVFRVmzLg5TLq8rl4K/tpfWA14thxmJZFGEDjjH6AuqyD8LprCW66laDnVsQoyGMeLHkA/bdBxMgRsJ0GTSQ9zU7Jr0+ZIOEVKd15G9bR4zjbB6Eta+5aJFx1deHd/3WCxd2I6ZciiuD8dQjnmQ0Q5JHhDERmRuSIUUBqNPTUJqg3gSiVKX/iepzd+xCFAtptj0+SyVLYsA7/6vm4I2XkWY11egL3sR8y8Y07COfPx/3XKVp1tr0HA1sVb0d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2c2d2fDDAEAgAAAABjVBMVEUAAAAAAAAAAAAAYQ12AAAADXRSTlMA/////wD////v3+8gAP7ePzAAAAABYktHRADwA3bDAAAAAmZLRH0AAy5r34AAAAC7SURBVCjPY/h/n4EAYADi//9oYBi1bBSQBAwM//8zIBtrDDIAGRj+M4hAMDAwfP/PwMDw/z8DAwMDw/8/DAwcwAzwz0AGBjYGhv9/wCRqgAcDA8OfP3h1MgAzsTAwMDCsX8DAwPz3DxR3fQYGFoZ/fxgY3P78xWshsBvw6x+x4dZ/uIH89x/h9o2z4bA7EAEzMDCA3MD4/x+54cAqAPmDA4j/fzMwcAD9yA7i/zEw/P3PAAcQ48eP3wyMTf0A1x52aC0T1KMAAAAASUVORK5CYII="
        SaveBase64ToFile(b64Muted, mutedPath)
    }
}

SaveBase64ToFile(b64, filePath) {
    if FileExist(filePath)
        return
    try {
        buf := Buffer(StrLen(b64))
        size := 0
        if DllCall("crypt32\CryptStringToBinaryW", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", buf, "UInt*", &size := buf.Size, "Ptr", 0, "Ptr", 0) {
            file := FileOpen(filePath, "w")
            file.RawWrite(buf, size)
            file.Close()
        }
    }
}

; ══════════════════════════════════════════
;  GITHUB OTOMATİK GÜNCELLEME SİSTEMİ
; ══════════════════════════════════════════
StartupUpdateCheck() {
    CheckForUpdates(true)
}

CheckForUpdates(silent := true) {
    global APP_VERSION

    try {
        ; GitHub API'den son release bilgisini çek
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

        if (latestVersion = currentVersion) {
            if (!silent)
                ShowTip("✅ Zaten güncel sürümdesiniz (v" . currentVersion . ")")
            return
        }

        ; Release asset'leri içinde .exe var mı kontrol et
        exeUrl := ""
        if RegExMatch(responseText, '"browser_download_url"\s*:\s*"([^"]+\.exe)"', &exeMatch)
            exeUrl := exeMatch[1]

        ; Zip bağlantısını kontrol et
        zipUrl := ""
        if RegExMatch(responseText, '"browser_download_url"\s*:\s*"([^"]+\.zip)"', &zipMatch)
            zipUrl := zipMatch[1]
        else if RegExMatch(responseText, '"zipball_url"\s*:\s*"([^"]+)"', &zipMatch)
            zipUrl := zipMatch[1]

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

        updateMsg .= "`nGüncellemek ister misiniz?"

        result := MsgBox(updateMsg, "🔄 Güncelleme Mevcut — v" . latestVersion, "YesNo Icon!")
        if (result = "Yes") {
            if (exeUrl != "")
                PerformExeUpdate(exeUrl, latestVersion)
            else if (zipUrl != "")
                PerformZipUpdate(zipUrl, latestVersion)
            else
                ShowTip("⚠️ İndirme bağlantısı bulunamadı!", 2500)
        }

    } catch as err {
        if (!silent)
            ShowTip("⚠️ Güncelleme kontrolü hatası: " . err.Message, 2500)
    }
}

PerformExeUpdate(exeUrl, newVersion) {
    tempDir := A_ScriptDir "\update_temp"
    tempExe := tempDir "\update.exe"
    targetExe := A_ScriptFullPath

    ShowTip("⬇️ v" . newVersion . " (.exe) indiriliyor...", 5000)

    try {
        if DirExist(tempDir)
            try DirDelete(tempDir, true)
        DirCreate(tempDir)

        Download(exeUrl, tempExe)

        if !FileExist(tempExe) {
            ShowTip("⚠️ İndirme başarısız!", 2500)
            return
        }

        ; Batch updater betiği oluştur
        batFile := tempDir "\update.bat"
        batContent := "@echo off`r`ntimeout /t 2 /nobreak > nul`r`ncopy /y `"" . tempExe . "`" `"" . targetExe . "`"`r`nstart `"`" `"" . targetExe . "`"`r`nrmdir /s /q `"" . tempDir . "`""
        
        FileOpen(batFile, "w").Write(batContent)

        ShowTip("✅ v" . newVersion . " indirildi! Yeniden başlatılıyor...", 3000)
        Sleep 1500
        Run('cmd.exe /c "' . batFile . '"',, "Hide")
        ExitApp()

    } catch as err {
        ShowTip("⚠️ Güncelleme hatası: " . err.Message, 3000)
        try DirDelete(tempDir, true)
    }
}

PerformZipUpdate(zipUrl, newVersion) {
    tempDir := A_ScriptDir "\update_temp"
    zipFile := tempDir "\update.zip"
    extractDir := tempDir "\extracted"

    ShowTip("⬇️ v" . newVersion . " (zip) indiriliyor...", 5000)

    try {
        if DirExist(tempDir)
            try DirDelete(tempDir, true)
        DirCreate(tempDir)
        DirCreate(extractDir)

        Download(zipUrl, zipFile)

        if !FileExist(zipFile) {
            ShowTip("⚠️ İndirme başarısız!", 2500)
            return
        }

        ; PowerShell ile zip'ı aç (AHK v2 dizgi birleştirme formatına uygun)
        psCmd := 'powershell -NoProfile -Command "Expand-Archive -Path `"' . zipFile . '`" -DestinationPath `"' . extractDir . '`" -Force"'
        RunWait(psCmd,, "Hide")

        innerDir := ""
        loop files extractDir "\*", "D" {
            innerDir := A_LoopFileFullPath
            break
        }
        if (innerDir = "")
            innerDir := extractDir

        ; İçinde .exe var mı bak
        foundExe := ""
        loop files innerDir "\*.exe", "F" {
            foundExe := A_LoopFileFullPath
            break
        }

        if (foundExe != "") {
            targetExe := A_ScriptFullPath
            batFile := tempDir "\update.bat"
            batContent := "@echo off`r`ntimeout /t 2 /nobreak > nul`r`ncopy /y `"" . foundExe . "`" `"" . targetExe . "`"`r`nstart `"`" `"" . targetExe . "`"`r`nrmdir /s /q `"" . tempDir . "`""
            
            FileOpen(batFile, "w").Write(batContent)
            ShowTip("✅ v" . newVersion . " indirildi! Yeniden başlatılıyor...", 3000)
            Sleep 1500
            Run('cmd.exe /c "' . batFile . '"',, "Hide")
            ExitApp()
        } else {
            updatedFiles := 0
            loop files innerDir "\*.*", "FR" {
                if (A_LoopFileName = "config.ini")
                    continue
                targetPath := A_ScriptDir "\" A_LoopFileName
                try {
                    FileCopy(A_LoopFileFullPath, targetPath, true)
                    updatedFiles++
                }
            }

            try DirDelete(tempDir, true)

            if (updatedFiles > 0) {
                ShowTip("✅ v" . newVersion . " güncellendi! Yeniden başlatılıyor...", 3000)
                Sleep 1500
                Reload()
            } else {
                ShowTip("⚠️ Güncellenecek dosya bulunamadı", 2500)
            }
        }

    } catch as err {
        ShowTip("⚠️ Güncelleme hatası: " . err.Message, 3000)
        try DirDelete(tempDir, true)
    }
}