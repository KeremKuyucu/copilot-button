#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook true
InstallKeybdHook()
A_MenuMaskKey := "vkE8"

global APP_VERSION := "1.0.9"
global EXPECTED_CERT_THUMBPRINT := "037728AEA36D0BB09D2D1EE111C70A2D423CC6B4"

SetTitleMatchMode 2

; ══════════════════════════════════════════
;  ÖZEL KLASÖRE YERLEŞTİRME & KURULUM
; ══════════════════════════════════════════
EnsureInstalledLocation()

; ══════════════════════════════════════════
;  AYARLAR — config.ini'den okunur
; ══════════════════════════════════════════
global configFile := A_ScriptDir "\config.ini"

ReadConfigInt(section, key, defaultVal) {
    global configFile
    try
        return Integer(IniRead(configFile, section, key, defaultVal))
    catch
        return defaultVal
}

global doubleTapThreshold := ReadConfigInt("Settings", "DoubleTapMs", 250)
global holdThreshold      := ReadConfigInt("Settings", "HoldMs", 250)
global autoStart          := ReadConfigInt("Settings", "AutoStart", 1)

global musicApp     := IniRead(configFile, "Settings", "MusicApp", "YTM")
global ytmUrl       := IniRead(configFile, "Settings", "YtmURL", "https://music.youtube.com")
global ytmTitle     := IniRead(configFile, "Settings", "YtmWindowTitle", "YouTube Music")
global spotifyCmd   := IniRead(configFile, "Settings", "SpotifyCmd", "spotify:")
global spotifyTitle := IniRead(configFile, "Settings", "SpotifyWindowTitle", "ahk_exe spotify.exe")

; OSD & Tema Ayarları
global themeMode      := IniRead(configFile, "Settings", "Theme", "Dark")
global osdPosition    := IniRead(configFile, "Settings", "OsdPosition", "TopLeft")
global osdColor       := IniRead(configFile, "Settings", "OsdColor", "00E5FF")
global osdFontSize    := ReadConfigInt("Settings", "OsdFontSize", 10)
global osdDurationMs  := ReadConfigInt("Settings", "OsdDurationMs", 1500)
global osdFadeEnabled := ReadConfigInt("Settings", "OsdFadeEnabled", 1)

; Basılı Tutma & Eylem Ayarları
global holdAction        := IniRead(configFile, "Settings", "HoldAction", "MusicApp")
global customAppPath     := IniRead(configFile, "Settings", "CustomAppPath", "")
global action1           := IniRead(configFile, "Settings", "Action1", "MicMute")
global action2           := IniRead(configFile, "Settings", "Action2", "PlayPause")
global action3           := IniRead(configFile, "Settings", "Action3", "NextTrack")
global action4           := IniRead(configFile, "Settings", "Action4", "PrevTrack")
global trayIconMicState  := ReadConfigInt("Settings", "TrayIconMicState", 1)
global soundFxEnabled    := ReadConfigInt("Settings", "SoundFxEnabled", 1)
global isKeyDown            := false
global holdTriggered        := false   ; Basılı tutma eyleminin tetiklenip tetiklenmediği
global tapCount             := 0       ; Arka arkaya tıklama sayısı
global settingsGui          := 0       ; GUI pencere nesnesi
global micOverlayGui        := 0       ; Mikrofon kapalı OSD penceresi
global fadeTimer            := 0       ; Fade animasyon zamanlayıcısı
global fadeAlpha            := 0       ; Mevcut saydamlık değeri (0-255)
global pttActive            := false   ; Push-to-Talk aktif mi

; 3-State Anti-Leak Hook Değişkenleri
global copilotState         := "idle"  ; "idle", "waiting", "copilot", "passed"
global shiftState           := "idle"  ; "idle", "waiting", "passed"
global shiftSuppressed      := false   ; LShift/RShift bastırıldı mı
global winSuppressed        := false   ; LWin/RWin bastırıldı mı
global copilotJustReleased  := 0       ; Bırakma zamanı damgası (trailing modifier bastırma)

; Windows Başlangıç Kısayolu Ayarla
SetStartupShortcut(autoStart)

; ══════════════════════════════════════════
;  TRAY İKONU VE MENÜSÜ
; ══════════════════════════════════════════
try {
    if FileExist(A_ScriptDir "\logo.ico")
        TraySetIcon A_ScriptDir "\logo.ico"
    else if A_IsCompiled
        TraySetIcon A_ScriptFullPath
} catch {
    ; İkon yüklenemezse varsayılan AHK ikonu kullanılır, çökme engellenir
}

activeAppName := (musicApp = "Spotify") ? "Spotify" : "YouTube Music"

A_IconTip := "Copilot Tuşu — " activeAppName " & Medya Kontrolü`n• 1 tık : Mikrofon Sustur / Aç`n• 2 tık : Şarkı Durdur / Oynat`n• 3 tık : Şarkı Geç`n• Basılı : " activeAppName " Aç / Öne Al"

A_TrayMenu.Delete()
A_TrayMenu.Add("⚙️  Ayarlar",         ShowSettingsGUI)
A_TrayMenu.Add("🔄 Güncelleme Kontrolü", (*) => CheckForUpdates(false))
A_TrayMenu.Add("🔄 Scripti Yenile",   (*) => Reload())
A_TrayMenu.Add()                         ; Ayırıcı
A_TrayMenu.Add("❌ Çıkış",            (*) => ExitApp())

global tipGui          := 0       ; Anlık bildirim OSD penceresi

; Başlangıçta ve düzenli aralıklarla mikrofon durumunu kontrol et (arka plan eşzamanlama)
CheckInitialMicState()
SetTimer(CheckInitialMicState, 2000)

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
;  COPILOT TUŞ YAKALAMA & MODİFİER BASTIRMA (3-State Anti-Leak Hook)
; ══════════════════════════════════════════

; --- Windows Tuşu Yakalama (LWin / RWin) ---
$*LWin::
$*RWin::
{
    global copilotState, winSuppressed, shiftState
    if (copilotState = "copilot") {
        ; Copilot basılıyken donanımın tekrarladığı Win sinyalini tamamen yut
        return
    }

    copilotState := "waiting"
    winSuppressed := true
    SetTimer(PassModifiers, -25)
}

$*LWin Up::
$*RWin Up::
{
    global copilotState, winSuppressed, shiftSuppressed, copilotJustReleased
    
    ; Copilot henüz bırakıldıysa trailing Win Up sinyalini tamamen yut
    if (copilotState = "copilot" || A_TickCount < copilotJustReleased) {
        winSuppressed := false
        return
    }

    if (copilotState = "waiting") {
        SetTimer(PassModifiers, 0)
        copilotState := "idle"
        if (shiftSuppressed) {
            shiftSuppressed := false
            winSuppressed := false
            SendInput "{Blind}{LWin Down}{LShift Down}{LShift Up}{LWin Up}"
        } else {
            winSuppressed := false
            SendInput "{Blind}{LWin Down}{LWin Up}"
        }
    } else if (copilotState = "passed") {
        copilotState := "idle"
        winSuppressed := false
        SendInput "{Blind}{LWin Up}"
    }
}

; --- Shift Tuşu Yakalama (LShift / RShift) ---
$*LShift::
$*RShift::
{
    global copilotState, shiftState, shiftSuppressed
    if (copilotState = "copilot") {
        ; Copilot basılıyken donanımın tekrarladığı Shift sinyalini tamamen yut
        return
    }
    if (copilotState = "waiting") {
        ; Win tuşundan hemen sonra Shift geldi -> bu Copilot tuş dizisidir, bastır!
        shiftSuppressed := true
        return
    }

    ; Bağımsız Shift basımı: Çok kısa (15ms) bekle (arkasından Win+F23 gelebilir mi?)
    shiftState := "waiting"
    SetTimer(PassShiftOnly, -15)
}

$*LShift Up::
$*RShift Up::
{
    global copilotState, shiftState, shiftSuppressed, copilotJustReleased
    
    ; Copilot basılıyken veya yeni bırakıldıysa trailing Shift Up sinyalini tamamen yut
    if (copilotState = "copilot" || A_TickCount < copilotJustReleased) {
        shiftSuppressed := false
        return
    }
    if (shiftSuppressed) {
        shiftSuppressed := false
        return
    }
    if (shiftState = "waiting") {
        SetTimer(PassShiftOnly, 0)
        shiftState := "idle"
        SendInput "{Blind}{LShift Down}{LShift Up}"
        return
    }
    if (shiftState = "passed") {
        shiftState := "idle"
        SendInput "{Blind}{LShift Up}"
    }
}

PassShiftOnly() {
    global shiftState, copilotState
    if (shiftState = "waiting" && copilotState != "copilot") {
        shiftState := "passed"
        SendInput "{Blind}{LShift Down}"
    }
}

PassModifiers() {
    global copilotState, shiftState, shiftSuppressed, winSuppressed
    if (copilotState = "waiting") {
        copilotState := "passed"
        if (shiftSuppressed || shiftState = "waiting") {
            shiftSuppressed := false
            shiftState := "passed"
            SendInput "{Blind}{LWin Down}{LShift Down}"
        } else {
            SendInput "{Blind}{LWin Down}"
        }
    }
}

; ══════════════════════════════════════════
;  COPILOT TUŞU TETİKLEME (F23 / SC06E / Launch_App1)
; ══════════════════════════════════════════
$*SC06E::
$*vk86::
$*vkB6::
{
    global copilotState, shiftState, shiftSuppressed, winSuppressed
    global isKeyDown, holdTriggered, holdThreshold, pttActive

    ; Zamanlayıcıları hemen durdur ve tamponları temizle (Shift/Win tamamen yok edilir)
    SetTimer(PassModifiers, 0)
    SetTimer(PassShiftOnly, 0)
    copilotState := "copilot"
    shiftState := "idle"
    shiftSuppressed := false
    winSuppressed := false

    if (isKeyDown)
        return

    isKeyDown     := true
    holdTriggered := false

    ; Tıklama sayacı zamanlayıcısını geçici olarak durdur
    SetTimer(CheckMultiPress, 0)

    ; Basılı tutma zamanlayıcısını başlat
    SetTimer(CheckHoldTimer, -holdThreshold)
}

$*SC06E Up::
$*vk86 Up::
$*vkB6 Up::
{
    global copilotState, shiftState, isKeyDown, doubleTapThreshold, holdTriggered, tapCount, pttActive, copilotJustReleased

    copilotState := "idle"
    shiftState := "idle"
    copilotJustReleased := A_TickCount + 80  ; 80ms boyunca ardışık Win Up/Shift Up sinyallerini bastır

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
        case "MasterMute":
            ToggleMasterMute()
        case "ToggleDeafen":
            ToggleDeafen()
        case "VoiceTyping":
            ShowTip("🎙️ Sesle Yazma Açılıyor...")
            Send "#h"
        case "Screenshot":
            ShowTip("✂️ Ekran Alıntısı")
            Send "#+s"
        case "TaskView":
            Send "#{Tab}"
        case "LockScreen":
            ShowTip("🔒 Bilgisayar Kilitleniyor...")
            Sleep 200
            DllCall("LockWorkStation")
        case "PlayPause":
            Send "{Blind}{Media_Play_Pause}"
            SetTimer(ShowPlayPauseTrackInfo, -400)
        case "NextTrack":
            Send "{Blind}{Media_Next}"
            ; Kısa gecikme sonrası güncel şarkı bilgisini göster
            SetTimer(ShowNextTrackInfo, -600)
        case "PrevTrack":
            Send "{Blind}{Media_Prev}"
            SetTimer(ShowPrevTrackInfo, -600)
        case "VolumeUp":
            ShowTip("🔊 Ses Artırıldı")
            Send "{Blind}{Volume_Up 5}"
        case "VolumeDown":
            ShowTip("🔉 Ses Azaltıldı")
            Send "{Blind}{Volume_Down 5}"
        case "None":
            ; Eylem yok
        default:
            ShowTip("⚠️ Bilinmeyen eylem: " actionName)
    }
}

ToggleMasterMute() {
    try {
        SoundSetMute(-1)
        isMuted := SoundGetMute()
        if isMuted
            ShowTip("🔇 Sistem Sesi Kapatıldı (MUTE)")
        else
            ShowTip("🔊 Sistem Sesi Açıldı (UNMUTE)")
    } catch as err {
        ShowTip("⚠️ Ses erişim hatası: " . err.Message, 2000)
    }
}

ToggleDeafen() {
    isMicMuted := false
    isMasterMuted := false
    try {
        SoundSetMute(-1, , "Microphone")
        isMicMuted := SoundGetMute(, "Microphone")
    } catch {
        try {
            SoundSetMute(-1, "Master", "Capture")
            isMicMuted := SoundGetMute("Master", "Capture")
        }
    }
    try {
        SoundSetMute(-1)
        isMasterMuted := SoundGetMute()
    }

    PlayMicSound(isMicMuted)
    UpdateMicOverlay(isMicMuted)
    UpdateTrayIcon(isMicMuted)

    if (isMicMuted && isMasterMuted)
        ShowTip("🔕 Sağırlaştırıldı (Ses & Mic Kapalı)")
    else if (!isMicMuted && !isMasterMuted)
        ShowTip("🔔 Sağırlaştırma Kaldırıldı (Ses & Mic Açık)")
    else
        ShowTip("🔕 Ses & Mikrofon Değiştirildi")
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
    global soundFxEnabled
    if (!soundFxEnabled)
        return

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

    try {
        if (isMuted) {
            if FileExist(A_ScriptDir "\logo_muted.ico")
                TraySetIcon A_ScriptDir "\logo_muted.ico"
            else if A_IsCompiled
                TraySetIcon A_ScriptFullPath  ; EXE'nin gömülü ikonunu kullan
        } else {
            if FileExist(A_ScriptDir "\logo.ico")
                TraySetIcon A_ScriptDir "\logo.ico"
            else if A_IsCompiled
                TraySetIcon A_ScriptFullPath  ; EXE'nin gömülü ikonunu kullan
        }
    } catch {
        ; İkon yüklenemezse çökme engellenir
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
;  BAŞLAT MENÜSÜ KISAYOLU
; ══════════════════════════════════════════
CreateStartMenuShortcut(targetPath := "") {
    if (targetPath = "")
        targetPath := A_ScriptFullPath
    startMenuPath := A_Programs "\CopilotButton.lnk"
    try {
        iconPath := A_ScriptDir "\logo.ico"
        if FileExist(iconPath)
            FileCreateShortcut(targetPath, startMenuPath, A_ScriptDir, , "Copilot Tuşu — Medya & Mikrofon Kontrolü", iconPath)
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
    global settingsGui, configFile, doubleTapThreshold, holdThreshold, musicApp, autoStart, ytmUrl, ytmTitle, spotifyCmd, spotifyTitle, osdPosition, osdColor, osdFontSize, osdDurationMs, osdFadeEnabled, holdAction, action1, action2, action3, action4, trayIconMicState, customAppPath, themeMode, soundFxEnabled

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

    ; --- Sekmeli Ana Panel ---
    tab := settingsGui.Add("Tab3", "x10 y10 w390 h415", ["🎮 Eylemler", "💬 OSD & Görünüm", "🎵 Medya & PTT"])

    ; ══════════════════════════════════════════
    ;  SEKME 1: Eylemler & Zamanlama
    ; ══════════════════════════════════════════
    tab.UseTab(1)
    actionList := ["MicMute", "PlayPause", "NextTrack", "PrevTrack", "VolumeUp", "VolumeDown", "MasterMute", "ToggleDeafen", "VoiceTyping", "Screenshot", "TaskView", "LockScreen", "None"]

    settingsGui.Add("GroupBox", "x20 y45 w370 h185", "⌨️ Tık Eylem Atamaları")

    settingsGui.Add("Text", "x35 y72 w100 h20", "1 Tık:")
    ddlAct1 := settingsGui.Add("DropDownList", "x140 y69 w230 r" actionList.Length " " editOpt, actionList)
    ddlAct1.Text := action1

    settingsGui.Add("Text", "x35 y107 w100 h20", "2 Tık:")
    ddlAct2 := settingsGui.Add("DropDownList", "x140 y104 w230 r" actionList.Length " " editOpt, actionList)
    ddlAct2.Text := action2

    settingsGui.Add("Text", "x35 y142 w100 h20", "3 Tık:")
    ddlAct3 := settingsGui.Add("DropDownList", "x140 y139 w230 r" actionList.Length " " editOpt, actionList)
    ddlAct3.Text := action3

    settingsGui.Add("Text", "x35 y177 w100 h20", "4 Tık:")
    ddlAct4 := settingsGui.Add("DropDownList", "x140 y174 w230 r" actionList.Length " " editOpt, actionList)
    ddlAct4.Text := action4

    settingsGui.Add("GroupBox", "x20 y240 w370 h170", "⏱️ Zamanlama & Başlangıç")

    settingsGui.Add("Text", "x35 y267 w190 h20", "Tıklama Bekleme Süresi (ms):")
    edtDoubleTap := settingsGui.Add("Edit", "x230 y264 w140 h22 Number " editOpt, doubleTapThreshold)

    settingsGui.Add("Text", "x35 y302 w190 h20", "Basılı Tutma Eşik Süresi (ms):")
    edtHold := settingsGui.Add("Edit", "x230 y299 w140 h22 Number " editOpt, holdThreshold)

    chkAuto := settingsGui.Add("Checkbox", "x35 y337 w335 h20 Checked" (autoStart ? "1" : "0"), "Windows açıldığında otomatik başlat")

    ; ══════════════════════════════════════════
    ;  SEKME 2: OSD & Görünüm
    ; ══════════════════════════════════════════
    tab.UseTab(2)

    settingsGui.Add("GroupBox", "x20 y45 w370 h150", "🎨 Tema & Konum")

    settingsGui.Add("Text", "x35 y72 w120 h20", "Arayüz Teması:")
    ddlTheme := settingsGui.Add("DropDownList", "x160 y69 w210 r3 " editOpt, ["Dark", "Light", "Auto"])
    ddlTheme.Text := themeMode

    settingsGui.Add("Text", "x35 y107 w120 h20", "OSD Konumu:")
    ddlPos := settingsGui.Add("DropDownList", "x160 y104 w210 r5 " editOpt, ["TopLeft", "TopRight", "BottomLeft", "BottomRight", "Center"])
    ddlPos.Text := osdPosition

    settingsGui.Add("Text", "x35 y142 w120 h20", "Metin Rengi (hex):")
    edtOsdColor := settingsGui.Add("Edit", "x160 y139 w210 h22 " editOpt, osdColor)

    settingsGui.Add("GroupBox", "x20 y205 w370 h205", "💬 OSD Boyut & Animasyon")

    settingsGui.Add("Text", "x35 y232 w120 h20", "Font Boyutu:")
    edtOsdSize := settingsGui.Add("Edit", "x160 y229 w210 h22 Number " editOpt, osdFontSize)

    settingsGui.Add("Text", "x35 y267 w120 h20", "Gösterim Süresi (ms):")
    edtOsdDur := settingsGui.Add("Edit", "x160 y264 w210 h22 Number " editOpt, osdDurationMs)

    chkFade := settingsGui.Add("Checkbox", "x35 y302 w335 h20 Checked" (osdFadeEnabled ? "1" : "0"), "Fade (solma) animasyonu kullan")

    chkTrayMic := settingsGui.Add("Checkbox", "x35 y332 w335 h20 Checked" (trayIconMicState ? "1" : "0"), "Mikrofon durumuna göre tray ikonu değiştir")

    ; ══════════════════════════════════════════
    ;  SEKME 3: Medya, PTT & Özel Uygulama
    ; ══════════════════════════════════════════
    tab.UseTab(3)

    settingsGui.Add("GroupBox", "x20 y45 w370 h185", "🎵 Hedef Müzik Uygulaması")
    radYtm     := settingsGui.Add("Radio", "x35 y70 w150 h20 Checked" (musicApp = "YTM" ? "1" : "0"), "YouTube Music")
    radSpotify := settingsGui.Add("Radio", "x195 y70 w150 h20 Checked" (musicApp = "Spotify" ? "1" : "0"), "Spotify")

    settingsGui.Add("Text", "x35 y100 w110 h20", "YTM URL / Komut:")
    edtYtmUrl := settingsGui.Add("Edit", "x150 y97 w220 h22 " editOpt, ytmUrl)

    settingsGui.Add("Text", "x35 y130 w110 h20", "YTM Başlık:")
    edtYtmTitle := settingsGui.Add("Edit", "x150 y127 w220 h22 " editOpt, ytmTitle)

    settingsGui.Add("Text", "x35 y160 w110 h20", "Spotify Komut:")
    edtSpotCmd := settingsGui.Add("Edit", "x150 y157 w220 h22 " editOpt, spotifyCmd)

    settingsGui.Add("Text", "x35 y190 w110 h20", "Spotify Başlık:")
    edtSpotTitle := settingsGui.Add("Edit", "x150 y187 w220 h22 " editOpt, spotifyTitle)

    settingsGui.Add("GroupBox", "x20 y240 w370 h170", "🎤 Basılı Tutma, Özel Uygulama & Ses")

    settingsGui.Add("Text", "x35 y265 w110 h20", "Basılı Tutma:")
    ddlHold := settingsGui.Add("DropDownList", "x150 y262 w220 r3 " editOpt, ["MusicApp", "PushToTalk", "CustomApp"])
    ddlHold.Text := holdAction

    settingsGui.Add("Text", "x35 y298 w110 h20", "Uygulama / URL:")
    edtCustomApp := settingsGui.Add("Edit", "x35 y320 w265 h24 " editOpt, customAppPath)
    btnBrowse := settingsGui.Add("Button", "x305 y320 w65 h24", "📁 Gözat")
    btnBrowse.OnEvent("Click", (*) => BrowseCustomApp(edtCustomApp))

    chkSoundFx := settingsGui.Add("Checkbox", "x35 y355 w335 h20 Checked" (soundFxEnabled ? "1" : "0"), "Mikrofon susturma/açma ses efektlerini çal")

    ; ══════════════════════════════════════════
    ;  TAB DIŞI: Butonlar
    ; ══════════════════════════════════════════
    tab.UseTab()

    btnSave := settingsGui.Add("Button", "x120 y435 w110 h32 Default", "💾 Kaydet & Yenile")
    btnSave.OnEvent("Click", (*) => SaveAndReload())

    btnCancel := settingsGui.Add("Button", "x240 y435 w110 h32", "❌ İptal")
    btnCancel.OnEvent("Click", (*) => (settingsGui.Destroy(), settingsGui := 0))

    btnUninstall := settingsGui.Add("Button", "x20 y478 w380 h30", "🗑️ Uygulamayı Tamamen Sil")
    btnUninstall.OnEvent("Click", (*) => UninstallApp())

    settingsGui.OnEvent("Close", (*) => (settingsGui.Destroy(), settingsGui := 0))

    ; Windows Dark Mode Başlık Çubuğu & Kontrol Teması Uygula
    SetWindowDarkMode(settingsGui.Hwnd, isDark)
    ApplyThemeToControls(settingsGui, isDark)

    settingsGui.Show("w410 h520")

    BrowseCustomApp(editCtrl) {
        selectedFile := FileSelect(3, , "Çalıştırılacak Uygulama veya Dosyayı Seçin", "Programlar (*.exe; *.bat; *.cmd; *.lnk; *.vbs; *.ps1; *.*)")
        if (selectedFile != "")
            editCtrl.Value := selectedFile
    }

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

        ; Basılı Tutma & Tray İkonu & Ses Efektleri kaydet
        IniWrite(ddlHold.Text,              configFile, "Settings", "HoldAction")
        IniWrite(Trim(edtCustomApp.Value),  configFile, "Settings", "CustomAppPath")
        IniWrite(chkTrayMic.Value ? 1 : 0,  configFile, "Settings", "TrayIconMicState")
        IniWrite(chkSoundFx.Value ? 1 : 0,  configFile, "Settings", "SoundFxEnabled")

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
;  UYGULAMAYI TAMAMEN SİLME (UNINSTALL)
; ══════════════════════════════════════════
UninstallApp() {
    global settingsGui

    result := MsgBox(
        "Copilot Button uygulaması tamamen silinecek!`n`n"
        . "Bu işlem şunları yapacak:`n"
        . "• Windows başlangıç kısayolunu silecek`n"
        . "• Başlat Menüsü kısayolunu silecek`n"
        . "• Ayar dosyasını (config.ini) silecek`n"
        . "• İkon dosyalarını silecek`n"
        . "• Uygulamanın kendisini silecek`n`n"
        . "Bu işlem geri alınamaz! Devam etmek istiyor musunuz?",
        "🗑️ Uygulamayı Sil — Copilot Button",
        "YesNo Icon! Default2"
    )

    if (result != "Yes")
        return

    ; Ayarlar penceresini kapat
    if (IsObject(settingsGui)) {
        settingsGui.Destroy()
        settingsGui := 0
    }

    ; 1) Startup kısayolunu sil
    try SetStartupShortcut(false)

    ; 2) Başlat Menüsü kısayolunu sil
    try RemoveStartMenuShortcut()

    installDir := A_ScriptDir

    ; 3) Config dosyasını sil
    if FileExist(installDir "\config.ini")
        try FileDelete(installDir "\config.ini")

    ; 4) İkon dosyalarını sil
    if FileExist(installDir "\logo.ico")
        try FileDelete(installDir "\logo.ico")
    if FileExist(installDir "\logo_muted.ico")
        try FileDelete(installDir "\logo_muted.ico")

    ; 5) EXE'yi silmek için batch script oluştur (çalışan dosya kendini silemez)
    if (A_IsCompiled) {
        tempBat := A_Temp "\copilot_button_uninstall.bat"
        batContent := "@echo off`r`n"
            . "timeout /t 2 /nobreak > nul`r`n"
            . 'del /f /q "' . A_ScriptFullPath . '"' . "`r`n"
            . 'rmdir /s /q "' . installDir . '" 2>nul' . "`r`n"
            . 'del /f /q "%~f0"' . "`r`n"

        f := FileOpen(tempBat, "w")
        f.Write(batContent)
        f.Close()

        Run('cmd.exe /c "' . tempBat . '"',, "Hide")
    }

    ExitApp()
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
    ; Seçenekler: MicMute, PlayPause, NextTrack, PrevTrack, VolumeUp, VolumeDown, MasterMute, ToggleDeafen, VoiceTyping, Screenshot, TaskView, LockScreen, None

    ; 1 Tık Eylemi
    Action1=MicMute

    ; 2 Tık Eylemi
    Action2=PlayPause

    ; 3 Tık Eylemi
    Action3=NextTrack

    ; 4 Tık Eylemi
    Action4=None

    ; ── Tray İkonu & Ses Efektleri ──

    ; Mikrofon durumuna göre tray ikonu değiştir (1 = Açık, 0 = Kapalı)
    TrayIconMicState=1

    ; Mikrofon susturma/açma ses efektlerini çal (1 = Açık, 0 = Kapalı)
    SoundFxEnabled=1
    )"

    try FileAppend(defaultConfig, path)
}

; ══════════════════════════════════════════
;  ÖZEL KLASÖR KURULUM FONKSİYONU
; ══════════════════════════════════════════
EnsureInstalledLocation() {
    ; Geliştirme modunda (derlenmemiş script) özel klasöre taşıma yapma
    if (!A_IsCompiled)
        return

    localAppData := EnvGet("LOCALAPPDATA")
    if (localAppData = "")
        localAppData := A_AppData "\..\Local"
    installDir := localAppData "\CopilotButton"
    
    ; Zaten özel klasördeyse ikonları ve kısayolları kontrol et ve çık
    if (StrLower(A_ScriptDir) = StrLower(installDir)) {
        EnsureDefaultIcons(installDir)
        ; Başlat Menüsü kısayolu yoksa oluştur
        if !FileExist(A_Programs "\CopilotButton.lnk")
            CreateStartMenuShortcut()
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

        ; Başlat Menüsü kısayolunu oluştur
        CreateStartMenuShortcut(targetFile)

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

    ; Eger logo dosyasi yoksa veya boyutu bozuksa (50KB alti), guncel base64 ile yeniden yaz
    if (!FileExist(logoPath) || FileGetSize(logoPath) < 50000) {
        b64Logo := "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"
        SaveBase64ToFile(b64Logo, logoPath)
    }

    if (!FileExist(mutedPath) || FileGetSize(mutedPath) < 50000) {
        b64Muted := "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"
        SaveBase64ToFile(b64Muted, mutedPath)
    }
}

SaveBase64ToFile(b64, filePath) {
    try {
        size := 0
        if DllCall("crypt32\CryptStringToBinaryW", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0) {
            buf := Buffer(size)
            if DllCall("crypt32\CryptStringToBinaryW", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", buf, "UInt*", &size, "Ptr", 0, "Ptr", 0) {
                if FileExist(filePath)
                    try FileDelete(filePath)
                file := FileOpen(filePath, "w")
                file.RawWrite(buf, size)
                file.Close()
            }
        }
    }
}

; ══════════════════════════════════════════
;  GITHUB OTOMATİK GÜNCELLEME SİSTEMİ
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

        if (CompareVersions(latestVersion, currentVersion) <= 0) {
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

        ; Dijital imza ve sertifika parmak izi (Thumbprint) doğrulaması
        psVerify := 'powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = Get-AuthenticodeSignature -LiteralPath `'' . tempExe . '`'; if ($s.SignerCertificate -and $s.SignerCertificate.Thumbprint -eq `'' . EXPECTED_CERT_THUMBPRINT . '`' -and $s.Status -ne `'HashMismatch`') { exit 0 } else { exit 1 }"'
        verifyExit := RunWait(psVerify,, "Hide")
        if (verifyExit != 0) {
            ShowTip("⚠️ İndirilen dosyanın dijital imzası veya sertifika hash'i doğrulanamadı!", 3500)
            try DirDelete(tempDir, true)
            return
        }

        ; Batch updater betiği oluştur
        batFile := tempDir "\update.bat"
        batContent := "@echo off`r`ntimeout /t 2 /nobreak > nul`r`ncopy /y `"" . tempExe . "`" `"" . targetExe . "`"`r`nstart `"`" `"" . targetExe . "`"`r`nrmdir /s /q `"" . tempDir . "`""
        
        f := FileOpen(batFile, "w")
        f.Write(batContent)
        f.Close()

        ShowTip("✅ v" . newVersion . " hazır! Başlatılıyor...", 3000)
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
            ; Dijital imza ve sertifika parmak izi (Thumbprint) doğrulaması
            psVerify := 'powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = Get-AuthenticodeSignature -LiteralPath `'' . foundExe . '`'; if ($s.SignerCertificate -and $s.SignerCertificate.Thumbprint -eq `'' . EXPECTED_CERT_THUMBPRINT . '`' -and $s.Status -ne `'HashMismatch`') { exit 0 } else { exit 1 }"'
            verifyExit := RunWait(psVerify,, "Hide")
            if (verifyExit != 0) {
                ShowTip("⚠️ İndirilen paketteki EXE'nin dijital imzası veya sertifika hash'i doğrulanamadı!", 3500)
                try DirDelete(tempDir, true)
                return
            }

            targetExe := A_ScriptFullPath
            batFile := tempDir "\update.bat"
            batContent := "@echo off`r`ntimeout /t 2 /nobreak > nul`r`ncopy /y `"" . foundExe . "`" `"" . targetExe . "`"`r`nstart `"`" `"" . targetExe . "`"`r`nrmdir /s /q `"" . tempDir . "`""
            
            f := FileOpen(batFile, "w")
            f.Write(batContent)
            f.Close()

            ShowTip("✅ v" . newVersion . " hazır! Başlatılıyor...", 3000)
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
                ShowTip("✅ v" . newVersion . " hazır! Başlatılıyor...", 3000)
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