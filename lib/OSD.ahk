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
            return { x: screenW - 320, y: 45 }
        case "BottomLeft":
            return { x: 20, y: screenH - 80 }
        case "BottomRight":
            return { x: screenW - 320, y: screenH - 80 }
        case "Center":
            return { x: (screenW // 2) - 150, y: (screenH // 2) - 20 }
        default:  ; TopLeft
            return { x: 20, y: 45 }
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

    ; Eski pencere varsa temizle (böylece font, renk ve metin uzunluğu her zaman sıfırdan hesaplanır)
    if (IsObject(tipGui)) {
        try tipGui.Destroy()
        tipGui := 0
    }

    transColor := "010101"
    tipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "CopilotTipGui")
    tipGui.BackColor := transColor
    tipGui.SetFont("s" osdFontSize " bold c" osdColor, "Segoe UI")
    tipGui.Add("Text", "vTipText x0 y0", msg)

    pos := GetOsdPosition()
    tipGui.Show("x" pos.x " y" pos.y " NoActivate AutoSize")

    if (osdFadeEnabled) {
        fadeAlpha := 0
        try WinSetTransColor(transColor " 0", tipGui)
        SetTimer(FadeInTipStep, -15)
        SetTimer(StartFadeOut, -durationMs)
    } else {
        fadeAlpha := 255
        try WinSetTransColor(transColor " 255", tipGui)
        SetTimer(HideTipGui, -durationMs)
    }
}

FadeInTipStep() {
    global tipGui, fadeAlpha
    if (!IsObject(tipGui))
        return
    fadeAlpha += 35
    if (fadeAlpha >= 255) {
        fadeAlpha := 255
        try WinSetTransColor("010101 255", tipGui)
        return
    }
    try WinSetTransColor("010101 " . fadeAlpha, tipGui)
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
    try WinSetTransColor("010101 " . fadeAlpha, tipGui)
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

