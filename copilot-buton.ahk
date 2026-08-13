#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook

global APP_VERSION := "1.0.0"

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

; OSD Ayarları
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
global osdFontSize, osdDurationMs, osdFadeEnabled, trayIconMicState
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
            nowPlaying := GetNowPlaying()
            if (nowPlaying != "")
                ShowTip("⏸️ Şarkı Durduruldu / Başlatıldı")
            else
                ShowTip("⏸️ " nowPlaying)
            Send "{Media_Play_Pause}"
        case "NextTrack":
            Send "{Media_Next}"
            ; Kısa gecikme sonrası güncel şarkı bilgisini göster
            SetTimer(ShowNextTrackInfo, -600)
        case "PrevTrack":
            ShowTip("⏮️ Önceki Parça")
            Send "{Media_Prev}"
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

ShowNextTrackInfo() {
    nowPlaying := GetNowPlaying()
    if (nowPlaying != "")
        ShowTip("⏭️ " nowPlaying)
    else
        ShowTip("⏭️ Sonraki Parça")
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
;  GÖRSEL AYARLAR PENCERESİ (AHK GUI)
; ══════════════════════════════════════════
ShowSettingsGUI(*) {
    global settingsGui, configFile, doubleTapThreshold, holdThreshold, musicApp, autoStart, ytmUrl, ytmTitle, spotifyCmd, spotifyTitle, osdPosition, osdColor, osdFontSize, osdDurationMs, osdFadeEnabled, holdAction, action1, action2, action3, action4, trayIconMicState, customAppPath

    if (IsObject(settingsGui)) {
        settingsGui.Show()
        return
    }

    settingsGui := Gui("+AlwaysOnTop +Owner", "⚙️ Copilot Tuşu Ayarları")
    settingsGui.SetFont("s9", "Segoe UI")

    ; --- Müzik Uygulaması Seçimi ---
    settingsGui.Add("GroupBox", "x12 y10 w360 h60", "🎵 Hedef Müzik Uygulaması")
    radYtm     := settingsGui.Add("Radio", "x26 y32 w150 h20 Checked" (musicApp = "YTM" ? "1" : "0"), "YouTube Music")
    radSpotify := settingsGui.Add("Radio", "x180 y32 w150 h20 Checked" (musicApp = "Spotify" ? "1" : "0"), "Spotify")

    ; --- Tıklama & Başlangıç Ayarları ---
    settingsGui.Add("GroupBox", "x12 y75 w360 h120", "⏱️ Zamanlama & Başlangıç Ayarları")
    settingsGui.Add("Text",     "x26 y95 w180 h20", "Tıklama Bekleme Süresi (ms):")
    edtDoubleTap := settingsGui.Add("Edit", "x210 y92 w140 h22 Number", doubleTapThreshold)
    
    settingsGui.Add("Text",     "x26 y130 w180 h20", "Basılı Tutma Eşik Süresi (ms):")
    edtHold := settingsGui.Add("Edit", "x210 y127 w140 h22 Number", holdThreshold)

    chkAuto := settingsGui.Add("Checkbox", "x26 y162 w320 h20 Checked" (autoStart ? "1" : "0"), "Windows açıldığında otomatik başlat")

    ; --- Uygulama Özel Ayarları ---
    settingsGui.Add("GroupBox", "x12 y200 w360 h150", "⚙️ Uygulama Başlık & Komut Ayarları")
    
    settingsGui.Add("Text",     "x26 y225 w120 h20", "YTM URL / Komut:")
    edtYtmUrl := settingsGui.Add("Edit", "x150 y222 w200 h22", ytmUrl)

    settingsGui.Add("Text",     "x26 y255 w120 h20", "YTM Başlık:")
    edtYtmTitle := settingsGui.Add("Edit", "x150 y252 w200 h22", ytmTitle)

    settingsGui.Add("Text",     "x26 y285 w120 h20", "Spotify Komut:")
    edtSpotCmd := settingsGui.Add("Edit", "x150 y282 w200 h22", spotifyCmd)

    settingsGui.Add("Text",     "x26 y315 w120 h20", "Spotify Başlık:")
    edtSpotTitle := settingsGui.Add("Edit", "x150 y312 w200 h22", spotifyTitle)

    ; --- OSD Bildirim Ayarları ---
    settingsGui.Add("GroupBox", "x12 y355 w360 h175", "💬 OSD Bildirim Ayarları")

    settingsGui.Add("Text", "x26 y378 w120 h20", "OSD Konumu:")
    ddlPos := settingsGui.Add("DropDownList", "x150 y375 w200 h22", ["TopLeft", "TopRight", "BottomLeft", "BottomRight", "Center"])
    ddlPos.Text := osdPosition

    settingsGui.Add("Text", "x26 y408 w120 h20", "Metin Rengi (hex):")
    edtOsdColor := settingsGui.Add("Edit", "x150 y405 w200 h22", osdColor)

    settingsGui.Add("Text", "x26 y438 w120 h20", "Font Boyutu:")
    edtOsdSize := settingsGui.Add("Edit", "x150 y435 w200 h22 Number", osdFontSize)

    settingsGui.Add("Text", "x26 y468 w120 h20", "Gösterim Süresi (ms):")
    edtOsdDur := settingsGui.Add("Edit", "x150 y465 w200 h22 Number", osdDurationMs)

    chkFade := settingsGui.Add("Checkbox", "x26 y498 w320 h20 Checked" (osdFadeEnabled ? "1" : "0"), "Fade (solma) animasyonu kullan")

    ; --- Basılı Tutma & Tray İkonu ---
    settingsGui.Add("GroupBox", "x12 y535 w360 h105", "🎤 Basılı Tutma & Tray İkonu")

    settingsGui.Add("Text", "x26 y558 w120 h20", "Basılı Tutma:")
    ddlHold := settingsGui.Add("DropDownList", "x150 y555 w200 h22", ["MusicApp", "PushToTalk", "CustomApp"])
    ddlHold.Text := holdAction

    settingsGui.Add("Text", "x26 y588 w120 h20", "Uygulama / URL:")
    edtCustomApp := settingsGui.Add("Edit", "x150 y585 w200 h22", customAppPath)

    chkTrayMic := settingsGui.Add("Checkbox", "x26 y615 w320 h20 Checked" (trayIconMicState ? "1" : "0"), "Mikrofon durumuna göre tray ikonu değiştir")

    ; --- Eylem Atamaları ---
    actionList := ["MicMute", "PlayPause", "NextTrack", "PrevTrack", "VolumeUp", "VolumeDown", "None"]

    settingsGui.Add("GroupBox", "x12 y645 w360 h145", "⌨️ Tık Eylem Atamaları")

    settingsGui.Add("Text", "x26 y668 w120 h20", "1 Tık:")
    ddlAct1 := settingsGui.Add("DropDownList", "x150 y665 w200 h22", actionList)
    ddlAct1.Text := action1

    settingsGui.Add("Text", "x26 y698 w120 h20", "2 Tık:")
    ddlAct2 := settingsGui.Add("DropDownList", "x150 y695 w200 h22", actionList)
    ddlAct2.Text := action2

    settingsGui.Add("Text", "x26 y728 w120 h20", "3 Tık:")
    ddlAct3 := settingsGui.Add("DropDownList", "x150 y725 w200 h22", actionList)
    ddlAct3.Text := action3

    settingsGui.Add("Text", "x26 y758 w120 h20", "4 Tık:")
    ddlAct4 := settingsGui.Add("DropDownList", "x150 y755 w200 h22", actionList)
    ddlAct4.Text := action4

    ; --- Butonlar ---
    btnSave := settingsGui.Add("Button", "x140 y805 w110 h30 Default", "💾 Kaydet & Yenile")
    btnSave.OnEvent("Click", (*) => SaveAndReload())

    btnCancel := settingsGui.Add("Button", "x260 y805 w110 h30", "❌ İptal")
    btnCancel.OnEvent("Click", (*) => (settingsGui.Destroy(), settingsGui := 0))

    settingsGui.OnEvent("Close", (*) => (settingsGui.Destroy(), settingsGui := 0))
    settingsGui.Show("w384 h850")

    SaveAndReload() {
        newApp    := radSpotify.Value ? "Spotify" : "YTM"
        newDouble := Integer(edtDoubleTap.Value)
        newHold   := Integer(edtHold.Value)
        newAuto   := chkAuto.Value ? 1 : 0
        newYtmUrl := Trim(edtYtmUrl.Value)
        newYtmTitle  := Trim(edtYtmTitle.Value)
        newSpotCmd   := Trim(edtSpotCmd.Value)
        newSpotTitle := Trim(edtSpotTitle.Value)

        ; OSD Ayarları
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

        ; OSD Ayarları kaydet
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

    ; ── OSD Bildirim Ayarları ──

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
    installDir := A_LocalAppData "\CopilotButton"
    
    ; Zaten özel klasördeyse hiçbir şey yapma
    if (StrLower(A_ScriptDir) = StrLower(installDir))
        return

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
        whr.Open("GET", "https://api.github.com/repos/KeremKuyucu/copilot-buton/releases/latest", true)
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