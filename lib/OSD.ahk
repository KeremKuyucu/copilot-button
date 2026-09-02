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

