; ══════════════════════════════════════════
;  CONFIG & YAPILANDIRMA MODÜLÜ
; ══════════════════════════════════════════

ReadConfigInt(section, key, defaultVal) {
    global configFile
    try
        return Integer(IniRead(configFile, section, key, defaultVal))
    catch
        return defaultVal
}

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
    ; Seçenekler: MicMute, PlayPause, NextTrack, PrevTrack, VolumeUp, VolumeDown, MasterMute, ToggleDeafen, VoiceTyping, Screenshot, TaskView, LockScreen, CustomMacro, None

    ; 1 Tık Eylemi
    Action1=MicMute

    ; 2 Tık Eylemi
    Action2=PlayPause

    ; 3 Tık Eylemi
    Action3=NextTrack

    ; 4 Tık Eylemi
    Action4=None

    ; ── Özel Makro Tuş Dizileri ──
    ; CustomMacro seçildiğinde gönderilecek tuş dizisi (AHK Send formatı)
    ; Örnekler: ^c (Ctrl+C), !{F4} (Alt+F4), #+s (Win+Shift+S), {Volume_Up 5}
    CustomMacro1=
    CustomMacro2=
    CustomMacro3=
    CustomMacro4=

    ; ── Mikrofon Cihaz Seçimi ──
    ; Auto = otomatik algıla, veya tam cihaz adı (ör. Microphone, Mikrofon, Headset Microphone)
    MicDevice=Auto

    ; ── Tray İkonu & Ses Efektleri ──

    ; Mikrofon durumuna göre tray ikonu değiştir (1 = Açık, 0 = Kapalı)
    TrayIconMicState=1

    ; Mikrofon susturma/açma ses efektlerini çal (1 = Açık, 0 = Kapalı)
    SoundFxEnabled=1

    ; ── Telemetri & Log ──
    ; Telemetri & Log Gönderimi (1 = Açık, 0 = Kapalı, varsayılan: 1)
    TelemetryEnabled=1
    ; Benzersiz Cihaz ID (boş ise otomatik oluşturulur)
    UID=
    )"

    try FileAppend(defaultConfig, path)
}

; ══════════════════════════════════════════
;  SES CİHAZI NUMARALANDIRMA
; ══════════════════════════════════════════
EnumerateCaptureDevices() {
    devices := []
    try {
        CLSID_MMDeviceEnumerator := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
        IID_IMMDeviceEnumerator  := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
        
        devEnum := ComObject(CLSID_MMDeviceEnumerator, IID_IMMDeviceEnumerator)
        ; EnumAudioEndpoints: dataFlow=1 (eCapture), dwStateMask=1 (DEVICE_STATE_ACTIVE)
        ComCall(3, devEnum, "int", 1, "uint", 1, "ptr*", &pCollection := 0)
        collection := ComValue(13, pCollection)
        
        ; IMMDeviceCollection: GetCount (index 3)
        count := 0
        ComCall(3, collection, "uint*", &count)
        
        propKey := Buffer(20, 0)
        DllCall("ole32\CLSIDFromString", "wstr", "{A45C254E-DF1C-4EFD-8020-67D146A850E0}", "ptr", propKey)
        NumPut("uint", 14, propKey, 16) ; pid = 14

        Loop count {
            idx := A_Index - 1
            ; Item (index 4)
            pDev := 0
            ComCall(4, collection, "uint", idx, "ptr*", &pDev)
            dev := ComValue(13, pDev)
            
            ; OpenPropertyStore (index 4)
            pStore := 0
            ComCall(4, dev, "uint", 0, "ptr*", &pStore)
            store := ComValue(13, pStore)
            
            ; GetValue (index 5)
            propVar := Buffer(24, 0)
            ComCall(5, store, "ptr", propKey, "ptr", propVar)
            name := StrGet(NumGet(propVar, 8, "ptr"), "UTF-16")
            if (name != "")
                devices.Push(name)
        }
    }
    return devices
}

