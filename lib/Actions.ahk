; ══════════════════════════════════════════
;  EYLEM DİSPATCH & MEDYA / MİKROFON KONTROLLERİ
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
;  MİKROFON SUSTURMA / AÇMA
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
