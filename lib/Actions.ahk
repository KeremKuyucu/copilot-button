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
        case "PlayPause":
            Send "{Blind}{Media_Play_Pause}"
        case "NextTrack":
            Send "{Blind}{Media_Next}"
        case "PrevTrack":
            Send "{Blind}{Media_Prev}"
        case "LockScreen":
            ShowTip("🔒 Bilgisayar Kilitleniyor...")
            Sleep 200
            DllCall("LockWorkStation")
        case "None":
            ; Eylem yok
        default:
            ShowTip("⚠️ Bilinmeyen eylem: " actionName)
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

    return false
}

SetMicMuteState(muteState) {
    global micDevice
    val := muteState ? 1 : 0

    ; Kullanıcı belirli bir cihaz seçtiyse
    if (micDevice != "Auto" && micDevice != "") {
        try {
            SoundSetMute(val, , micDevice)
            return true
        }
    }

    ; Windows Varsayılan Kayıt Cihazı (Core Audio COM)
    try {
        epv := GetDefaultCaptureEndpointVolume()
        if (epv) {
            ComCall(14, epv, "int", val, "ptr", 0) ; IAudioEndpointVolume::SetMute
            return true
        }
    }

    return false
}

; ══════════════════════════════════════════
;  DURUM YÖNETİCİLERİ
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
    lastKnownMicMute := isMuted
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

    curMic := GetMicMuteState()
    curMaster := false
    try {
        curMaster := (SoundGetMute() != 0)
    }

    ; Herhangi biri açıksa ikisini de sustur (Deafen); ikisi de susturulmuşsa aç (Undeafen)
    shouldMute := (!curMic || !curMaster) ? true : false

    SetMicMuteState(shouldMute)
    isMicMuted := GetMicMuteState()

    try {
        SoundSetMute(shouldMute ? 1 : 0)
        isMasterMuted := (SoundGetMute() != 0)
    } catch {
        isMasterMuted := shouldMute
    }

    PlayMicSound(isMicMuted)
    UpdateMicOverlay(isMicMuted)
    lastKnownMicMute := isMicMuted

    if (isMicMuted && isMasterMuted)
        ShowTip("🔕 Sağırlaştırıldı (Ses & Mic Kapalı)")
    else if (!isMicMuted && !isMasterMuted)
        ShowTip("🔔 Sağırlaştırma Kaldırıldı (Ses & Mic Açık)")
    else
        ShowTip("🔕 Ses & Mikrofon Güncellendi")
}

SetMicMute(muteState) {
    global lastKnownMicMute
    SetMicMuteState(muteState)
    isMuted := GetMicMuteState()
    UpdateMicOverlay(isMuted)
    lastKnownMicMute := isMuted
}

SyncMicState(silent := true) {
    global lastKnownMicMute

    currentMute := GetMicMuteState()

    ; İlk çalışma senkronizasyonu
    if (lastKnownMicMute == -1) {
        lastKnownMicMute := currentMute
        UpdateMicOverlay(currentMute)
        return
    }

    ; Durum dışarıdan (Windows/kulaklık/donanım düğmesi) değiştiyse
    if (currentMute != lastKnownMicMute) {
        lastKnownMicMute := currentMute
        UpdateMicOverlay(currentMute)
        if (!silent) {
            PlayMicSound(currentMute)
            if (currentMute)
                ShowTip("🎙️ Mikrofon Susturuldu (MUTE)")
            else
                ShowTip("🎙️ Mikrofon Açıldı (UNMUTE)")
        }
    }
}

; ══════════════════════════════════════════
;  SES, İKON VE OVERLAY YARDIMCILARI
; ══════════════════════════════════════════

PlayMicSound(isMuted) {
    global soundFxEnabled
    if (!soundFxEnabled)
        return

    if isMuted {
        if FileExist(A_WinDir "\Media\Speech Off.wav")
            SoundPlay A_WinDir "\Media\Speech Off.wav"
        else if FileExist(A_WinDir "\Media\Windows Pop-up Blocked.wav")
            SoundPlay A_WinDir "\Media\Windows Pop-up Blocked.wav"
        else
            SoundPlay "*16"
    } else {
        if FileExist(A_WinDir "\Media\Speech On.wav")
            SoundPlay A_WinDir "\Media\Speech On.wav"
        else if FileExist(A_WinDir "\Media\Windows Navigation Start.wav")
            SoundPlay A_WinDir "\Media\Windows Navigation Start.wav"
        else
            SoundPlay "*64"
    }
}

UpdateMicOverlay(isMuted) {
    global micOverlayGui

    if (isMuted) {
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

; ══════════════════════════════════════════
;  SPOTIFY YARDIMCILARI
; ══════════════════════════════════════════

ParseSpotifyTrack(fullTitle) {
    if InStr(fullTitle, " - ") {
        parts := StrSplit(fullTitle, " - ", , 2)
        return { artist: Trim(parts[1]), title: Trim(parts[2]) }
    }
    return { artist: "Spotify", title: fullTitle }
}

GetNowPlaying() {
    global spotifyTitle

    try {
        windows := WinGetList(spotifyTitle)
        for hwnd in windows {
            fullTitle := WinGetTitle(hwnd)
            if (fullTitle = "" || fullTitle = "Spotify" || fullTitle = "Spotify Premium" || fullTitle = "Spotify Free"
                || fullTitle = "Default IME" || fullTitle = "MSCTFIME UI" || InStr(fullTitle, "GDI+"))
                continue
            return fullTitle
        }
    }
    return ""
}