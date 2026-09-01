; ══════════════════════════════════════════
;  MAKRO KAYDEDİCİ & TUŞ YAKALAMA MODÜLÜ
; ══════════════════════════════════════════

global recGui := 0
global recTargetEdit := 0
global recInputHook := 0
global recIsLiveRecording := false
global recMode := "single" ; "single" (Kısayol) veya "sequence" (Sıralı Dizi)

; ══════════════════════════════════════════
;  ANA KAYIT PENCERESİNİ AÇ
; ══════════════════════════════════════════
OpenMacroRecorder(tapIndex, targetEditCtrl, parentGui := 0) {
    global recGui, recTargetEdit, recInputHook, recIsLiveRecording, recMode

    ; Eğer açık bir kayıt penceresi varsa kapat
    CloseMacroRecorder()

    recTargetEdit := targetEditCtrl
    recIsLiveRecording := false
    recMode := "single"

    isDark := (GetEffectiveTheme() = "Dark")

    if (isDark) {
        bgColor := "0E121B"
        cardBgColor := "161C2A"
        textColor := "FFFFFF"
        subTextColor := "8FA8C8"
        dimTextColor := "5D7699"
        accentBlue := "0078D4"
        darkBlueBtn := "0067C0"
        editBgColor := "182030"
        borderClr := "233046"
        badgeBg := "202D44"
        activeCardBg := "1A2538"
    } else {
        bgColor := "F0F4FA"
        cardBgColor := "FFFFFF"
        textColor := "0F172A"
        subTextColor := "334155"
        dimTextColor := "64748B"
        accentBlue := "0078D4"
        darkBlueBtn := "0067C0"
        editBgColor := "FFFFFF"
        borderClr := "CBD5E1"
        badgeBg := "E2EAF4"
        activeCardBg := "EAF1FA"
    }
    editOpt := "Background" editBgColor " c" textColor

    tapLabels := ["1 Tık (Tek Basım)", "2 Tık (Çift Basım)", "3 Tık (Üç Basım)", "4 Tık (Dört Basım)"]
    currentTapLabel := (tapIndex >= 1 && tapIndex <= 4) ? tapLabels[tapIndex] : (tapIndex . ". Tık")

    recGui := Gui("+AlwaysOnTop -MinimizeBox +Owner" . (parentGui ? parentGui.Hwnd : ""),
        "🎹 Makro Kaydedici — " currentTapLabel)
    recGui.BackColor := bgColor
    recGui.SetFont("s9 c" textColor, "Segoe UI")

    SetWindowDarkMode(recGui.Hwnd, isDark)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", recGui.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)

    ; Buton HWND Haritası (Hover el imleci için)
    recBtnHwnds := Map()
    RegRecBtn(ctrl) => (recBtnHwnds[ctrl.Hwnd] := true, ctrl)

    ; ── ÜST BAŞLIK ──
    recGui.SetFont("s11 bold c" textColor, "Segoe UI")
    recGui.Add("Text", "x20 y14 w480 h24", "🎹 Makro & Kısayol Tuşu Kaydedici")

    recGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    recGui.Add("Text", "x20 y38 w480 h18",
        "Klavyenizden istediğiniz tuşa basın veya aşağıdaki hazır şablonları kullanın.")

    ; Ayırıcı Çizgi
    recGui.Add("Text", "x0 y62 w520 h1 Background" borderClr)

    ; ── MOD SEÇİMİ ──
    recGui.SetFont("s9 bold c" textColor, "Segoe UI")
    radSingle := recGui.Add("Radio", "x20 y72 w220 h24 Checked", "⚡ Tek Kısayol Yakala")
    radSeq := recGui.Add("Radio", "x250 y72 w250 h24", "🔴 Sıralı Tuş Dizisi Kaydet")

    ; ── CANLI YAKALAMA KARTI ──
    recGui.Add("GroupBox", "x20 y102 w480 h120", "🔴 Canlı Tuş Yakalama Alanı")

    recGui.SetFont("s9 bold c00A3FF", "Segoe UI")
    lblStatus := recGui.Add("Text", "x35 y124 w450 h20 Center",
        "⚡ Tuş Yakalama Hazır: Klavyenizden herhangi bir tuşa/kısayola basın...")

    ; Görsel Tuş Rozetleri Alanı
    recGui.SetFont("s12 bold c" textColor, "Segoe UI")
    lblKeyBadge := recGui.Add("Text", "x35 y148 w450 h36 Center 0x200 Background" badgeBg,
        "[ Tuş Bekleniyor ]")

    recGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    lblAhkPreview := recGui.Add("Text", "x35 y190 w450 h20 Center",
        "AHK Kodu: (Boş)")

    ; ── SIRALI KAYIT KONTROL BUTONLARI (Varsayılan Pasif / Gizli) ──
    recGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnToggleLive := RegRecBtn(recGui.Add("Text",
        "x20 y228 w130 h26 Background" accentBlue " cFFFFFF Center 0x200", "🔴 Kaydı Başlat"))
    btnClearSeq := RegRecBtn(recGui.Add("Text",
        "x158 y228 w100 h26 Background" darkBlueBtn " cFFFFFF Center 0x200", "🧹 Temizle"))
    btnBackSeq := RegRecBtn(recGui.Add("Text",
        "x266 y228 w110 h26 Background" darkBlueBtn " cFFFFFF Center 0x200", "⌫ Son Tuşu Sil"))

    btnToggleLive.Visible := false
    btnClearSeq.Visible := false
    btnBackSeq.Visible := false

    ; ── HAZIR ŞABLONLAR & ÖZEL TUŞLAR KARTI ──
    recGui.SetFont("s9 c" textColor, "Segoe UI")
    recGui.Add("GroupBox", "x20 y262 w480 h95", "⚡ Hazır Kısayollar & Özel Tuş Ekle")

    recGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    recGui.Add("Text", "x35 y286 w110 h20", "Hazır Kısayol:")

    presetList := [
        "— Popüler Bir Kısayol Seçin —",
        "📋 Kopyala (Ctrl+C)",
        "📋 Yapıştır (Ctrl+V)",
        "✂️ Kes (Ctrl+X)",
        "↩️ Geri Al (Ctrl+Z)",
        "💾 Kaydet (Ctrl+S)",
        "🔍 Bul (Ctrl+F)",
        "🖨️ Yazdır (Ctrl+P)",
        "🌐 Yeni Sekme (Ctrl+T)",
        "🌐 Sekmeyi Kapat (Ctrl+W)",
        "❌ Pencereyi Kapat (Alt+F4)",
        "🔀 Uygulama Değiştir (Alt+Tab)",
        "🖥️ Masaüstünü Göster (Win+D)",
        "🔒 Ekranı Kilitle (Win+L)",
        "📸 Ekran Alıntısı (Win+Shift+S)",
        "🗂️ Görev Yöneticisi (Ctrl+Shift+Esc)",
        "🔍 Windows Arama (Win+S)",
        "⚙️ Windows Ayarlar (Win+I)",
        "📂 Dosya Gezgini (Win+E)",
        "🏃 Çalıştır (Win+R)",
        "🔊 Sesi Artır (Volume Up)",
        "🔉 Sesi Azalt (Volume Down)",
        "🔇 Sesi Kapat/Aç (Volume Mute)",
        "⏯️ Oynat/Durdur (Media Play/Pause)",
        "⏭️ Sonraki Şarkı (Media Next)",
        "⏮️ Önceki Şarkı (Media Prev)"
    ]

    presetMap := Map(
        "📋 Kopyala (Ctrl+C)", "^c",
        "📋 Yapıştır (Ctrl+V)", "^v",
        "✂️ Kes (Ctrl+X)", "^x",
        "↩️ Geri Al (Ctrl+Z)", "^z",
        "💾 Kaydet (Ctrl+S)", "^s",
        "🔍 Bul (Ctrl+F)", "^f",
        "🖨️ Yazdır (Ctrl+P)", "^p",
        "🌐 Yeni Sekme (Ctrl+T)", "^t",
        "🌐 Sekmeyi Kapat (Ctrl+W)", "^w",
        "❌ Pencereyi Kapat (Alt+F4)", "!{F4}",
        "🔀 Uygulama Değiştir (Alt+Tab)", "!{Tab}",
        "🖥️ Masaüstünü Göster (Win+D)", "#d",
        "🔒 Ekranı Kilitle (Win+L)", "#l",
        "📸 Ekran Alıntısı (Win+Shift+S)", "#+s",
        "🗂️ Görev Yöneticisi (Ctrl+Shift+Esc)", "^+{Escape}",
        "🔍 Windows Arama (Win+S)", "#s",
        "⚙️ Windows Ayarlar (Win+I)", "#i",
        "📂 Dosya Gezgini (Win+E)", "#e",
        "🏃 Çalıştır (Win+R)", "#r",
        "🔊 Sesi Artır (Volume Up)", "{Volume_Up}",
        "🔉 Sesi Azalt (Volume Down)", "{Volume_Down}",
        "🔇 Sesi Kapat/Aç (Volume Mute)", "{Volume_Mute}",
        "⏯️ Oynat/Durdur (Media Play/Pause)", "{Media_Play_Pause}",
        "⏭️ Sonraki Şarkı (Media Next)", "{Media_Next}",
        "⏮️ Önceki Şarkı (Media Prev)", "{Media_Prev}"
    )

    recGui.SetFont("s8.5 c" textColor, "Segoe UI")
    ddlPresets := recGui.Add("DropDownList", "x150 y282 w335 r15 " editOpt, presetList)
    ddlPresets.Choose(1)

    recGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    recGui.Add("Text", "x35 y320 w110 h20", "Özel Tuş Ekle:")

    specialKeyList := [
        "— Özel Bir Tuş Ekle —",
        "Enter (Giriş)",
        "Tab (Sekme)",
        "Escape (İptal)",
        "Space (Boşluk)",
        "Backspace (Geri Sil)",
        "Delete (İleri Sil)",
        "Home (Satır Başı)",
        "End (Satır Sonu)",
        "Page Up (Sayfa Yukarı)",
        "Page Down (Sayfa Aşağı)",
        "Yukarı Ok (Up)",
        "Aşağı Ok (Down)",
        "Sol Ok (Left)",
        "Sağ Ok (Right)",
        "F1", "F2", "F3", "F4", "F5", "F6",
        "F7", "F8", "F9", "F10", "F11", "F12"
    ]

    specialKeyMap := Map(
        "Enter (Giriş)", "{Enter}",
        "Tab (Sekme)", "{Tab}",
        "Escape (İptal)", "{Escape}",
        "Space (Boşluk)", "{Space}",
        "Backspace (Geri Sil)", "{BS}",
        "Delete (İleri Sil)", "{Del}",
        "Home (Satır Başı)", "{Home}",
        "End (Satır Sonu)", "{End}",
        "Page Up (Sayfa Yukarı)", "{PgUp}",
        "Page Down (Sayfa Aşağı)", "{PgDn}",
        "Yukarı Ok (Up)", "{Up}",
        "Aşağı Ok (Down)", "{Down}",
        "Sol Ok (Left)", "{Left}",
        "Sağ Ok (Right)", "{Right}",
        "F1", "{F1}", "F2", "{F2}", "F3", "{F3}", "F4", "{F4}",
        "F5", "{F5}", "F6", "{F6}", "F7", "{F7}", "F8", "{F8}",
        "F9", "{F9}", "F10", "{F10}", "F11", "{F11}", "F12", "{F12}"
    )

    recGui.SetFont("s8.5 c" textColor, "Segoe UI")
    ddlSpecialKeys := recGui.Add("DropDownList", "x150 y316 w335 r15 " editOpt, specialKeyList)
    ddlSpecialKeys.Choose(1)

    ; ── OLUŞTURULAN MAKRO KUTUSU ──
    recGui.SetFont("s9 bold c" textColor, "Segoe UI")
    recGui.Add("Text", "x20 y368 w130 h22", "Oluşturulan Makro:")

    initialValue := Trim(targetEditCtrl.Value)
    recGui.SetFont("s9 c" textColor, "Segoe UI")
    edtRecorded := recGui.Add("Edit", "x150 y365 w350 h24 " editOpt, initialValue)

    ; ── ALT BUTONLAR (Test, Uygula, İptal) ──
    recGui.SetFont("s9 bold cFFFFFF", "Segoe UI")
    btnTest := RegRecBtn(recGui.Add("Text",
        "x20 y408 w100 h32 Background" darkBlueBtn " cFFFFFF Center 0x200", "👁️ Test Et"))

    btnApply := RegRecBtn(recGui.Add("Text",
        "x270 y408 w130 h32 Background" accentBlue " cFFFFFF Center 0x200", "✅ Uygula & Aktar"))

    btnCancel := RegRecBtn(recGui.Add("Text",
        "x410 y408 w90 h32 Background" borderClr " c" textColor " Center 0x200", "❌ İptal"))

    ; ── MOD DEĞİŞİKLİK OLAYLARI ──
    radSingle.OnEvent("Click", (*) => SwitchMode("single"))
    radSeq.OnEvent("Click", (*) => SwitchMode("sequence"))

    SwitchMode(mode) {
        recMode := mode
        if (mode = "single") {
            btnToggleLive.Visible := false
            btnClearSeq.Visible := false
            btnBackSeq.Visible := false
            lblStatus.Text := "⚡ Tek Kısayol Yakala: Klavyenizden bir kısayola basın..."
            recIsLiveRecording := false
            StartCaptureHook()
        } else {
            btnToggleLive.Visible := true
            btnClearSeq.Visible := true
            btnBackSeq.Visible := true
            lblStatus.Text := "🔴 Sıralı Kayıt: 'Kaydı Başlat' butonuna basın ve tuşlara sırayla basın."
            recIsLiveRecording := false
            btnToggleLive.Text := "🔴 Kaydı Başlat"
            StopCaptureHook()
        }
    }

    ; ── SIRALI KAYIT BUTONLARI ──
    btnToggleLive.OnEvent("Click", (*) => ToggleLiveRecording())

    ToggleLiveRecording() {
        if (!recIsLiveRecording) {
            recIsLiveRecording := true
            btnToggleLive.Text := "⏹️ Kaydı Durdur"
            lblStatus.Text := "🔴 CANLI KAYIT AKTİF — Bastığınız her tuş sırayla eklenecektir..."
            StartCaptureHook()
        } else {
            recIsLiveRecording := false
            btnToggleLive.Text := "🔴 Kaydı Başlat"
            lblStatus.Text := "⏹️ Kayıt Durduruldu. Yeni tuşlar için tekrar 'Kaydı Başlat'a basabilirsiniz."
            StopCaptureHook()
        }
    }

    btnClearSeq.OnEvent("Click", (*) => (
        edtRecorded.Value := "",
        lblKeyBadge.Text := "[ Temizlendi ]",
        lblAhkPreview.Text := "AHK Kodu: (Boş)"
    ))

    btnBackSeq.OnEvent("Click", (*) => RemoveLastStep())

    RemoveLastStep() {
        currentVal := Trim(edtRecorded.Value)
        if (currentVal = "")
            return

        ; Eğer son kısım {...} ise onu sil, değilse son 1 karakteri sil
        if (RegExMatch(currentVal, "(\{[^}]+\}|[\^!+#]?[a-zA-Z0-9])$", &m)) {
            newVal := SubStr(currentVal, 1, StrLen(currentVal) - StrLen(m[0]))
            edtRecorded.Value := newVal
            lblKeyBadge.Text := "[ Son Adım Silindi ]"
            lblAhkPreview.Text := "AHK Kodu: " newVal
        } else {
            edtRecorded.Value := SubStr(currentVal, 1, -1)
            lblAhkPreview.Text := "AHK Kodu: " edtRecorded.Value
        }
    }

    ; ── HAZIR ŞABLON SEÇİMİ ──
    ddlPresets.OnEvent("Change", (*) => ApplyPreset())

    ApplyPreset() {
        sel := ddlPresets.Text
        if (presetMap.Has(sel)) {
            ahkCode := presetMap[sel]
            if (recMode = "single") {
                edtRecorded.Value := ahkCode
            } else {
                edtRecorded.Value := edtRecorded.Value . ahkCode
            }
            lblKeyBadge.Text := "[ " sel " ]"
            lblAhkPreview.Text := "AHK Kodu: " edtRecorded.Value
        }
        ddlPresets.Choose(1)
    }

    ; ── ÖZEL TUŞ SEÇİMİ ──
    ddlSpecialKeys.OnEvent("Change", (*) => ApplySpecialKey())

    ApplySpecialKey() {
        sel := ddlSpecialKeys.Text
        if (specialKeyMap.Has(sel)) {
            ahkCode := specialKeyMap[sel]
            if (recMode = "single") {
                edtRecorded.Value := ahkCode
            } else {
                edtRecorded.Value := edtRecorded.Value . ahkCode
            }
            lblKeyBadge.Text := "[ " sel " ]"
            lblAhkPreview.Text := "AHK Kodu: " edtRecorded.Value
        }
        ddlSpecialKeys.Choose(1)
    }

    ; ── TEST BUTONU ──
    btnTest.OnEvent("Click", (*) => TestMacro())

    TestMacro() {
        macroToSend := Trim(edtRecorded.Value)
        if (macroToSend = "") {
            ShowTip("⚠️ Test edilecek makro boş!", 2000)
            return
        }

        ShowTip("⏳ Makro 1.5 sn sonra test edilecek. Hedef pencereye odaklanın...", 1500)
        SetTimer(() => DoSendTest(macroToSend), -1500)
    }

    DoSendTest(m) {
        try {
            Send m
            ShowTip("✅ Makro gönderildi: " m, 2000)
        } catch as err {
            ShowTip("⚠️ Makro hatası: " err.Message, 2500)
        }
    }

    ; ── UYGULA & İPTAL BUTONLARI ──
    btnApply.OnEvent("Click", (*) => (
        targetEditCtrl.Value := Trim(edtRecorded.Value),
        CloseMacroRecorder(),
        ShowTip("✅ Makro aktarıldı: " targetEditCtrl.Value, 2000)
    ))

    btnCancel.OnEvent("Click", (*) => CloseMacroRecorder())
    recGui.OnEvent("Close", (*) => CloseMacroRecorder())
    recGui.OnEvent("Escape", (*) => CloseMacroRecorder())

    ; ── HOVER İMLEÇ YÖNETİMİ (SetCursor Hand) ──
    OnMessage(0x0200, RecOnMouseMove)
    RecOnMouseMove(wParam, lParam, msg, hWnd) {
        if (recBtnHwnds.Has(hWnd)) {
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))
        }
    }

    ; ── INPUT HOOK BAŞLATMA (TUŞ YAKALAYICI) ──
    StartCaptureHook()

    StartCaptureHook() {
        global recInputHook
        StopCaptureHook()

        recInputHook := InputHook("L0 I1")
        recInputHook.KeyOpt("{All}", "+N")
        recInputHook.OnKeyDown := OnRecordedKeyDown
        recInputHook.Start()
    }

    StopCaptureHook() {
        global recInputHook
        if (recInputHook) {
            try recInputHook.Stop()
            recInputHook := 0
        }
    }

    OnRecordedKeyDown(ih, vk, sc) {
        ; Eğer kayıt penceresi aktif değilse yakalamayı atla
        if (!WinActive("ahk_id " recGui.Hwnd))
            return

        ; Modifiers durumu oku
        isCtrl := GetKeyState("Ctrl", "P")
        isShift := GetKeyState("Shift", "P")
        isAlt := GetKeyState("Alt", "P")
        isWin := GetKeyState("LWin", "P") || GetKeyState("RWin", "P")

        result := FormatKeyCombo(vk, sc, isCtrl, isShift, isAlt, isWin)

        if (result.isModifierOnly) {
            ; Yalnızca modifier basılıyken canlı önizleme
            if (result.display != "")
                lblKeyBadge.Text := "[ " result.display " + ... ]"
            return
        }

        ; Geçerli bir tuş kombinasyonu basıldı!
        lblKeyBadge.Text := "[ " result.display " ]"

        if (recMode = "single") {
            edtRecorded.Value := result.ahk
            lblAhkPreview.Text := "AHK Kodu: " result.ahk
        } else if (recIsLiveRecording) {
            edtRecorded.Value := edtRecorded.Value . result.ahk
            lblAhkPreview.Text := "AHK Kodu: " edtRecorded.Value
        }
    }

    recGui.Show("w520 h455 Center")
}

; ══════════════════════════════════════════
;  KAYIT PENCERESİNİ GÜVENLİ KAPAT
; ══════════════════════════════════════════
CloseMacroRecorder() {
    global recGui, recInputHook, recIsLiveRecording
    if (recInputHook) {
        try recInputHook.Stop()
        recInputHook := 0
    }
    recIsLiveRecording := false
    if (IsObject(recGui)) {
        try recGui.Destroy()
        recGui := 0
    }
}

; ══════════════════════════════════════════
;  TUŞ BİLGİSİNİ AHK SÖZDİZİMİNE ÇEVİRİCİ
; ══════════════════════════════════════════
FormatKeyCombo(vk, sc, isCtrl, isShift, isAlt, isWin) {
    keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))

    ; Modifiye tuşların tek başına basımı kontrolü
    if (keyName = "Control" || keyName = "LControl" || keyName = "RControl"
        || keyName = "Shift" || keyName = "LShift" || keyName = "RShift"
        || keyName = "Alt" || keyName = "LAlt" || keyName = "RAlt"
        || keyName = "LWin" || keyName = "RWin") {

        modDisp := []
        if (isCtrl)
            modDisp.Push("Ctrl")
        if (isAlt)
            modDisp.Push("Alt")
        if (isShift)
            modDisp.Push("Shift")
        if (isWin)
            modDisp.Push("Win")

        dStr := ""
        for idx, p in modDisp
            dStr .= (idx > 1 ? " + " : "") . p

        return { display: dStr, ahk: "", isModifierOnly: true }
    }

    displayParts := []
    ahkPrefix := ""

    ; Standart AHK prefix sırası: # (Win), ^ (Ctrl), ! (Alt), + (Shift)
    if (isWin) {
        displayParts.Push("Win")
        ahkPrefix .= "#"
    }
    if (isCtrl) {
        displayParts.Push("Ctrl")
        ahkPrefix .= "^"
    }
    if (isAlt) {
        displayParts.Push("Alt")
        ahkPrefix .= "!"
    }
    if (isShift) {
        displayParts.Push("Shift")
        ahkPrefix .= "+"
    }

    cleanKey := keyName
    ahkKey := ""

    ; Süslü parantez içine alınması gereken özel tuşlar
    specialKeys := Map(
        "Enter", "{Enter}",
        "Tab", "{Tab}",
        "Space", "{Space}",
        "Escape", "{Escape}",
        "Esc", "{Escape}",
        "Backspace", "{BS}",
        "Delete", "{Del}",
        "Insert", "{Ins}",
        "Home", "{Home}",
        "End", "{End}",
        "PgUp", "{PgUp}",
        "PgDn", "{PgDn}",
        "PageUp", "{PgUp}",
        "PageDown", "{PgDn}",
        "Up", "{Up}",
        "Down", "{Down}",
        "Left", "{Left}",
        "Right", "{Right}",
        "CapsLock", "{CapsLock}",
        "ScrollLock", "{ScrollLock}",
        "NumLock", "{NumLock}",
        "PrintScreen", "{PrintScreen}",
        "Pause", "{Pause}",
        "Volume_Mute", "{Volume_Mute}",
        "Volume_Up", "{Volume_Up}",
        "Volume_Down", "{Volume_Down}",
        "Media_Next", "{Media_Next}",
        "Media_Prev", "{Media_Prev}",
        "Media_Stop", "{Media_Stop}",
        "Media_Play_Pause", "{Media_Play_Pause}",
        "Browser_Back", "{Browser_Back}",
        "Browser_Forward", "{Browser_Forward}",
        "Browser_Refresh", "{Browser_Refresh}",
        "Browser_Home", "{Browser_Home}",
        "Launch_App1", "{Launch_App1}",
        "Launch_App2", "{Launch_App2}",
        "Launch_Mail", "{Launch_Mail}"
    )

    if (RegExMatch(cleanKey, "^(F\d{1,2})$")) {
        ; F1-F24 tuşları
        ahkKey := "{" cleanKey "}"
        displayParts.Push(cleanKey)
    } else if (specialKeys.Has(cleanKey)) {
        ahkKey := specialKeys[cleanKey]
        displayParts.Push(cleanKey)
    } else if (StrLen(cleanKey) = 1) {
        ; Tek karakterli harf veya sembol (a, b, 1, 2, vs.)
        displayParts.Push(StrUpper(cleanKey))
        if (InStr("#!^+{}", cleanKey))
            ahkKey := "{" cleanKey "}"
        else
            ahkKey := StrLower(cleanKey)
    } else {
        ahkKey := "{" cleanKey "}"
        displayParts.Push(cleanKey)
    }

    dispStr := ""
    for idx, p in displayParts {
        dispStr .= (idx > 1 ? " + " : "") . p
    }

    return { display: dispStr, ahk: ahkPrefix . ahkKey, isModifierOnly: false }
}
