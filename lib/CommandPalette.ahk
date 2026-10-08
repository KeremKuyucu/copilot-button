; ══════════════════════════════════════════
;  HIZLI KOMUT PALETİ & SPOTLIGHT MODÜLÜ
;  (Raycast / Spotlight tarzı — Tam özel çizim, ListView YOK)
; ══════════════════════════════════════════

global cmdPalGui    := 0
global cmdPalItems  := []
global cmdPalSelIdx := 1
global cmdPalRows   := []     ; Her satır için oluşturulan Text kontrol çiftleri [titleCtrl, catCtrl, bgCtrl]
global _cpColors    := Map()

; Görünür satır sayısı ve satır yüksekliği
global CP_VISIBLE   := 7
global CP_ROW_H     := 38
global CP_ROW_W     := 618
global CP_ROW_X     := 1
global CP_FIRST_Y   := 62     ; İlk satırın Y konumu
global CP_PAL_W     := 620

ShowCommandPalette(*) {
    global cmdPalGui, cmdPalItems, cmdPalSelIdx, cmdPalRows, _cpColors
    global CP_VISIBLE, CP_ROW_H, CP_ROW_W, CP_ROW_X, CP_FIRST_Y, CP_PAL_W

    if (IsObject(cmdPalGui)) {
        CloseCommandPalette()
        return
    }

    isDark := (GetEffectiveTheme() = "Dark")

    if (isDark) {
        _cpColors["bg"]       := "0D1117"
        _cpColors["border"]   := "1E2A3B"
        _cpColors["search"]   := "0D1117"
        _cpColors["text"]     := "E8EDF3"
        _cpColors["subtext"]  := "6B7F96"
        _cpColors["accent"]   := "1683E6"
        _cpColors["rowNorm"]  := "0D1117"
        _cpColors["rowSel"]   := "1A2740"
        _cpColors["rowHov"]   := "141C28"
        _cpColors["catClr"]   := "4A6080"
        _cpColors["footer"]   := "0A0F18"
        _cpColors["divider"]  := "1A2236"
        _cpColors["pill"]     := "192030"
        _cpColors["pillText"] := "6B8BAA"
    } else {
        _cpColors["bg"]       := "FFFFFF"
        _cpColors["border"]   := "D4DCE8"
        _cpColors["search"]   := "FFFFFF"
        _cpColors["text"]     := "1A2332"
        _cpColors["subtext"]  := "7080A0"
        _cpColors["accent"]   := "0B6FD8"
        _cpColors["rowNorm"]  := "FFFFFF"
        _cpColors["rowSel"]   := "EAF2FE"
        _cpColors["rowHov"]   := "F5F8FC"
        _cpColors["catClr"]   := "8898B4"
        _cpColors["footer"]   := "F5F7FA"
        _cpColors["divider"]  := "E4EAF2"
        _cpColors["pill"]     := "EDF0F5"
        _cpColors["pillText"] := "7888A8"
    }

    w  := CP_PAL_W
    h  := CP_FIRST_Y + CP_VISIBLE * CP_ROW_H + 36  ; footer için +36
    posX := (A_ScreenWidth  - w) // 2
    posY := (A_ScreenHeight - h) // 3

    cmdPalGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "Copilot Command Palette")
    cmdPalGui.BackColor := _cpColors["bg"]
    cmdPalGui.SetFont("s10 c" _cpColors["text"], "Segoe UI")
    SetWindowDarkMode(cmdPalGui.Hwnd, isDark)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", cmdPalGui.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)

    ; ── ÇERÇEVE ──
    cmdPalGui.Add("Text", "x0 y0 w" w " h1 Background" _cpColors["border"])
    cmdPalGui.Add("Text", "x0 y" (h-1) " w" w " h1 Background" _cpColors["border"])
    cmdPalGui.Add("Text", "x0 y0 w1 h" h " Background" _cpColors["border"])
    cmdPalGui.Add("Text", "x" (w-1) " y0 w1 h" h " Background" _cpColors["border"])

    ; ── ARAMA BÖLÜMÜ ──
    ; İkon + placeholder arka plan
    cmdPalGui.SetFont("s14 bold c" _cpColors["accent"], "Segoe UI Variable Display")
    cmdPalGui.Add("Text", "x16 y13 w28 h28 Center 0x200", "⚡")

    cmdPalGui.SetFont("s12 c" _cpColors["text"], "Segoe UI")
    editSearch := cmdPalGui.Add("Edit",
        "x48 y12 w520 h30 -E0x200 Background" _cpColors["search"] " c" _cpColors["text"], "")
    try {
        ; WS_EX_CLIENTEDGE kaldır → kenarlıksız Edit
        exStyle := DllCall("user32\GetWindowLong", "Ptr", editSearch.Hwnd, "Int", -20, "Int")
        DllCall("user32\SetWindowLong", "Ptr", editSearch.Hwnd, "Int", -20, "Int", exStyle & ~0x200)
        DllCall("user32\SetWindowPos", "Ptr", editSearch.Hwnd, "Ptr", 0,
            "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x27)
    }

    ; ESC rozeti
    cmdPalGui.SetFont("s7.5 bold c" _cpColors["pillText"], "Segoe UI")
    cmdPalGui.Add("Text",
        "x571 y17 w38 h20 Center 0x200 Background" _cpColors["pill"], "ESC")

    ; Arama altı ayırıcı
    cmdPalGui.Add("Text", "x0 y" (CP_FIRST_Y - 2) " w" w " h1 Background" _cpColors["divider"])

    ; ── ÖZEL SATIR ALANI ──
    cmdPalRows := []
    loop CP_VISIBLE {
        yy := CP_FIRST_Y + (A_Index - 1) * CP_ROW_H

        ; Satır arka planı (tam genişlik, tıklanabilir)
        bgCtrl := cmdPalGui.Add("Text",
            "x" CP_ROW_X " y" yy " w" CP_ROW_W " h" (CP_ROW_H - 1)
            " Background" _cpColors["rowNorm"] " 0x200", "")

        ; Başlık metni
        cmdPalGui.SetFont("s9.5 c" _cpColors["text"], "Segoe UI")
        titleCtrl := cmdPalGui.Add("Text",
            "x14 y" (yy + 9) " w370 h20 BackgroundTrans", "")

        ; Kategori pill etiket
        cmdPalGui.SetFont("s7.5 c" _cpColors["catClr"], "Segoe UI")
        catCtrl := cmdPalGui.Add("Text",
            "x400 y" (yy + 11) " w210 h18 Right BackgroundTrans", "")

        ; Satır alt çizgisi
        cmdPalGui.Add("Text",
            "x14 y" (yy + CP_ROW_H - 1) " w" (CP_ROW_W - 14) " h1 Background" _cpColors["divider"])

        rowIdx := A_Index
        bgCtrl.OnEvent("Click", MakeRowClick(rowIdx))
        titleCtrl.OnEvent("Click", MakeRowClick(rowIdx))
        catCtrl.OnEvent("Click", MakeRowClick(rowIdx))

        cmdPalRows.Push({ bg: bgCtrl, title: titleCtrl, cat: catCtrl })
    }

    MakeRowClick(idx) {
        return (*) => OnRowClick(idx)
    }

    OnRowClick(idx) {
        global cmdPalSelIdx, cmdPalScrollOfs
        newSel := cmdPalScrollOfs + idx
        if (newSel < 1 || newSel > cmdPalItems.Length)
            return
        if (cmdPalSelIdx = newSel)
            ExecuteSelected()
        else {
            cmdPalSelIdx := newSel
            RedrawRows()
        }
    }

    ; ── FOOTER ──
    footerY := CP_FIRST_Y + CP_VISIBLE * CP_ROW_H + 2
    cmdPalGui.Add("Text", "x0 y" footerY " w" w " h1 Background" _cpColors["divider"])
    cmdPalGui.SetFont("s8 c" _cpColors["subtext"], "Segoe UI")
    cmdPalGui.Add("Text", "x14 y" (footerY + 8) " w320 h20",
        "↑ ↓ Seçim   •   Enter Çalıştır   •   Esc Kapat")
    cmdPalGui.SetFont("s8 bold c" _cpColors["accent"], "Segoe UI")
    cmdPalGui.Add("Text", "x400 y" (footerY + 8) " w205 h20 Right", "⚡ Copilot Spotlight")

    ; ── SCROLL DEĞİŞKENİ ──
    cmdPalScrollOfs := 0

    ; ── MATEMATİK DEĞERLENDİRİCİ ──
    EvalMathExpr(rawExpr) {
        expr := Trim(rawExpr)
        expr := RegExReplace(expr, "\s+", "")
        expr := StrReplace(expr, ",", ".")
        if (!RegExMatch(expr, "^[\d\.\+\-\*\/\(\)\%]+$"))
            return ""
        if (!RegExMatch(expr, "[\+\-\*\/\%]"))
            return ""
        try {
            html := ComObject("htmlfile")
            html.write("<meta http-equiv='x-ua-compatible' content='IE=edge'>")
            res := html.parentWindow.eval(expr)
            if (res != "" && IsNumber(res))
                return Round(res, 4)
        }
        return ""
    }

    ; ── VERİTABANI ──
    allCommands := [
        { title: "🔒  Ekranı Kilitle",                  cat: "Sistem",        val: "lock",       type: "system", keys: "kilitle lock oturum" },
        { title: "🌙  Uyku Moduna Al",                   cat: "Sistem",        val: "sleep",      type: "system", keys: "uyut sleep askıya" },
        { title: "🔄  Yeniden Başlat",                   cat: "Sistem",        val: "restart",    type: "system", keys: "yeniden başlat restart reboot" },
        { title: "🛑  Bilgisayarı Kapat",                cat: "Sistem",        val: "shutdown",   type: "system", keys: "kapat shutdown turnoff" },
        { title: "🗑️  Geri Dönüşüm Kutusunu Boşalt",    cat: "Sistem",        val: "emptybin",   type: "system", keys: "çöp çöpü boşalt empty recycle bin" },
        { title: "🌐  Yerel IP Adresini Kopyala",        cat: "Ağ & Araç",     val: "ip",         type: "system", keys: "ip network adres" },
        { title: "⚙️  Copilot Button Ayarları",          cat: "Uygulama",      val: "settings",   type: "system", keys: "ayar ayarlar settings config" },
        { title: "💻  Windows Terminal / CMD",           cat: "Geliştirici",   val: "terminal",   type: "run",    keys: "terminal cmd powershell komut satırı" },
        { title: "📝  Not Defteri (Notepad)",            cat: "Araç",          val: "notepad.exe",type: "run",    keys: "not notepad text defter" },
        { title: "🔢  Hesap Makinesi",                   cat: "Araç",          val: "calc.exe",   type: "run",    keys: "hesap makinesi calc calculator" },
        { title: "📊  Görev Yöneticisi",                 cat: "Sistem",        val: "taskmgr.exe",type: "run",    keys: "görev task manager performans" },
        { title: "✂️  Ekran Alıntısı Aracı",            cat: "Araç",          val: "screenshot", type: "system", keys: "ekran alıntısı screenshot ss kırp" },
        { title: "🎙️  Mikrofon Sustur / Aç",            cat: "Copilot",       val: "mic",        type: "action", keys: "mikrofon mic mute sustur ses" },
        { title: "⏯️  Müziği Oynat / Duraklat",         cat: "Medya",         val: "playpause",  type: "action", keys: "oynat duraklat play pause müzik şarkı" },
        { title: "⏭️  Sonraki Şarkı",                   cat: "Medya",         val: "next",       type: "action", keys: "sonraki ileri next track şarkı" },
        { title: "⏮️  Önceki Şarkı",                    cat: "Medya",         val: "prev",       type: "action", keys: "önceki geri prev track" },
        { title: "🎵  Spotify Aç",                       cat: "Uygulama",      val: "spotify:",   type: "run",    keys: "spotify müzik dinle" },
        { title: "💬  Discord Aç",                       cat: "İletişim",      val: "discord:",   type: "run",    keys: "discord sohbet ses" },
        { title: "🎮  Steam Aç",                         cat: "Oyun",          val: "steam:",     type: "run",    keys: "steam oyun kütüphane" },
        { title: "✨  Google Gemini Aç",                 cat: "Yapay Zeka",    val: "gemini",     type: "gemini", keys: "gemini google ai yapay zeka" }
    ]

    ; ── LİSTEYİ YENİLE ──
    RefreshList(*) {
        global cmdPalItems, cmdPalSelIdx, cmdPalScrollOfs
        q      := Trim(editSearch.Value)
        qLower := StrLower(q)
        cmdPalItems    := []
        cmdPalSelIdx   := 1
        cmdPalScrollOfs := 0

        ; Matematik hesabı
        if (q != "") {
            mathRes := EvalMathExpr(q)
            if (mathRes != "")
                cmdPalItems.Push({ title: "🧮  Sonuç: " mathRes, cat: "Kopyala → Enter", val: String(mathRes), type: "copy" })
        }

        ; Prefix aramaları
        if (SubStr(qLower, 1, 2) = "g " && StrLen(q) > 2) {
            qr := SubStr(q, 3)
            cmdPalItems.Push({ title: "🔍  Google: '" qr "'", cat: "Web Araması", val: "https://www.google.com/search?q=" . UriEncode(qr), type: "url" })
            RedrawRows()
            return
        }
        if (SubStr(qLower, 1, 3) = "yt " && StrLen(q) > 3) {
            qr := SubStr(q, 4)
            cmdPalItems.Push({ title: "▶️  YouTube: '" qr "'", cat: "Video Arama", val: "https://www.youtube.com/results?search_query=" . UriEncode(qr), type: "url" })
            RedrawRows()
            return
        }
        if (SubStr(qLower, 1, 3) = "gh " && StrLen(q) > 3) {
            qr := SubStr(q, 4)
            cmdPalItems.Push({ title: "🐙  GitHub: '" qr "'", cat: "Kod / Repo", val: "https://github.com/search?q=" . UriEncode(qr), type: "url" })
            RedrawRows()
            return
        }
        if (SubStr(qLower, 1, 3) = "ai " && StrLen(q) > 3) {
            qr := SubStr(q, 4)
            cmdPalItems.Push({ title: "🤖  ChatGPT: '" qr "'", cat: "Yapay Zeka", val: "https://chatgpt.com/?q=" . UriEncode(qr), type: "url" })
            localAppData := EnvGet("LOCALAPPDATA")
            geminiExe := (localAppData != "") ? localAppData "\Google\Gemini\Gemini.exe" : ""
            if (geminiExe != "" && FileExist(geminiExe)) {
                cmdPalItems.Push({ title: "✨  Gemini Uygulaması", cat: "Yapay Zeka", val: "gemini", type: "gemini" })
            }
            cmdPalItems.Push({ title: "✨  Gemini: '" qr "'",   cat: "Yapay Zeka", val: "https://gemini.google.com",               type: "url" })
            RedrawRows()
            return
        }

        ; Komutları filtrele
        for cmd in allCommands {
            if (qLower = "" || InStr(StrLower(cmd.title), qLower) || InStr(cmd.keys, qLower))
                cmdPalItems.Push(cmd)
        }

        ; Metin yazıldıysa web önerileri ekle
        if (q != "") {
            cmdPalItems.Push({ title: "🔍  Google: '" q "'",    cat: "Web Araması", val: "https://www.google.com/search?q=" . UriEncode(q), type: "url" })
            cmdPalItems.Push({ title: "🤖  ChatGPT: '" q "'",   cat: "Yapay Zeka",  val: "https://chatgpt.com/?q=" . UriEncode(q),          type: "url" })
            cmdPalItems.Push({ title: "▶️  YouTube: '" q "'",   cat: "Video Arama", val: "https://www.youtube.com/results?search_query=" . UriEncode(q), type: "url" })
        }

        RedrawRows()
    }

    ; ── SATIRLARI YENİDEN ÇİZ ──
    RedrawRows() {
        global cmdPalItems, cmdPalSelIdx, cmdPalScrollOfs, cmdPalRows, _cpColors
        global CP_VISIBLE

        total := cmdPalItems.Length

        ; Scroll ofsetini seçim çerçevesinde tut
        if (cmdPalSelIdx < cmdPalScrollOfs + 1)
            cmdPalScrollOfs := cmdPalSelIdx - 1
        if (cmdPalSelIdx > cmdPalScrollOfs + CP_VISIBLE)
            cmdPalScrollOfs := cmdPalSelIdx - CP_VISIBLE
        if (cmdPalScrollOfs < 0)
            cmdPalScrollOfs := 0

        loop CP_VISIBLE {
            rowCtrl := cmdPalRows[A_Index]
            itemIdx := cmdPalScrollOfs + A_Index

            if (itemIdx > total) {
                rowCtrl.bg.Opt("Background" _cpColors["rowNorm"])
                rowCtrl.title.Text := ""
                rowCtrl.cat.Text   := ""
            } else {
                item   := cmdPalItems[itemIdx]
                isSel  := (itemIdx = cmdPalSelIdx)

                ; Seçili satır için arka plan değiştir
                rowCtrl.bg.Opt("Background" (isSel ? _cpColors["rowSel"] : _cpColors["rowNorm"]))
                rowCtrl.bg.Redraw()

                ; Başlık rengi: seçiliyse açık beyaz, değilse normal
                rowCtrl.title.Opt("c" (isSel ? _cpColors["text"] : _cpColors["text"]))
                rowCtrl.title.Text := item.title

                ; Seçiliyse kategori rengi biraz daha parlak
                rowCtrl.cat.Opt("c" (isSel ? _cpColors["accent"] : _cpColors["catClr"]))
                rowCtrl.cat.Text := item.cat
            }
        }
    }

    ; ── SEÇİLİYİ ÇALIŞTIR ──
    ExecuteSelected(*) {
        global cmdPalItems, cmdPalSelIdx
        if (cmdPalSelIdx < 1 || cmdPalSelIdx > cmdPalItems.Length)
            return
        item := cmdPalItems[cmdPalSelIdx]
        CloseCommandPalette()

        switch item.type {
            case "copy":
                A_Clipboard := item.val
                ShowTip("📋 Panoya kopyalandı: " item.val, 2000)
            case "gemini":
                LaunchGeminiApp()
            case "url":
                try {
                    Run item.val
                } catch as err {
                    ShowTip("⚠️ Açılamadı: " err.Message)
                }
            case "run":
                if (item.val = "terminal") {
                    try {
                        Run "wt.exe"
                    } catch {
                        try Run "cmd.exe"
                    }
                } else {
                    try {
                        Run item.val
                    } catch as err {
                        ShowTip("⚠️ Çalıştırılamadı: " err.Message)
                    }
                }
            case "action":
                switch item.val {
                    case "mic":       ToggleMicrophoneMute()
                    case "playpause": (Send("{Blind}{Media_Play_Pause}"), ShowPlayPauseTrackInfo())
                    case "next":      (Send("{Blind}{Media_Next}"),       ShowNextTrackInfo())
                    case "prev":      (Send("{Blind}{Media_Prev}"),       ShowPrevTrackInfo())
                }
            case "system":
                switch item.val {
                    case "lock":
                        ShowTip("🔒 Kilitleniyor...")
                        Sleep 200
                        DllCall("LockWorkStation")
                    case "sleep":
                        ShowTip("🌙 Uyku...")
                        Sleep 200
                        DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
                    case "restart":
                        if (MsgBox("Yeniden başlatmak istediğinize emin misiniz?", "Yeniden Başlat", "YesNo Icon? 262144") = "Yes")
                            Shutdown 2
                    case "shutdown":
                        if (MsgBox("Bilgisayarı kapatmak istediğinize emin misiniz?", "Kapat", "YesNo Icon? 262144") = "Yes")
                            Shutdown 1
                    case "emptybin":
                        try {
                            FileRecycleEmpty()
                            ShowTip("🗑️ Geri dönüşüm kutusu boşaltıldı!")
                        } catch {
                            ShowTip("🗑️ Zaten boş.")
                        }
                    case "ip":
                        ip := GetLocalIP()
                        if (ip != "") {
                            A_Clipboard := ip
                            ShowTip("🌐 IP: " ip " kopyalandı!", 2500)
                        } else {
                            ShowTip("⚠️ IP bulunamadı.")
                        }
                    case "settings":  ShowSettingsGUI()
                    case "screenshot": Send "#+s"
                }
        }
    }

    ; ── NAVİGASYON ──
    NavPalDown(*) {
        global cmdPalSelIdx, cmdPalItems
        if (cmdPalSelIdx < cmdPalItems.Length) {
            cmdPalSelIdx++
            RedrawRows()
        }
    }

    NavPalUp(*) {
        global cmdPalSelIdx
        if (cmdPalSelIdx > 1) {
            cmdPalSelIdx--
            RedrawRows()
        }
    }

    ; ── OLAYLAR ──
    editSearch.OnEvent("Change", RefreshList)
    cmdPalGui.OnEvent("Escape", (*) => CloseCommandPalette())
    OnMessage(0x0006, CmdPalMsg)

    RefreshList()

    cmdPalGui.Show("x" posX " y" posY " w" w " h" h)
    editSearch.Focus()

    HotIfWinActive("ahk_id " cmdPalGui.Hwnd)
    Hotkey("Down",        NavPalDown, "On")
    Hotkey("Up",          NavPalUp,   "On")
    Hotkey("Enter",       ExecuteSelected, "On")
    Hotkey("NumpadEnter", ExecuteSelected, "On")
    HotIfWinActive()
}

CmdPalMsg(wParam, lParam, msg, hwnd) {
    global cmdPalGui
    if (IsObject(cmdPalGui) && hwnd = cmdPalGui.Hwnd && (wParam & 0xFFFF) = 0)
        SetTimer(CloseCommandPalette, -30)
}

CloseCommandPalette(*) {
    global cmdPalGui
    if (IsObject(cmdPalGui)) {
        try OnMessage(0x0006, CmdPalMsg, 0)
        try {
            HotIfWinActive("ahk_id " cmdPalGui.Hwnd)
            Hotkey("Down",        "Off")
            Hotkey("Up",          "Off")
            Hotkey("Enter",       "Off")
            Hotkey("NumpadEnter", "Off")
            HotIfWinActive()
        }
        cmdPalGui.Destroy()
        cmdPalGui := 0
    }
}

UriEncode(str) {
    static doc := 0
    if (!doc) {
        doc := ComObject("htmlfile")
        doc.write("<meta http-equiv='x-ua-compatible' content='IE=edge'>")
    }
    try return doc.parentWindow.encodeURIComponent(str)
    return str
}

GetLocalIP() {
    try {
        wmi := ComObjGet("winmgmts:\\.\root\cimv2")
        for adapter in wmi.ExecQuery("Select IPAddress from Win32_NetworkAdapterConfiguration where IPEnabled = True") {
            if (adapter.IPAddress) {
                for addr in adapter.IPAddress {
                    if (InStr(addr, ".") && addr != "127.0.0.1")
                        return addr
                }
            }
        }
    }
    return ""
}

LaunchGeminiApp() {
    if WinExist("ahk_exe Gemini.exe") {
        WinActivate "ahk_exe Gemini.exe"
        ShowTip("✨ Gemini öne getirildi")
        return
    }
    localAppData := EnvGet("LOCALAPPDATA")
    geminiExe := (localAppData != "") ? localAppData "\Google\Gemini\Gemini.exe" : ""
    geminiLauncher := (localAppData != "") ? localAppData "\Google\Gemini\GeminiAppLauncher.exe" : ""
    targetPath := (geminiExe != "" && FileExist(geminiExe)) ? geminiExe
                : (geminiLauncher != "" && FileExist(geminiLauncher)) ? geminiLauncher
                : (FileExist(A_Programs "\Gemini.lnk") ? A_Programs "\Gemini.lnk" : "https://gemini.google.com")
    try {
        Run targetPath
        ShowTip("✨ Gemini açılıyor...")
    } catch as err {
        try Run "https://gemini.google.com"
        catch
            ShowTip("⚠️ Gemini açılamadı: " err.Message, 2500)
    }
}
