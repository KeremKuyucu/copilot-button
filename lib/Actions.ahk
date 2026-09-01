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
;  MİKROFON CİHAZ ÇÖZÜMLEME
; ══════════════════════════════════════════
; Kullanıcının seçtiği veya otomatik algılanan mikrofon cihazını döndürür.
; Dönen değer: { device: "CihazAdı", component: "" } veya { device: "Capture", component: "Master" }
; Bulunamadıysa boş string döner.
GetMicDeviceId() {
    global micDevice

    ; Kullanıcı belirli bir cihaz seçtiyse direkt onu kullan
    if (micDevice != "Auto" && micDevice != "") {
        try {
            SoundGetMute(, micDevice)
            return { device: micDevice, component: "" }
        } catch {
            ; Seçili cihaz bulunamadı, otomatik algılamaya düş
        }
    }

    ; Otomatik algılama: Çoklu strateji
    ; Strateji 1: Varsayılan capture cihazı
    try {
        SoundGetMute(, "Capture:1")
        return { device: "Capture:1", component: "" }
    }

    ; Strateji 2: Bilinen cihaz adları
    micNames := ["Microphone", "Mikrofon", "Microphone Array", "Mikrofon Dizisi",
                  "Internal Microphone", "Headset Microphone"]
    for _, micName in micNames {
        try {
            SoundGetMute(, micName)
            return { device: micName, component: "" }
        }
    }

    ; Strateji 3: Master + Capture
    try {
        SoundGetMute("Master", "Capture")
        return { device: "Capture", component: "Master" }
    }

    return ""
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

    mic := GetMicDeviceId()
    if (mic != "") {
        try {
            if (mic.component != "")
                SoundSetMute(-1, mic.component, mic.device)
            else
                SoundSetMute(-1, , mic.device)

            if (mic.component != "")
                isMicMuted := SoundGetMute(mic.component, mic.device)
            else
                isMicMuted := SoundGetMute(, mic.device)
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
    mic := GetMicDeviceId()
    if (mic = "") {
        ShowTip("⚠️ Mikrofon cihazı bulunamadı! Ayarlardan cihaz seçin.", 3000)
        return
    }

    isMuted := false
    try {
        if (mic.component != "")
            SoundSetMute(-1, mic.component, mic.device)
        else
            SoundSetMute(-1, , mic.device)

        if (mic.component != "")
            isMuted := SoundGetMute(mic.component, mic.device)
        else
            isMuted := SoundGetMute(, mic.device)
    } catch as err {
        ShowTip("⚠️ Mikrofon erişim hatası: " . err.Message, 2000)
        return
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
    mic := GetMicDeviceId()
    if (mic != "") {
        try {
            if (mic.component != "")
                SoundSetMute(muteState, mic.component, mic.device)
            else
                SoundSetMute(muteState, , mic.device)
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
            micOverlayGui.SetFont("s11 bold cFF4444", "Segoe UI")
            micOverlayGui.Add("Text", "x0 y0", "🔴 MİKROFON KAPALI")
        }
        ; Sol üst köşede (x: 20, y: 15) arkaplansız saydam olarak göster
        micOverlayGui.Show("x20 y15 NoActivate AutoSize")
        try WinSetTransColor("010101 255", micOverlayGui)
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
