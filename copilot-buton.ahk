;@Ahk2Exe-SetMainIcon assets\logo.ico
;@Ahk2Exe-SetProductName Copilot Button Controller
;@Ahk2Exe-SetDescription Windows Copilot Key Media & Mic Controller
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Kerem Kuyucu
;@Ahk2Exe-SetCompanyName Kerem Kuyucu
;@Ahk2Exe-SetOrigFilename CopilotButton.exe

#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook true
InstallKeybdHook()
A_MaxHotkeysPerInterval := 2000
A_MenuMaskKey := "vkE8"
SetTitleMatchMode 2

; ══════════════════════════════════════════
;  MODÜLLERİ DAHİL ET (#Include)
; ══════════════════════════════════════════
#Include "lib\Config.ahk"
#Include "lib\Globals.ahk"
#Include "lib\OSD.ahk"
#Include "lib\Actions.ahk"
#Include "lib\KeyHook.ahk"
#Include "lib\GUI.ahk"
#Include "lib\Updater.ahk"
#Include "lib\Telemetry.ahk"

; ══════════════════════════════════════════
;  TRAY İKONU VE MENÜSÜ
; ══════════════════════════════════════════
; Varsayılan AutoHotkey ikonunu kullan
TraySetIcon("*")

A_IconTip := "Copilot Button"

A_TrayMenu.Delete()
A_TrayMenu.Add("⚙️  Ayarlar", ShowSettingsGUI)
A_TrayMenu.Add("❌  Çıkış", (*) => ExitApp())

; ══════════════════════════════════════════
;  BAŞLANGIÇ İŞLEMLERİ & ZAMANLAYICILAR
; ══════════════════════════════════════════
; Başlangıç bildirimi
holdLabel := (holdAction = "PushToTalk") ? "Push-to-Talk" : "Özel Uygulama"
ShowTip("✅ Copilot Tuşu v" APP_VERSION " aktif — " holdLabel, 2500)

; Başlangıçta mikrofon durumunu senkronize et ve harici/donanım değişikliklerini sürekli izle
SyncMicState()
SetTimer(SyncMicState, 1000)

; Spotify şarkı değişimini otomatik izleyen arka plan zamanlayıcısı
lastSpotifyTrack := GetNowPlaying()
if (spotifyTrackOsdEnabled)
    SetTimer(WatchSpotifyTrackChange, 1000)

WatchSpotifyTrackChange() {
    global lastSpotifyTrack, spotifyTrackOsdEnabled
    if (!spotifyTrackOsdEnabled)
        return

    nowPlaying := GetNowPlaying()

    if (nowPlaying = "") {
        lastSpotifyTrack := ""
        return
    }

    if (nowPlaying != lastSpotifyTrack) {
        lastSpotifyTrack := nowPlaying
        parsed := ParseSpotifyTrack(nowPlaying)
        ShowSpotifyTrackOSD(parsed.title, parsed.artist)
    }
}

; Başlangıçta güncelleme kontrolü (sessiz)
SetTimer(StartupUpdateCheck, -5000)

; Başlangıçta açılış logu gönderimi (sessiz)
SetTimer(SendAppLog, -3000)