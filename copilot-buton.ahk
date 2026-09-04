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
#Include "lib\MacroRecorder.ahk"
#Include "lib\AppPicker.ahk"
#Include "lib\Updater.ahk"
#Include "lib\Telemetry.ahk"

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

A_IconTip := "Copilot Button v" APP_VERSION "`n"
    . "• Sol Tık: Ayarları Aç`n"
    . "• 1 Tık: Mic | 2 Tık: Oynat/Durdur`n"
    . "• 3 Tık: Sonraki | Basılı: " activeAppName

A_TrayMenu.Delete()
A_TrayMenu.Add("Copilot Button v" APP_VERSION, ShowSettingsGUI)
A_TrayMenu.Add() ; Ayırıcı

; ── Hızlı Kontroller ──
A_TrayMenu.Add("⚙️  Ayarlar & Kontrol Paneli", ShowSettingsGUI)
A_TrayMenu.Add("🎙️  Mikrofonu Sustur / Aç", (*) => ToggleMicrophoneMute())
A_TrayMenu.Add("⏯️  Müziği Oynat / Duraklat", (*) => (Send("{Blind}{Media_Play_Pause}"), ShowPlayPauseTrackInfo()))
A_TrayMenu.Add("⏭️  Sonraki Şarkı", (*) => (Send("{Blind}{Media_Next}"), ShowNextTrackInfo()))
A_TrayMenu.Add("🎵  " activeAppName " Aç / Öne Getir", (*) => OpenMusicApp())
A_TrayMenu.Add() ; Ayırıcı

; ── Görünüm & Araçlar ──
A_TrayMenu.Add("👁️  OSD Bildirim Testi", (*) => ShowTip("✨ Copilot Tuşu v" APP_VERSION " aktif! ✨", 2000))
A_TrayMenu.Add("🔄  Güncellemeleri Denetle", (*) => CheckForUpdates(false))
A_TrayMenu.Add("🔄  Scripti Yeniden Başlat", (*) => Reload())
A_TrayMenu.Add() ; Ayırıcı

; ── Çıkış ──
A_TrayMenu.Add("❌  Çıkış", (*) => ExitApp())

; Sol Tıklama: Varsayılan menü öğesini (Ayarlar) açar
A_TrayMenu.Default := "⚙️  Ayarlar & Kontrol Paneli"
A_TrayMenu.ClickCount := 1

; ══════════════════════════════════════════
;  BAŞLANGIÇ İŞLEMLERİ & ZAMANLAYICILAR
; ══════════════════════════════════════════
; Başlangıç bildirimi
holdLabel := (holdAction = "PushToTalk") ? "Push-to-Talk" : activeAppName
ShowTip("✅ Copilot Tuşu v" APP_VERSION " aktif — " holdLabel, 2500)

; Başlangıçta mikrofon durumunu senkronize et (overlay & tray ikonu)
SyncMicState()

; Başlangıçta güncelleme kontrolü (sessiz)
SetTimer(StartupUpdateCheck, -5000)

; Başlangıçta açılış logu gönderimi (sessiz)
SetTimer(SendAppLog, -3000)