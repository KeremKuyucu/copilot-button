; ══════════════════════════════════════════
;  GLOBAL DEĞİŞKENLER, SABİTLER & DURUM (GLOBALS)
; ══════════════════════════════════════════

; ── Uygulama Bilgileri & Sabitler ──
global APP_VERSION := "1.1.9"
global EXPECTED_CERT_THUMBPRINT := "037728AEA36D0BB09D2D1EE111C70A2D423CC6B4"
global configFile := A_ScriptDir "\config.ini"

; İlk çalıştırmada config.ini yoksa varsayılan ayarlarla oluştur
if !FileExist(configFile)
    CreateDefaultConfig(configFile)

; ── Temel Ayarlar (config.ini) ──
global doubleTapThreshold := ReadConfigInt("Settings", "DoubleTapMs", 250)
global holdThreshold := ReadConfigInt("Settings", "HoldMs", 250)
global autoStart := ReadConfigInt("Settings", "AutoStart", 1)

; ── Müzik Oynatıcı Ayarları ──
global musicApp := IniRead(configFile, "Settings", "MusicApp", "YTM")
global ytmUrl := IniRead(configFile, "Settings", "YtmURL", "https://music.youtube.com")
global ytmTitle := IniRead(configFile, "Settings", "YtmWindowTitle", "YouTube Music")
global spotifyCmd := IniRead(configFile, "Settings", "SpotifyCmd", "spotify:")
global spotifyTitle := IniRead(configFile, "Settings", "SpotifyWindowTitle", "ahk_exe spotify.exe")

; ── OSD & Tema Ayarları ──
global themeMode := IniRead(configFile, "Settings", "Theme", "Dark")
global osdPosition := IniRead(configFile, "Settings", "OsdPosition", "TopLeft")
global osdColor := IniRead(configFile, "Settings", "OsdColor", "00E5FF")
global osdFontSize := ReadConfigInt("Settings", "OsdFontSize", 10)
global osdDurationMs := ReadConfigInt("Settings", "OsdDurationMs", 1500)
global osdFadeEnabled := ReadConfigInt("Settings", "OsdFadeEnabled", 1)

; ── Basılı Tutma & Eylem Atamaları ──
global holdAction := IniRead(configFile, "Settings", "HoldAction", "MusicApp")
global customAppPath := IniRead(configFile, "Settings", "CustomAppPath", "")
global action1 := IniRead(configFile, "Settings", "Action1", "MicMute")
global action2 := IniRead(configFile, "Settings", "Action2", "PlayPause")
global action3 := IniRead(configFile, "Settings", "Action3", "NextTrack")
global action4 := IniRead(configFile, "Settings", "Action4", "PrevTrack")
global trayIconMicState := ReadConfigInt("Settings", "TrayIconMicState", 1)
global soundFxEnabled := ReadConfigInt("Settings", "SoundFxEnabled", 1)
global telemetryEnabled := ReadConfigInt("Settings", "TelemetryEnabled", 1)

; ── Mikrofon Cihaz Seçimi ──
global micDevice := IniRead(configFile, "Settings", "MicDevice", "Auto")

; ── Özel Makro Tuş Dizileri ──
global customMacro1 := IniRead(configFile, "Settings", "CustomMacro1", "")
global customMacro2 := IniRead(configFile, "Settings", "CustomMacro2", "")
global customMacro3 := IniRead(configFile, "Settings", "CustomMacro3", "")
global customMacro4 := IniRead(configFile, "Settings", "CustomMacro4", "")
global customMacroHold := IniRead(configFile, "Settings", "CustomMacroHold", "")

; ── Çalışma Zamanı (Runtime) Durum Değişkenleri ──
global isKeyDown := false
global holdTriggered := false   ; Basılı tutma eyleminin tetiklenip tetiklenmediği
global tapCount := 0            ; Arka arkaya tıklama sayısı
global settingsGui := 0         ; GUI pencere nesnesi
global micOverlayGui := 0       ; Mikrofon kapalı OSD penceresi
global fadeTimer := 0           ; Fade animasyon zamanlayıcısı
global fadeAlpha := 0           ; Mevcut saydamlık değeri (0-255)
global pttActive := false       ; Push-to-Talk aktif mi
global tipGui := 0              ; Anlık bildirim OSD penceresi
global lastKnownMicMute := -1     ; Son bilinen mikrofon susturma durumu

; ── 3-State Anti-Leak Hook Değişkenleri ──
global copilotState := "idle"   ; "idle", "waiting", "copilot", "passed"
global shiftState := "idle"     ; "idle", "waiting", "passed"
global shiftSuppressed := false ; LShift/RShift bastırıldı mı
global winSuppressed := false   ; LWin/RWin bastırıldı mı
global copilotJustReleased := 0 ; Bırakma zamanı damgası (trailing modifier bastırma)
