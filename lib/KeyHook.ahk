; ══════════════════════════════════════════
;  COPILOT TUŞ YAKALAMA & ANTI-LEAK HOOK MODÜLÜ
; ══════════════════════════════════════════

; --- Windows Tuşu Yakalama (LWin / RWin) ---
$*LWin::
$*RWin::
{
    global copilotState, winSuppressed, shiftState
    if (copilotState = "copilot") {
        ; Copilot basılıyken donanımın tekrarladığı Win sinyalini tamamen yut
        return
    }

    copilotState := "waiting"
    winSuppressed := true
    SetTimer(PassModifiers, -25)
}

$*LWin Up::
$*RWin Up::
{
    global copilotState, winSuppressed, shiftSuppressed, copilotJustReleased

    ; Copilot henüz bırakıldıysa trailing Win Up sinyalini tamamen yut
    if (copilotState = "copilot" || A_TickCount < copilotJustReleased) {
        winSuppressed := false
        return
    }

    if (copilotState = "waiting") {
        SetTimer(PassModifiers, 0)
        copilotState := "idle"
        if (shiftSuppressed) {
            shiftSuppressed := false
            winSuppressed := false
            SendInput "{Blind}{LWin Down}{LShift Down}{LShift Up}{LWin Up}"
        } else {
            winSuppressed := false
            SendInput "{Blind}{LWin Down}{LWin Up}"
        }
    } else if (copilotState = "passed") {
        copilotState := "idle"
        winSuppressed := false
        SendInput "{Blind}{LWin Up}"
    }
}

; --- Shift Tuşu Yakalama (LShift / RShift) ---
$*LShift::
$*RShift::
{
    global copilotState, shiftState, shiftSuppressed
    if (copilotState = "copilot") {
        ; Copilot basılıyken donanımın tekrarladığı Shift sinyalini tamamen yut
        return
    }
    if (copilotState = "waiting") {
        ; Win tuşundan hemen sonra Shift geldi -> bu Copilot tuş dizisidir, bastır!
        shiftSuppressed := true
        return
    }

    ; Bağımsız Shift basımı: Çok kısa (15ms) bekle (arkasından Win+F23 gelebilir mi?)
    shiftState := "waiting"
    SetTimer(PassShiftOnly, -15)
}

$*LShift Up::
$*RShift Up::
{
    global copilotState, shiftState, shiftSuppressed, copilotJustReleased

    ; Copilot basılıyken veya yeni bırakıldıysa trailing Shift Up sinyalini tamamen yut
    if (copilotState = "copilot" || A_TickCount < copilotJustReleased) {
        shiftSuppressed := false
        return
    }
    if (shiftSuppressed) {
        shiftSuppressed := false
        return
    }
    if (shiftState = "waiting") {
        SetTimer(PassShiftOnly, 0)
        shiftState := "idle"
        SendInput "{Blind}{LShift Down}{LShift Up}"
        return
    }
    if (shiftState = "passed") {
        shiftState := "idle"
        SendInput "{Blind}{LShift Up}"
    }
}

PassShiftOnly() {
    global shiftState, copilotState
    if (shiftState = "waiting" && copilotState != "copilot") {
        shiftState := "passed"
        SendInput "{Blind}{LShift Down}"
    }
}

PassModifiers() {
    global copilotState, shiftState, shiftSuppressed, winSuppressed
    if (copilotState = "waiting") {
        copilotState := "passed"
        if (shiftSuppressed || shiftState = "waiting") {
            shiftSuppressed := false
            shiftState := "passed"
            SendInput "{Blind}{LWin Down}{LShift Down}"
        } else {
            SendInput "{Blind}{LWin Down}"
        }
    }
}

; ══════════════════════════════════════════
;  COPILOT TUŞU TETİKLEME (F23 / SC06E / Launch_App1)
; ══════════════════════════════════════════
$*SC06E::
$*vk86::
$*vkB6::
{
    global copilotState, shiftState, shiftSuppressed, winSuppressed
    global isKeyDown, holdTriggered, holdThreshold, pttActive

    ; Zamanlayıcıları hemen durdur ve tamponları temizle (Shift/Win tamamen yok edilir)
    SetTimer(PassModifiers, 0)
    SetTimer(PassShiftOnly, 0)
    copilotState := "copilot"
    shiftState := "idle"
    shiftSuppressed := false
    winSuppressed := false

    if (isKeyDown)
        return

    isKeyDown := true
    holdTriggered := false

    ; Tıklama sayacı zamanlayıcısını geçici olarak durdur
    SetTimer(CheckMultiPress, 0)

    ; Basılı tutma zamanlayıcısını başlat
    SetTimer(CheckHoldTimer, -holdThreshold)
}

$*SC06E Up::
$*vk86 Up::
$*vkB6 Up::
{
    global copilotState, shiftState, isKeyDown, doubleTapThreshold, holdTriggered, tapCount, pttActive,
        copilotJustReleased

    copilotState := "idle"
    shiftState := "idle"
    copilotJustReleased := A_TickCount + 80  ; 80ms boyunca ardışık Win Up/Shift Up sinyallerini bastır

    if (!isKeyDown)
        return

    isKeyDown := false
    SetTimer(CheckHoldTimer, 0)   ; Tuş bırakıldıysa hold timer'ı iptal et

    ; Push-to-Talk: tuş bırakıldığında mikrofonu sustur
    if (pttActive) {
        pttActive := false
        SetMicMute(true)
        ShowTip("🎙️ PTT — Mikrofon Susturuldu")
        return
    }

    ; Eğer basılı tutma eylemi zaten çalıştıysa, tıklama işlemlerini atla
    if (holdTriggered) {
        tapCount := 0
        return
    }

    ; Tıklama sayısını artır ve zamanlayıcıyı başlat
    tapCount++
    SetTimer(CheckMultiPress, -doubleTapThreshold)
}

CheckMultiPress() {
    global tapCount, action1, action2, action3, action4

    count := tapCount
    tapCount := 0   ; Sayacı sıfırla

    ; Tık sayısına göre atanmış eylemi çalıştır
    switch count {
        case 1: RunAction(action1, 1)
        case 2: RunAction(action2, 2)
        case 3: RunAction(action3, 3)
        case 4: RunAction(action4, 4)
        default:
            ShowTip("⚠️ " count " Tık (Atanmış eylem yok)")
    }
}

CheckHoldTimer() {
    global holdTriggered, holdAction, pttActive
    global musicApp, ytmUrl, ytmTitle, spotifyCmd, spotifyTitle, customAppPath, customMacroHold

    holdTriggered := true
    SetTimer(CheckHoldTimer, 0)

    ; Push-to-Talk modu
    if (holdAction = "PushToTalk") {
        pttActive := true
        SetMicMute(false)
        PlayMicSound(false)
        ShowTip("🎙️ PTT — Mikrofon Açık (konuş...)")
        return
    }

    ; Özel uygulama / URL modu
    if (holdAction = "CustomApp") {
        if (customAppPath != "") {
            try {
                Run customAppPath
                ; Dosya adını veya URL'yi OSD'de göster
                displayName := RegExReplace(customAppPath, "^.*\\", "")  ; Son \\ sonrasını al
                if (displayName = "")
                    displayName := customAppPath
                ShowTip("🚀 " displayName " açılıyor...")
            } catch as err {
                ShowTip("⚠️ Açılamadı: " err.Message, 2500)
            }
        } else {
            ShowTip("⚠️ Özel uygulama yolu ayarlanmamış!", 2500)
        }
        return
    }

    ; Özel Makro modu
    if (holdAction = "CustomMacro") {
        if (customMacroHold != "") {
            try {
                Send customMacroHold
                ShowTip("🎹 Makro gönderildi: " customMacroHold)
            } catch as err {
                ShowTip("⚠️ Makro hatası: " err.Message, 2500)
            }
        } else {
            ShowTip("⚠️ Basılı tutma makrosu tanımlı değil! Ayarlardan makro girin.", 2500)
        }
        return
    }

    ; Müzik uygulaması modu
    OpenMusicApp()
}
