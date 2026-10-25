; ══════════════════════════════════════════
;  OSD & EKRAN BİLDİRİM SİSTEMİ
; ══════════════════════════════════════════

GetOsdPosition() {
    global osdPosition

    ; Ekran boyutlarını al
    screenW := A_ScreenWidth
    screenH := A_ScreenHeight

    switch osdPosition {
        case "TopRight":
            return { x: screenW - 340, y: 45 }
        case "BottomLeft":
            return { x: 20, y: screenH - 90 }
        case "BottomRight":
            return { x: screenW - 340, y: screenH - 90 }
        case "Center":
            return { x: (screenW // 2) - 150, y: (screenH // 2) - 30 }
        default:  ; TopLeft
            return { x: 20, y: 55 }
    }
}

ShowTip(msg, durationMs := 0) {
    global tipGui, osdColor, osdFontSize, osdDurationMs, osdFadeEnabled, fadeAlpha

    ; Varsayılan süre config'den gelir
    if (durationMs = 0)
        durationMs := osdDurationMs

    ; Önceki tüm zamanlayıcıları kesin olarak durdur (çakışmaları engelle)
    SetTimer(FadeInTipStep, 0)
    SetTimer(StartFadeOut, 0)
    SetTimer(FadeOutTipStep, 0)
    SetTimer(HideTipGui, 0)

    ; Eski pencere varsa temizle
    if (IsObject(tipGui)) {
        try tipGui.Destroy()
        tipGui := 0
    }

    ; Modern koyu kart arka planı ve Windows 11 yuvarlatılmış köşeleri
    tipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "CopilotTipGui")
    tipGui.BackColor := "121824"
    tipGui.MarginX := 16
    tipGui.MarginY := 8
    tipGui.SetFont("s" osdFontSize " bold c" osdColor, "Segoe UI")
    tipGui.Add("Text", "vTipText x14 y8", msg)

    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", tipGui.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)

    pos := GetOsdPosition()
    tipGui.Show("x" pos.x " y" pos.y " NoActivate AutoSize")

    if (osdFadeEnabled) {
        fadeAlpha := 0
        try WinSetTransparent(0, tipGui)
        SetTimer(FadeInTipStep, -15)
        SetTimer(StartFadeOut, -durationMs)
    } else {
        fadeAlpha := 240
        try WinSetTransparent(240, tipGui)
        SetTimer(HideTipGui, -durationMs)
    }
}

FadeInTipStep() {
    global tipGui, fadeAlpha
    if (!IsObject(tipGui))
        return
    fadeAlpha += 35
    if (fadeAlpha >= 240) {
        fadeAlpha := 240
        try WinSetTransparent(240, tipGui)
        return
    }
    try WinSetTransparent(fadeAlpha, tipGui)
    SetTimer(FadeInTipStep, -15)
}

StartFadeOut() {
    global osdFadeEnabled
    if (osdFadeEnabled)
        SetTimer(FadeOutTipStep, -15)
    else
        HideTipGui()
}

FadeOutTipStep() {
    global tipGui, fadeAlpha
    if (!IsObject(tipGui))
        return
    fadeAlpha -= 30
    if (fadeAlpha <= 0) {
        HideTipGui()
        return
    }
    try WinSetTransparent(fadeAlpha, tipGui)
    SetTimer(FadeOutTipStep, -15)
}

HideTipGui() {
    global tipGui
    SetTimer(FadeInTipStep, 0)
    SetTimer(StartFadeOut, 0)
    SetTimer(FadeOutTipStep, 0)
    SetTimer(HideTipGui, 0)
    if (IsObject(tipGui)) {
        try tipGui.Destroy()
        tipGui := 0
    }
}

; ══════════════════════════════════════════
;  SPOTIFY ŞARKI DEĞİŞİMİ ÖZEL OSD BİLDİRİMİ
; ══════════════════════════════════════════
global spotOsdGui := 0
global spotFadeAlpha := 0

GetTrackOsdPosition(w := 360, h := 74) {
    global osdPosition
    screenW := A_ScreenWidth
    screenH := A_ScreenHeight

    switch osdPosition {
        case "TopRight":
            return { x: screenW - w - 24, y: 45 }
        case "BottomLeft":
            return { x: 24, y: screenH - h - 45 }
        case "BottomRight":
            return { x: screenW - w - 24, y: screenH - h - 45 }
        case "Center":
            return { x: (screenW - w) // 2, y: (screenH - h) // 2 }
        default:  ; TopLeft
            return { x: 24, y: 45 }
    }
}

ShowSpotifyTrackOSD(songTitle, artistName := "", durationMs := 0) {
    global spotOsdGui, osdDurationMs, osdFadeEnabled, spotFadeAlpha

    if (durationMs = 0)
        durationMs := Max(osdDurationMs, 2800)

    SetTimer(FadeInSpotStep, 0)
    SetTimer(StartFadeOutSpot, 0)
    SetTimer(FadeOutSpotStep, 0)
    SetTimer(HideSpotOsdGui, 0)

    if (IsObject(spotOsdGui)) {
        try spotOsdGui.Destroy()
        spotOsdGui := 0
    }

    w := 360
    h := 74

    spotOsdGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "SpotifyTrackOSD")
    spotOsdGui.BackColor := "0E131F"
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", spotOsdGui.Hwnd, "UInt", 20, "Int*", 1, "UInt", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", spotOsdGui.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)

    ; Sol kenar Spotify yeşili vurgu şeridi
    spotOsdGui.Add("Text", "x0 y0 w4 h" h " Background1DB954")
    ; Çerçeve kenar çizgileri
    spotOsdGui.Add("Text", "x0 y0 w" w " h1 Background1E293B")
    spotOsdGui.Add("Text", "x0 y" (h-1) " w" w " h1 Background1E293B")
    spotOsdGui.Add("Text", "x" (w-1) " y0 w1 h" h " Background1E293B")

    ; Spotify ikonu
    spotOsdGui.SetFont("s16 bold c1DB954", "Segoe UI")
    spotOsdGui.Add("Text", "x14 y16 w32 h38 Center 0x200 BackgroundTrans", "🎧")

    ; Rozet başlığı
    spotOsdGui.SetFont("s7.5 bold c1DB954", "Segoe UI Variable Display")
    spotOsdGui.Add("Text", "x52 y10 w295 h14 BackgroundTrans", "SPOTIFY  •  ŞİMDİ ÇALIYOR")

    ; Şarkı adı (bold, beyaz)
    displayTitle := (songTitle != "") ? songTitle : "Bilinmeyen Parça"
    if (StrLen(displayTitle) > 34)
        displayTitle := SubStr(displayTitle, 1, 32) "..."
    spotOsdGui.SetFont("s10.5 bold cFFFFFF", "Segoe UI")
    spotOsdGui.Add("Text", "x52 y26 w295 h22 BackgroundTrans", displayTitle)

    ; Sanatçı adı
    displayArtist := (artistName != "") ? artistName : "Spotify"
    if (StrLen(displayArtist) > 42)
        displayArtist := SubStr(displayArtist, 1, 40) "..."
    spotOsdGui.SetFont("s8.5 c94A3B8", "Segoe UI")
    spotOsdGui.Add("Text", "x52 y49 w295 h18 BackgroundTrans", displayArtist)

    pos := GetTrackOsdPosition(w, h)
    spotOsdGui.Show("x" pos.x " y" pos.y " w" w " h" h " NoActivate")

    if (osdFadeEnabled) {
        spotFadeAlpha := 0
        try WinSetTransparent(0, spotOsdGui)
        SetTimer(FadeInSpotStep, -15)
        SetTimer(StartFadeOutSpot, -durationMs)
    } else {
        spotFadeAlpha := 245
        try WinSetTransparent(245, spotOsdGui)
        SetTimer(HideSpotOsdGui, -durationMs)
    }
}

FadeInSpotStep() {
    global spotOsdGui, spotFadeAlpha
    if (!IsObject(spotOsdGui))
        return
    spotFadeAlpha += 35
    if (spotFadeAlpha >= 245) {
        spotFadeAlpha := 245
        try WinSetTransparent(245, spotOsdGui)
        return
    }
    try WinSetTransparent(spotFadeAlpha, spotOsdGui)
    SetTimer(FadeInSpotStep, -15)
}

StartFadeOutSpot() {
    global osdFadeEnabled
    if (osdFadeEnabled)
        SetTimer(FadeOutSpotStep, -15)
    else
        HideSpotOsdGui()
}

FadeOutSpotStep() {
    global spotOsdGui, spotFadeAlpha
    if (!IsObject(spotOsdGui))
        return
    spotFadeAlpha -= 25
    if (spotFadeAlpha <= 0) {
        HideSpotOsdGui()
        return
    }
    try WinSetTransparent(spotFadeAlpha, spotOsdGui)
    SetTimer(FadeOutSpotStep, -15)
}

HideSpotOsdGui() {
    global spotOsdGui
    SetTimer(FadeInSpotStep, 0)
    SetTimer(StartFadeOutSpot, 0)
    SetTimer(FadeOutSpotStep, 0)
    SetTimer(HideSpotOsdGui, 0)
    if (IsObject(spotOsdGui)) {
        try spotOsdGui.Destroy()
        spotOsdGui := 0
    }
}


