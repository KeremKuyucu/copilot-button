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
            return { x: screenW - 300, y: 45 }
        case "BottomLeft":
            return { x: 20, y: screenH - 80 }
        case "BottomRight":
            return { x: screenW - 300, y: screenH - 80 }
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

    ; Önceki fade-out ve gizleme zamanlayıcılarını iptal et
    SetTimer(FadeOutTipStep, 0)
    SetTimer(HideTipGui, 0)

    if (!IsObject(tipGui)) {
        transColor := "010101"
        tipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "CopilotTipGui")
        tipGui.BackColor := transColor
        tipGui.SetFont("s" osdFontSize " bold c" osdColor, "Segoe UI")
        tipGui.Add("Text", "vTipText x0 y0", msg)
    } else {
        tipGui["TipText"].Value := msg
    }

    pos := GetOsdPosition()
    tipGui.Show("x" pos.x " y" pos.y " NoActivate AutoSize")

    ; TransColor'u Show() sonrasına taşıdık — bazı Windows sürümlerinde
    ; pencere gösterilmeden WS_EX_LAYERED stili düzgün uygulanmaz
    if (tipGui.HasProp("_transApplied") = false) {
        WinSetTransColor("010101", tipGui)
        tipGui._transApplied := true
    }

    ; Fade-in animasyonu
    if (osdFadeEnabled) {
        fadeAlpha := 0
        try WinSetTransparent(0, tipGui)
        SetTimer(FadeInTipStep, -10)
    } else {
        fadeAlpha := 255
        try WinSetTransparent(255, tipGui)
    }

    ; Süre sonunda fade-out veya gizleme
    if (osdFadeEnabled) {
        SetTimer(StartFadeOut, -durationMs)
    } else {
        SetTimer(HideTipGui, -durationMs)
    }
}

FadeInTipStep() {
    global tipGui, fadeAlpha
    if (!IsObject(tipGui))
        return
    fadeAlpha += 25
    if (fadeAlpha >= 255) {
        fadeAlpha := 255
        try WinSetTransparent(255, tipGui)
        return
    }
    try WinSetTransparent(fadeAlpha, tipGui)
    SetTimer(FadeInTipStep, -10)
}

StartFadeOut() {
    SetTimer(FadeOutTipStep, -10)
}

FadeOutTipStep() {
    global tipGui, fadeAlpha
    if (!IsObject(tipGui))
        return
    fadeAlpha -= 20
    if (fadeAlpha <= 0) {
        fadeAlpha := 0
        tipGui.Hide()
        try WinSetTransparent(255, tipGui)
        return
    }
    try WinSetTransparent(fadeAlpha, tipGui)
    SetTimer(FadeOutTipStep, -15)
}

HideTipGui() {
    global tipGui
    if (IsObject(tipGui)) {
        tipGui.Hide()
        try WinSetTransparent(255, tipGui)
    }
}
