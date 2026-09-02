; ══════════════════════════════════════════
;  EYLEM DİSPATCH & MEDYA / MİKROFON KONTROLLERİ
; ══════════════════════════════════════════

RunAction(actionName, tapIndex := 0) {
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
        case "CustomMacro":
            RunCustomMacro(tapIndex)
        case "None":
            ; Eylem yok
        default:
            ShowTip("⚠️ Bilinmeyen eylem: " actionName)
    }
}

; ══════════════════════════════════════════
;  ÖZEL MAKRO ÇALIŞTIRMA
; ══════════════════════════════════════════
RunCustomMacro(tapIndex) {
    global customMacro1, customMacro2, customMacro3, customMacro4

    macro := ""
    switch tapIndex {
        case 1: macro := customMacro1
        case 2: macro := customMacro2
        case 3: macro := customMacro3
        case 4: macro := customMacro4
    }

    if (macro = "") {
        ShowTip("⚠️ Makro tanımlı değil! Ayarlardan makro girin.", 2500)
        return
    }

    try {
        Send macro
        ShowTip("🎹 Makro gönderildi: " macro)
    } catch as err {
        ShowTip("⚠️ Makro hatası: " err.Message, 2500)
    }
}

; ══════════════════════════════════════════
;  MİKROFON KONTROLLERİ & CORE AUDIO COM
; ══════════════════════════════════════════

GetDefaultCaptureEndpointVolume() {
    CLSID_MMDeviceEnumerator := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
    IID_IMMDeviceEnumerator  := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
    IID_IAudioEndpointVolume := "{5CDF2C82-841E-4546-9722-0CF74078229A}"

    try {
        devEnum := ComObject(CLSID_MMDeviceEnumerator, IID_IMMDeviceEnumerator)
        ; GetDefaultAudioEndpoint: dataFlow=1 (eCapture), role=0 (eConsole)
        ComCall(4, devEnum, "int", 1, "int", 0, "ptr*", &pDevice := 0)
        if (!pDevice)
            return 0
        device := ComValue(13, pDevice)

        pEndpointVolume := 0
        IID_IAudioEndpointVolume_GUID := Buffer(16)
        DllCall("ole32\CLSIDFromString", "wstr", IID_IAudioEndpointVolume, "ptr", IID_IAudioEndpointVolume_GUID)
        ComCall(3, device, "ptr", IID_IAudioEndpointVolume_GUID, "uint", 23, "ptr", 0, "ptr*", &pEndpointVolume)
        if (!pEndpointVolume)
            return 0

        return ComValue(13, pEndpointVolume)
    }
    return 0
}

GetMicMuteState() {
    global micDevice

    ; Kullanıcı belirli bir cihaz seçtiyse doğrudan o cihazı kontrol et
    if (micDevice != "Auto" && micDevice != "") {
        try {
            return (SoundGetMute(, micDevice) != 0)
        }
    }

    ; Windows Varsayılan Kayıt Cihazı (Core Audio COM)
    try {
        epv := GetDefaultCaptureEndpointVolume()
        if (epv) {
            ComCall(15, epv, "int*", &isMuted := 0) ; IAudioEndpointVolume::GetMute
            return (isMuted != 0)
        }
    }

    ; Yedek Strateji: Bilinen cihaz adları
    micNames := ["Microphone", "Mikrofon", "Microphone Array", "Mikrofon Dizisi", "Headset Microphone"]
    for _, name in micNames {
        try {
            return (SoundGetMute(, name) != 0)
        }
    }

    return false
}

SetMicMuteState(muteState) {
    global micDevice
    success := false

    val := muteState ? 1 : 0

    ; Kullanıcı belirli bir cihaz seçtiyse
    if (micDevice != "Auto" && micDevice != "") {
        try {
            SoundSetMute(val, , micDevice)
            success := true
        }
    }

    ; Windows Varsayılan Kayıt Cihazı (Core Audio COM)
    if (!success) {
        try {
            epv := GetDefaultCaptureEndpointVolume()
            if (epv) {
                ComCall(14, epv, "int", val, "ptr", 0) ; IAudioEndpointVolume::SetMute
                success := true
            }
        }
    }

    ; Yedek Strateji
    if (!success) {
        micNames := ["Microphone", "Mikrofon", "Microphone Array", "Mikrofon Dizisi", "Headset Microphone"]
        for _, name in micNames {
            try {
                SoundSetMute(val, , name)
                success := true
                break
            }
        }
    }

    return success
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
    global lastKnownMicMute
    isMasterMuted := false

    ; Mikrofon durumunu tersine çevir
    curMic := GetMicMuteState()
    newMic := !curMic
    SetMicMuteState(newMic)
    isMicMuted := GetMicMuteState()

    try {
        SoundSetMute(-1)
        isMasterMuted := SoundGetMute()
    }

    PlayMicSound(isMicMuted)
    UpdateMicOverlay(isMicMuted)
    UpdateTrayIcon(isMicMuted)
    lastKnownMicMute := isMicMuted

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
;  MİKROFON SUSTURMA / AÇMA
; ══════════════════════════════════════════
ToggleMicrophoneMute() {
    global lastKnownMicMute

    curState := GetMicMuteState()
    newState := !curState
    SetMicMuteState(newState)

    ; Güncel durumu doğrula
    isMuted := GetMicMuteState()

    ; Discord benzeri yumuşak ses efekti
    PlayMicSound(isMuted)

    ; Ekranda bildirim göster
    if isMuted {
        ShowTip("🎙️ Mikrofon Susturuldu (MUTE)")
    } else {
        ShowTip("🎙️ Mikrofon Açıldı (UNMUTE)")
    }

    UpdateMicOverlay(isMuted)
    UpdateTrayIcon(isMuted)
    lastKnownMicMute := isMuted
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

SetMicMute(muteState) {
    global lastKnownMicMute
    SetMicMuteState(muteState)
    isMuted := GetMicMuteState()
    UpdateMicOverlay(isMuted)
    UpdateTrayIcon(isMuted)
    lastKnownMicMute := isMuted
}

UpdateMicOverlay(isMuted) {
    global micOverlayGui

    if (isMuted) {
        ; Overlay yoksa oluştur; varsa sadece göster
        if (!IsObject(micOverlayGui)) {
            try {
                if (IsObject(micOverlayGui))
                    micOverlayGui.Destroy()
            }
            micOverlayGui := 0

            transColor := "010101"
            micOverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "MicMuteOverlay")
            micOverlayGui.BackColor := transColor
            micOverlayGui.SetFont("s11 bold cFF4444", "Segoe UI")
            micOverlayGui.Add("Text", "x0 y0", "🔴 MİKROFON SUSTURULDU")
        }
        micOverlayGui.Show("x20 y15 NoActivate AutoSize")
        try WinSetTransColor("010101 255", micOverlayGui)
    } else {
        if (IsObject(micOverlayGui)) {
            micOverlayGui.Hide()
        }
    }
}

SyncMicState() {
    global lastKnownMicMute

    currentMute := GetMicMuteState()

    ; İlk çalışma senkronizasyonu
    if (lastKnownMicMute == -1) {
        lastKnownMicMute := currentMute
        UpdateMicOverlay(currentMute)
        UpdateTrayIcon(currentMute)
        return
    }

    ; Durum dışarıdan (Windows/kulaklık/donanım düğmesi) değiştiyse
    if (currentMute != lastKnownMicMute) {
        lastKnownMicMute := currentMute
        UpdateMicOverlay(currentMute)
        UpdateTrayIcon(currentMute)
        PlayMicSound(currentMute)
        if (currentMute)
            ShowTip("🎙️ Mikrofon Susturuldu (MUTE)")
        else
            ShowTip("🎙️ Mikrofon Açıldı (UNMUTE)")
    }
}

OpenMusicApp() {
    global musicApp, spotifyTitle, spotifyCmd, ytmTitle, ytmUrl
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
