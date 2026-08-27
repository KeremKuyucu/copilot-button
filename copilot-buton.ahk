;@Ahk2Exe-SetMainIcon logo.ico
;@Ahk2Exe-SetProductName Copilot Button Controller
;@Ahk2Exe-SetDescription Windows Copilot Key Media & Mic Controller
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Kerem Kuyucu
;@Ahk2Exe-SetCompanyName Kerem Kuyucu
;@Ahk2Exe-SetOrigFilename CopilotButton.exe

#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook true
InstallKeybdHook()
A_MenuMaskKey := "vkE8"

global APP_VERSION := "1.0.12"
global EXPECTED_CERT_THUMBPRINT := "037728AEA36D0BB09D2D1EE111C70A2D423CC6B4"

SetTitleMatchMode 2

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
global holdThreshold := ReadConfigInt("Settings", "HoldMs", 250)
global autoStart := ReadConfigInt("Settings", "AutoStart", 1)

global musicApp := IniRead(configFile, "Settings", "MusicApp", "YTM")
global ytmUrl := IniRead(configFile, "Settings", "YtmURL", "https://music.youtube.com")
global ytmTitle := IniRead(configFile, "Settings", "YtmWindowTitle", "YouTube Music")
global spotifyCmd := IniRead(configFile, "Settings", "SpotifyCmd", "spotify:")
global spotifyTitle := IniRead(configFile, "Settings", "SpotifyWindowTitle", "ahk_exe spotify.exe")

; OSD & Tema Ayarları
global themeMode := IniRead(configFile, "Settings", "Theme", "Dark")
global osdPosition := IniRead(configFile, "Settings", "OsdPosition", "TopLeft")
global osdColor := IniRead(configFile, "Settings", "OsdColor", "00E5FF")
global osdFontSize := ReadConfigInt("Settings", "OsdFontSize", 10)
global osdDurationMs := ReadConfigInt("Settings", "OsdDurationMs", 1500)
global osdFadeEnabled := ReadConfigInt("Settings", "OsdFadeEnabled", 1)

; Basılı Tutma & Eylem Ayarları
global holdAction := IniRead(configFile, "Settings", "HoldAction", "MusicApp")
global customAppPath := IniRead(configFile, "Settings", "CustomAppPath", "")
global action1 := IniRead(configFile, "Settings", "Action1", "MicMute")
global action2 := IniRead(configFile, "Settings", "Action2", "PlayPause")
global action3 := IniRead(configFile, "Settings", "Action3", "NextTrack")
global action4 := IniRead(configFile, "Settings", "Action4", "PrevTrack")
global trayIconMicState := ReadConfigInt("Settings", "TrayIconMicState", 1)
global soundFxEnabled := ReadConfigInt("Settings", "SoundFxEnabled", 1)
global isKeyDown := false
global holdTriggered := false   ; Basılı tutma eyleminin tetiklenip tetiklenmediği
global tapCount := 0       ; Arka arkaya tıklama sayısı
global settingsGui := 0       ; GUI pencere nesnesi
global micOverlayGui := 0       ; Mikrofon kapalı OSD penceresi
global fadeTimer := 0       ; Fade animasyon zamanlayıcısı
global fadeAlpha := 0       ; Mevcut saydamlık değeri (0-255)
global pttActive := false   ; Push-to-Talk aktif mi

; 3-State Anti-Leak Hook Değişkenleri
global copilotState := "idle"  ; "idle", "waiting", "copilot", "passed"
global shiftState := "idle"  ; "idle", "waiting", "passed"
global shiftSuppressed := false   ; LShift/RShift bastırıldı mı
global winSuppressed := false   ; LWin/RWin bastırıldı mı
global copilotJustReleased := 0       ; Bırakma zamanı damgası (trailing modifier bastırma)

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
A_TrayMenu.Add("⚙️  Ayarlar", ShowSettingsGUI)
A_TrayMenu.Add("🔄 Güncelleme Kontrolü", (*) => CheckForUpdates(false))
A_TrayMenu.Add("🔄 Scripti Yenile", (*) => Reload())
A_TrayMenu.Add()                         ; Ayırıcı
A_TrayMenu.Add("❌ Çıkış", (*) => ExitApp())

global tipGui := 0       ; Anlık bildirim OSD penceresi

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
            return { x: screenW - 300, y: 45 }
        case "BottomLeft":
            return { x: 20, y: screenH - 80 }
        case "BottomRight":
            return { x: screenW - 300, y: screenH - 80 }
        case "Center":
            return { x: (screenW // 2) - 150, y: (screenH // 2) - 20 }
        default:  ; TopLeft
            return { x: 20, y: 45 }
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

    isKeyDown := true
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
    global copilotState, shiftState, isKeyDown, doubleTapThreshold, holdTriggered, tapCount, pttActive,
        copilotJustReleased

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
    "ToggleDeafen", "VoiceTyping", "Screenshot", "TaskView", "LockScreen", "None"]

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
        actionKeys, actionDisplayMap, tipGui, APP_VERSION

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
    AddP1(settingsGui.Add("GroupBox", "x212 y124 w485 h230", "⚡ Tık Fonksiyonları"))

    ; 1 Tık
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x228 y152 w130 h22", "1 Tık (Tek Basım):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct1 := AddP1(settingsGui.Add("DropDownList", "x365 y148 w315 r13 " editOpt, actionDisplayList))
    ddlAct1.Text := GetActionDisplay(action1)

    ; 2 Tık
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x228 y196 w130 h22", "2 Tık (Çift Basım):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct2 := AddP1(settingsGui.Add("DropDownList", "x365 y192 w315 r13 " editOpt, actionDisplayList))
    ddlAct2.Text := GetActionDisplay(action2)

    ; 3 Tık
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x228 y240 w130 h22", "3 Tık (Üç Basım):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct3 := AddP1(settingsGui.Add("DropDownList", "x365 y236 w315 r13 " editOpt, actionDisplayList))
    ddlAct3.Text := GetActionDisplay(action3)

    ; 4 Tık
    settingsGui.SetFont("s9 bold c" textColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x228 y284 w130 h22", "4 Tık (Dört Basım):"))
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    ddlAct4 := AddP1(settingsGui.Add("DropDownList", "x365 y280 w315 r13 " editOpt, actionDisplayList))
    ddlAct4.Text := GetActionDisplay(action4)

    ; Açıklamalar Kartı
    AddP1(settingsGui.Add("GroupBox", "x212 y362 w485 h163", "ℹ️ Eylem Açıklamaları"))
    settingsGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    AddP1(settingsGui.Add("Text", "x228 y385 w455 h130",
        "• Mikrofon Sustur: Donanım mikrofonunu evrensel olarak susturur / açar.`n"
        . "• Oynat / Duraklat & Şarkı Geç: Aktif medya oynatıcıyı kontrol eder.`n"
        . "• Sağırlaştır: Kulaklık ve mikrofonu aynı anda tamamen kapatır.`n"
        . "• Sesle Yazma: Windows sesli dikte modunu (Win+H) başlatır.`n"
        . "• Ekran Alıntısı: Ekran yakalama aracını (Win+Shift+S) tetikler."))

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

    ; Sistem & Bildirimler
    settingsGui.SetFont("s9 c" textColor, "Segoe UI")
    AddP2(settingsGui.Add("GroupBox", "x212 y312 w485 h213", "⚙️ Sistem & Geri Bildirim"))

    chkAuto := AddP2(settingsGui.Add("Checkbox", "x228 y340 w455 h24 Checked" (autoStart ? "1" : "0"),
    "🚀  Windows açıldığında otomatik olarak başlat"))

    chkTrayMic := AddP2(settingsGui.Add("Checkbox", "x228 y380 w455 h24 Checked" (trayIconMicState ? "1" : "0"),
    "🎙️  Mikrofon durumuna göre görev çubuğu simgesini değiştir (Mute ikonu)"))

    chkSoundFx := AddP2(settingsGui.Add("Checkbox", "x228 y420 w455 h24 Checked" (soundFxEnabled ? "1" : "0"),
    "🔊  Mikrofon susturulduğunda / açıldığında hafif ses efekti çal"))

    settingsGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    AddP2(settingsGui.Add("Text", "x248 y450 w435 h60",
        "Ses efektleri Discord benzeri hafif sistem bildirim seslerini kullanır ve mikrofon durumunuzu ekran dışındayken de duymanızı sağlar."
    ))

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
        "🔄  Scripti Yeniden Başlat")))
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

        ; Eylem Atamaları kaydet (Display String -> Key)
        IniWrite(GetActionKey(ddlAct1.Text), configFile, "Settings", "Action1")
        IniWrite(GetActionKey(ddlAct2.Text), configFile, "Settings", "Action2")
        IniWrite(GetActionKey(ddlAct3.Text), configFile, "Settings", "Action3")
        IniWrite(GetActionKey(ddlAct4.Text), configFile, "Settings", "Action4")

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
