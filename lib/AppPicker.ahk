; ══════════════════════════════════════════
;  AKILLI UYGULAMA SEÇİCİ (SMART APP PICKER) MODÜLÜ
; ══════════════════════════════════════════

global pickerGui := 0
global pickerTargetEdit := 0
global pickerParentGui := 0
global pickerBtnHwnds := Map()

; ══════════════════════════════════════════
;  PENCEREYİ AÇ
; ══════════════════════════════════════════
OpenAppPicker(targetEditCtrl, parentGui := 0) {
    global pickerGui, pickerTargetEdit, pickerParentGui, pickerBtnHwnds

    ; Eğer zaten açıksa öne getir
    if (IsObject(pickerGui)) {
        try pickerGui.Show()
        return
    }

    pickerTargetEdit := targetEditCtrl
    pickerParentGui := parentGui
    pickerBtnHwnds := Map()

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
    }
    editOpt := "Background" editBgColor " c" textColor

    pickerGui := Gui("+AlwaysOnTop -MinimizeBox +Owner" . (parentGui ? parentGui.Hwnd : ""),
        "🚀 Akıllı Uygulama Seçici")
    pickerGui.BackColor := bgColor
    pickerGui.SetFont("s9 c" textColor, "Segoe UI")

    ; DWM Dark Mode & Yuvarlatılmış Köşeler
    SetWindowDarkMode(pickerGui.Hwnd, isDark)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", pickerGui.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)

    RegPickerBtn(ctrl) => (pickerBtnHwnds[ctrl.Hwnd] := true, ctrl)

    ; ── ÜST BAŞLIK ──
    pickerGui.SetFont("s11 bold c" textColor, "Segoe UI")
    pickerGui.Add("Text", "x20 y14 w400 h24", "🚀 Akıllı Uygulama Seçici")

    pickerGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    pickerGui.Add("Text", "x20 y38 w580 h18",
        "Çalıştırmak istediğiniz uygulamayı arayın, açık pencerelerden veya doğrudan ekrandan seçin.")

    ; Ayırıcı Çizgi
    pickerGui.Add("Text", "x0 y62 w650 h1 Background" borderClr)

    ; ── SEKMELER (TAB3) ──
    pickerGui.SetFont("s9 bold c" textColor, "Segoe UI")
    tabs := pickerGui.Add("Tab3", "x16 y72 w614 h410",
        ["🪟 Açık Pencereler", "📋 Yüklü Programlar", "🎯 Pencereye Tıkla", "⚡ Popüler Önayarlar"])

    ; ══════════════════════════════════════════
    ;  SEKME 1: 🪟 AÇIK PENCERELER
    ; ══════════════════════════════════════════
    tabs.UseTab(1)
    pickerGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    pickerGui.Add("Text", "x30 y106 w450 h18",
        "Şu an açık olan pencerelerden seçin (çift tıklayarak anında onaylayabilirsiniz):")

    pickerGui.SetFont("s9 c" textColor, "Segoe UI")
    edtSearchOpen := pickerGui.Add("Edit", "x30 y128 w460 h26 " editOpt)
    
    pickerGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnRefreshOpen := RegPickerBtn(pickerGui.Add("Text",
        "x498 y128 w118 h26 Background" darkBlueBtn " cFFFFFF Center 0x200", "🔄 Pencereleri Yenile"))

    pickerGui.SetFont("s8.5 c" textColor, "Segoe UI")
    lvOpen := pickerGui.Add("ListView", "x30 y162 w586 h306 " editOpt " -Multi +Grid",
        ["Uygulama / Başlık", "İşlem (.exe)", "Dosya Yolu"])
    lvOpen.ModifyCol(1, 250)
    lvOpen.ModifyCol(2, 115)
    lvOpen.ModifyCol(3, 200)

    ; ══════════════════════════════════════════
    ;  SEKME 2: 📋 YÜKLÜ PROGRAMLAR (BAŞLAT MENÜSÜ)
    ; ══════════════════════════════════════════
    tabs.UseTab(2)
    pickerGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    pickerGui.Add("Text", "x30 y106 w580 h18",
        "Başlat menüsü kısayolları taranmıştır. Uygulama adıyla arayın ve çift tıklayın:")

    pickerGui.SetFont("s9 c" textColor, "Segoe UI")
    edtSearchInstalled := pickerGui.Add("Edit", "x30 y128 w586 h26 " editOpt)

    pickerGui.SetFont("s8.5 c" textColor, "Segoe UI")
    lvInstalled := pickerGui.Add("ListView", "x30 y162 w586 h306 " editOpt " -Multi +Grid",
        ["Program Adı", "İşlem / Hedef", "Dosya / Kısayol Konumu"])
    lvInstalled.ModifyCol(1, 230)
    lvInstalled.ModifyCol(2, 130)
    lvInstalled.ModifyCol(3, 205)

    ; ══════════════════════════════════════════
    ;  SEKME 3: 🎯 PENCEREYE TIKLA (HEDEF SEÇİCİ)
    ; ══════════════════════════════════════════
    tabs.UseTab(3)
    pickerGui.SetFont("s9 c" textColor, "Segoe UI")
    pickerGui.Add("GroupBox", "x30 y106 w586 h362", "🎯 Ekrandaki Pencereye Tıklayarak Otomatik Yakala")

    pickerGui.SetFont("s9 c" textColor, "Segoe UI")
    pickerGui.Add("Text", "x50 y138 w546 h90",
        "Dosya konumunu veya program adını aramak istemiyorsanız en kolay yol budur!`n`n"
        . "1. Aşağıdaki '🎯 Hedef Seçmeye Başla' butonuna basın.`n"
        . "2. Pencereler geçici olarak gizlenecek ve fare imleciniz hedef moduna geçecektir.`n"
        . "3. Seçmek istediğiniz uygulamanın penceresine SOL TIKLAYIN.`n"
        . "4. Uygulamanın .exe yolu otomatik tespit edilip ayarlarınıza aktarılacaktır!")

    pickerGui.SetFont("s10 bold cFFFFFF", "Segoe UI")
    btnStartTarget := RegPickerBtn(pickerGui.Add("Text",
        "x173 y250 w300 h44 Background" accentBlue " cFFFFFF Center 0x200", "🎯 Hedef Seçmeye Başla"))

    pickerGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    pickerGui.Add("Text", "x50 y310 w546 h40 Center",
        "💡 İpucu: Hedef seçme modundan vazgeçmek isterseniz klavyenizden ESC tuşuna basabilirsiniz.")

    ; ══════════════════════════════════════════
    ;  SEKME 4: ⚡ POPÜLER ÖNAYARLAR
    ; ══════════════════════════════════════════
    tabs.UseTab(4)
    pickerGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    pickerGui.Add("Text", "x30 y106 w580 h18",
        "Sık kullanılan uygulamaları ve yapay zeka web servislerini tek tıkla tanımlayın:")

    pickerGui.SetFont("s9 c" textColor, "Segoe UI")
    edtSearchPreset := pickerGui.Add("Edit", "x30 y128 w586 h26 " editOpt)

    pickerGui.SetFont("s8.5 c" textColor, "Segoe UI")
    lvPresets := pickerGui.Add("ListView", "x30 y162 w586 h306 " editOpt " -Multi +Grid",
        ["Önayar Adı", "Kategori", "Komut / URL"])
    lvPresets.ModifyCol(1, 200)
    lvPresets.ModifyCol(2, 140)
    lvPresets.ModifyCol(3, 225)

    tabs.UseTab() ; Sekme dışına çık

    ; ══════════════════════════════════════════
    ;  ALT KONTROL BUTONLARI (FOOTER)
    ; ══════════════════════════════════════════
    pickerGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnBrowseManual := RegPickerBtn(pickerGui.Add("Text",
        "x16 y494 w150 h30 Background" darkBlueBtn " cFFFFFF Center 0x200", "📁 Dosyaya Gözat..."))

    btnConfirm := RegPickerBtn(pickerGui.Add("Text",
        "x452 y494 w86 h30 Background" accentBlue " cFFFFFF Center 0x200", "✅ Seç"))

    btnCancel := RegPickerBtn(pickerGui.Add("Text",
        "x544 y494 w86 h30 Background" darkBlueBtn " cFFFFFF Center 0x200", "❌ İptal"))

    ; ══════════════════════════════════════════
    ;  VERİ LİSTELERİ & TARAMA İŞLEMLERİ
    ; ══════════════════════════════════════════
    allRunningWindows := []
    allInstalledApps := []

    presetApps := [
        ; Yapay Zeka & Web
        { name: "ChatGPT (Web)", cat: "🌐 Yapay Zeka & Web", path: "https://chatgpt.com" },
        { name: "Claude AI (Web)", cat: "🌐 Yapay Zeka & Web", path: "https://claude.ai" },
        { name: "Google Gemini (Web)", cat: "🌐 Yapay Zeka & Web", path: "https://gemini.google.com" },
        { name: "YouTube (Web)", cat: "🌐 Yapay Zeka & Web", path: "https://www.youtube.com" },
        { name: "GitHub (Web)", cat: "🌐 Yapay Zeka & Web", path: "https://github.com" },

        ; İletişim & Medya
        { name: "Discord", cat: "💬 İletişim", path: "discord:" },
        { name: "Telegram Desktop", cat: "💬 İletişim", path: "telegram:" },
        { name: "WhatsApp", cat: "💬 İletişim", path: "whatsapp:" },
        { name: "Spotify", cat: "🎵 Medya", path: "spotify:" },

        ; Windows Araçları & Verimlilik
        { name: "Not Defteri (Notepad)", cat: "🛠️ Araçlar", path: "notepad.exe" },
        { name: "Hesap Makinesi (Calc)", cat: "🛠️ Araçlar", path: "calc.exe" },
        { name: "Windows Terminal", cat: "🛠️ Araçlar", path: "wt.exe" },
        { name: "Komut İstemi (CMD)", cat: "🛠️ Araçlar", path: "cmd.exe" },
        { name: "PowerShell", cat: "🛠️ Araçlar", path: "powershell.exe" },
        { name: "Görev Yöneticisi", cat: "🛠️ Araçlar", path: "taskmgr.exe" },
        { name: "Ekran Alıntısı Aracı", cat: "🛠️ Araçlar", path: "snippingtool.exe" },
        { name: "Dosya Gezgini", cat: "🛠️ Araçlar", path: "explorer.exe" },
        { name: "Windows Ayarları", cat: "🛠️ Araçlar", path: "ms-settings:" }
    ]

    ; ── AÇIK PENCERELERİ TARA ──
    RefreshOpenWindows(*) {
        nonlocal allRunningWindows
        allRunningWindows := []
        seen := Map()

        for hwnd in WinGetList() {
            title := WinGetTitle(hwnd)
            if (title = "")
                continue

            style := WinGetStyle(hwnd)
            if !(style & 0x10000000) ; WS_VISIBLE
                continue
            exStyle := WinGetExStyle(hwnd)
            if (exStyle & 0x00000080) ; WS_EX_TOOLWINDOW
                continue

            try {
                pPath := WinGetProcessPath(hwnd)
                pName := WinGetProcessName(hwnd)
            } catch {
                continue
            }

            if (pPath = "" || pName = "")
                continue

            pLower := StrLower(pName)
            if (pLower = "autohotkey64.exe" || pLower = "autohotkey32.exe" || pLower = "copilotbutton.exe"
                || pLower = "shellexperiencehost.exe" || pLower = "startmenuexperiencehost.exe"
                || pLower = "searchhost.exe" || pLower = "textinputhost.exe"
                || (pLower = "applicationframehost.exe" && (title = "Windows Input Experience" || title = ""))
                || (pLower = "explorer.exe" && (title = "Program Manager" || title = "")))
                continue

            if (seen.Has(pPath))
                continue
            seen[pPath] := true

            allRunningWindows.Push({ title: title, name: pName, path: pPath })
        }
        FilterOpenWindows()
    }

    FilterOpenWindows(*) {
        query := StrLower(Trim(edtSearchOpen.Value))
        lvOpen.Delete()
        for item in allRunningWindows {
            if (query = "" || InStr(StrLower(item.title), query) || InStr(StrLower(item.name), query)) {
                lvOpen.Add(, item.title, item.name, item.path)
            }
        }
    }

    ; ── YÜKLÜ PROGRAMLARI TARA (BAŞLAT MENÜSÜ) ──
    ScanInstalledApps() {
        nonlocal allInstalledApps
        allInstalledApps := []
        seen := Map()

        scanDirs := [A_Programs, A_ProgramsCommon]

        for dir in scanDirs {
            if !DirExist(dir)
                continue

            loop files dir "\*.lnk", "R" {
                shortcutPath := A_LoopFileFullPath
                baseName := RegExReplace(A_LoopFileName, "\.lnk$", "")

                bLower := StrLower(baseName)
                if (InStr(bLower, "uninstall") || InStr(bLower, "kaldır") || InStr(bLower, "remove")
                    || InStr(bLower, "help") || InStr(bLower, "yardım") || InStr(bLower, "documentation")
                    || InStr(bLower, "readme") || InStr(bLower, "beni oku"))
                    continue

                targetPath := ""
                try {
                    FileGetShortcut(shortcutPath, &targetPath)
                } catch {
                    targetPath := ""
                }

                finalPath := (targetPath != "" && FileExist(targetPath)) ? targetPath : shortcutPath
                exeName := RegExReplace(finalPath, "^.*\\", "")

                if (seen.Has(StrLower(baseName)))
                    continue
                seen[StrLower(baseName)] := true

                allInstalledApps.Push({ name: baseName, exe: exeName, path: finalPath })
            }
        }

        ; İsme göre basit alfabetik sıralama
        n := allInstalledApps.Length
        if (n > 1) {
            loop n - 1 {
                i := A_Index
                loop n - i {
                    j := A_Index
                    if (StrCompare(allInstalledApps[j].name, allInstalledApps[j+1].name, true) > 0) {
                        temp := allInstalledApps[j]
                        allInstalledApps[j] := allInstalledApps[j+1]
                        allInstalledApps[j+1] := temp
                    }
                }
            }
        }
        FilterInstalledApps()
    }

    FilterInstalledApps(*) {
        query := StrLower(Trim(edtSearchInstalled.Value))
        lvInstalled.Delete()
        for item in allInstalledApps {
            if (query = "" || InStr(StrLower(item.name), query) || InStr(StrLower(item.exe), query)) {
                lvInstalled.Add(, item.name, item.exe, item.path)
            }
        }
    }

    ; ── POPÜLER ÖNAYARLARI FİLTRELE ──
    FilterPresets(*) {
        query := StrLower(Trim(edtSearchPreset.Value))
        lvPresets.Delete()
        for item in presetApps {
            if (query = "" || InStr(StrLower(item.name), query) || InStr(StrLower(item.cat), query)
                || InStr(StrLower(item.path), query)) {
                lvPresets.Add(, item.name, item.cat, item.path)
            }
        }
    }

    ; ── SEÇİMİ ONAYLA VE PENCEREYİ KAPAT ──
    SelectAndClose(selectedPath) {
        if (pickerTargetEdit && IsObject(pickerTargetEdit)) {
            pickerTargetEdit.Value := selectedPath
        }
        displayName := RegExReplace(selectedPath, "^.*\\", "")
        if (displayName = "")
            displayName := selectedPath
        ShowTip("✅ Uygulama seçildi: " displayName, 2200)
        CloseAppPicker()
    }

    ChooseFromListView(lv, colIndex) {
        rowNumber := lv.GetNext(0)
        if (rowNumber = 0) {
            MsgBox("Lütfen listeden bir uygulama seçin!", "Uygulama Seçici", "Icon! 262144")
            return
        }
        pathVal := lv.GetText(rowNumber, colIndex)
        if (pathVal != "")
            SelectAndClose(pathVal)
    }

    ; ── 🎯 HEDEF SEÇİCİ (PENCEREYE TIKLAYARAK YAKALAMA) ──
    StartTargetPicker(*) {
        pickerGui.Hide()
        if (pickerParentGui && IsObject(pickerParentGui))
            pickerParentGui.Hide()

        ToolTip("🎯 Seçmek istediğiniz pencerenin üzerine SOL TIKLAYIN...`n(Vazgeçmek için klavyeden ESC tuşuna basın)", 20, 20)

        ; Tıklama butonunun bırakılmasını bekle
        KeyWait "LButton", "U"

        loop {
            Sleep 25
            ; ESC kontrolü (Vazgeçme)
            if GetKeyState("Escape", "P") {
                ToolTip()
                if (pickerParentGui && IsObject(pickerParentGui))
                    pickerParentGui.Show()
                pickerGui.Show()
                return
            }
            ; Sol Tık kontrolü (Pencere seçildi)
            if GetKeyState("LButton", "P") {
                Sleep 60
                MouseGetPos ,, &clickedHwnd
                ToolTip()

                if (clickedHwnd) {
                    try {
                        pName := WinGetProcessName(clickedHwnd)
                        pPath := WinGetProcessPath(clickedHwnd)

                        if (pName != "AutoHotkey64.exe" && pName != "AutoHotkey32.exe"
                            && pName != "CopilotButton.exe" && pPath != "") {
                            if (pickerParentGui && IsObject(pickerParentGui))
                                pickerParentGui.Show()
                            SelectAndClose(pPath)
                            return
                        }
                    }
                }
                if (pickerParentGui && IsObject(pickerParentGui))
                    pickerParentGui.Show()
                pickerGui.Show()
                return
            }
        }
    }

    ; ── MANUEL DOSYA SEÇİCİ (GÖZAT) ──
    BrowseManualFile(*) {
        selectedFile := FileSelect(3, , "Çalıştırılacak Uygulama veya Dosyayı Seçin",
            "Programlar (*.exe; *.bat; *.cmd; *.lnk; *.vbs; *.ps1; *.*)")
        if (selectedFile != "")
            SelectAndClose(selectedFile)
    }

    ; ── ONAYLA BUTONU (AKTİF SEKMEDEKİ SEÇİMİ AL) ──
    OnConfirmClick(*) {
        activeTab := tabs.Value
        switch activeTab {
            case 1:
                ChooseFromListView(lvOpen, 3)
            case 2:
                ChooseFromListView(lvInstalled, 3)
            case 3:
                StartTargetPicker()
            case 4:
                ChooseFromListView(lvPresets, 3)
        }
    }

    ; ── OLAY TANIMLAMALARI ──
    edtSearchOpen.OnEvent("Change", FilterOpenWindows)
    btnRefreshOpen.OnEvent("Click", RefreshOpenWindows)
    lvOpen.OnEvent("DoubleClick", (*) => ChooseFromListView(lvOpen, 3))

    edtSearchInstalled.OnEvent("Change", FilterInstalledApps)
    lvInstalled.OnEvent("DoubleClick", (*) => ChooseFromListView(lvInstalled, 3))

    btnStartTarget.OnEvent("Click", StartTargetPicker)

    edtSearchPreset.OnEvent("Change", FilterPresets)
    lvPresets.OnEvent("DoubleClick", (*) => ChooseFromListView(lvPresets, 3))

    btnBrowseManual.OnEvent("Click", BrowseManualFile)
    btnConfirm.OnEvent("Click", OnConfirmClick)
    btnCancel.OnEvent("Click", (*) => CloseAppPicker())

    ; Mouse Hover Hand Cursor (WM_MOUSEMOVE)
    PickerMouseMove(wParam, lParam, msg, hwnd) {
        if (pickerBtnHwnds.Has(hwnd)) {
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))
        }
    }
    OnMessage(0x0200, PickerMouseMove)

    pickerGui.OnEvent("Close", (*) => CloseAppPicker())
    pickerGui.OnEvent("Escape", (*) => CloseAppPicker())

    ; İlk Verileri Yükle
    RefreshOpenWindows()
    ScanInstalledApps()
    FilterPresets()

    ; Kontrol Temalarını Uygula
    ApplyThemeToControls(pickerGui, isDark)

    ; Göster
    pickerGui.Show("w646 h540")
}

; ══════════════════════════════════════════
;  PENCEREYİ KAPAT & TEMİZLE
; ══════════════════════════════════════════
CloseAppPicker() {
    global pickerGui, pickerBtnHwnds
    if (IsObject(pickerGui)) {
        try OnMessage(0x0200, PickerMouseMove, 0)
        pickerGui.Destroy()
        pickerGui := 0
        pickerBtnHwnds := Map()
    }
}
