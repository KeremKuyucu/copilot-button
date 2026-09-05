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

    if (IsObject(pickerGui)) {
        try pickerGui.Show()
        return
    }

    pickerTargetEdit := targetEditCtrl
    pickerParentGui := parentGui
    pickerBtnHwnds := Map()

    isDark := (GetEffectiveTheme() = "Dark")

    if (isDark) {
        bgColor := "0B0F16"
        cardBgColor := "151B26"
        cardBg2 := "192231"
        textColor := "F5F7FA"
        subTextColor := "A6B5C9"
        dimTextColor := "718096"
        accentBlue := "1683E6"
        accentHover := "2495F5"
        editBgColor := "111925"
        borderClr := "263246"
        selectedBg := "17375C"
    } else {
        bgColor := "F4F7FB"
        cardBgColor := "FFFFFF"
        cardBg2 := "F8FAFD"
        textColor := "162033"
        subTextColor := "52647C"
        dimTextColor := "718096"
        accentBlue := "0878D1"
        accentHover := "1689E0"
        editBgColor := "FFFFFF"
        borderClr := "D8E0EA"
        selectedBg := "DDEEFF"
    }

    editOpt := "Background" editBgColor " c" textColor

    pickerGui := Gui("+AlwaysOnTop -MinimizeBox +Owner" . (parentGui ? parentGui.Hwnd : ""),
        "Akıllı Uygulama Seçici")
    pickerGui.BackColor := bgColor
    pickerGui.SetFont("s9 c" textColor, "Segoe UI")

    SetWindowDarkMode(pickerGui.Hwnd, isDark)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", pickerGui.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)

    RegPickerBtn(ctrl) => (pickerBtnHwnds[ctrl.Hwnd] := true, ctrl)

    ; ── HEADER ──
    pickerGui.SetFont("s12 bold c" textColor, "Segoe UI")
    pickerGui.Add("Text", "x22 y16 w430 h26", "Akıllı Uygulama Seçici")

    pickerGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    pickerGui.Add("Text", "x22 y43 w650 h18",
        "Uygulama, açık pencere veya hazır bir uygulama seçin.")

    pickerGui.Add("Text", "x0 y70 w720 h1 Background" borderClr)

    ; ── TABS ──
    pickerGui.SetFont("s9 bold c" textColor, "Segoe UI")
    tabs := pickerGui.Add("Tab3", "x18 y82 w684 h414",
        ["🪟 Açık Pencereler", "📋 Yüklü Programlar", "🎯 Pencere Seç", "⚡ Önayarlar"])

    ; ══════════════════════════════════════════
    ; SEKME 1: AÇIK PENCERELER
    ; ══════════════════════════════════════════
    tabs.UseTab(1)

    pickerGui.SetFont("s9 bold c" textColor, "Segoe UI")
    pickerGui.Add("Text", "x34 y112 w400 h20", "Açık Pencereler")

    pickerGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    pickerGui.Add("Text", "x34 y134 w620 h18",
        "Şu anda açık olan uygulamalardan birini seçin.")

    pickerGui.SetFont("s9 c" textColor, "Segoe UI")
    edtSearchOpen := pickerGui.Add("Edit", "x34 y160 w500 h28 " editOpt)

    pickerGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnRefreshOpen := RegPickerBtn(pickerGui.Add("Text",
        "x544 y160 w136 h28 Background" accentBlue " cFFFFFF Center 0x200", "↻  Yenile"))

    pickerGui.SetFont("s8.5 c" textColor, "Segoe UI")
    lvOpen := pickerGui.Add("ListView", "x34 y198 w646 h250 " editOpt " -Multi -Grid",
        ["Uygulama / Pencere", "İşlem", "Yol"])
    lvOpen.ModifyCol(1, 490)
    lvOpen.ModifyCol(2, 145)
    lvOpen.ModifyCol(3, 0)

    ; ══════════════════════════════════════════
    ; SEKME 2: YÜKLÜ PROGRAMLAR
    ; ══════════════════════════════════════════
    tabs.UseTab(2)

    pickerGui.SetFont("s9 bold c" textColor, "Segoe UI")
    pickerGui.Add("Text", "x34 y112 w400 h20", "Yüklü Programlar")

    pickerGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    pickerGui.Add("Text", "x34 y134 w620 h18",
        "Başlat menüsündeki kısayollardan uygulama seçin.")

    pickerGui.SetFont("s9 c" textColor, "Segoe UI")
    edtSearchInstalled := pickerGui.Add("Edit", "x34 y160 w646 h28 " editOpt)

    lvInstalled := pickerGui.Add("ListView", "x34 y198 w646 h250 " editOpt " -Multi -Grid",
        ["Program", "İşlem / Hedef", "Yol"])
    lvInstalled.ModifyCol(1, 365)
    lvInstalled.ModifyCol(2, 270)
    lvInstalled.ModifyCol(3, 0)

    ; ══════════════════════════════════════════
    ; SEKME 3: PENCERE SEÇ
    ; ══════════════════════════════════════════
    tabs.UseTab(3)

    pickerGui.SetFont("s12 bold c" textColor, "Segoe UI")
    pickerGui.Add("Text", "x34 y120 w646 h28 Center", "🎯 Ekrandaki bir pencereyi seçin")

    pickerGui.SetFont("s9 c" subTextColor, "Segoe UI")
    pickerGui.Add("Text", "x90 y164 w534 h62 Center",
        "Uygulamanın adına veya dosya yoluna ihtiyacınız yok.`n"
        . "Butona basın ve açmak istediğiniz pencereye tıklayın.`n"
        . "Uygulamanın çalıştırılabilir dosyası otomatik alınır.")

    pickerGui.Add("Text", "x84 y244 w546 h118 Background" cardBgColor)

    pickerGui.SetFont("s9 c" textColor, "Segoe UI")
    pickerGui.Add("Text", "x108 y262 w500 h24 Center", "1   Hedef seçme modunu başlatın")
    pickerGui.Add("Text", "x108 y292 w500 h24 Center", "2   İstediğiniz pencereye SOL TIKLAYIN")
    pickerGui.Add("Text", "x108 y322 w500 h24 Center", "3   Yol otomatik olarak ayarlara aktarılır")

    pickerGui.SetFont("s10 bold cFFFFFF", "Segoe UI")
    btnStartTarget := RegPickerBtn(pickerGui.Add("Text",
        "x190 y382 w334 h42 Background" accentBlue " cFFFFFF Center 0x200",
        "🎯  Pencere Seçmeye Başla"))

    pickerGui.SetFont("s8.5 c" dimTextColor, "Segoe UI")
    pickerGui.Add("Text", "x34 y438 w646 h22 Center",
        "ESC ile seçim modundan çıkabilirsiniz.")

    ; ══════════════════════════════════════════
    ; SEKME 4: ÖNAYARLAR
    ; ══════════════════════════════════════════
    tabs.UseTab(4)

    pickerGui.SetFont("s9 bold c" textColor, "Segoe UI")
    pickerGui.Add("Text", "x34 y112 w400 h20", "Popüler Önayarlar")

    pickerGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    pickerGui.Add("Text", "x34 y134 w620 h18",
        "Sık kullanılan uygulama ve servisleri tek tıkla seçin.")

    pickerGui.SetFont("s9 c" textColor, "Segoe UI")
    edtSearchPreset := pickerGui.Add("Edit", "x34 y160 w646 h28 " editOpt)

    lvPresets := pickerGui.Add("ListView", "x34 y198 w646 h250 " editOpt " -Multi -Grid",
        ["Önayar", "Kategori", "Komut / URL"])
    lvPresets.ModifyCol(1, 360)
    lvPresets.ModifyCol(2, 270)
    lvPresets.ModifyCol(3, 0)

    tabs.UseTab()

    ; ── SEÇİLEN ÖĞE / FOOTER ──
    pickerGui.Add("Text", "x18 y506 w684 h1 Background" borderClr)

    pickerGui.SetFont("s8 c" dimTextColor, "Segoe UI")
    pickerGui.Add("Text", "x28 y518 w70 h18", "Seçilen:")

    pickerGui.SetFont("s8.5 c" subTextColor, "Segoe UI")
    lblSelectedPath := pickerGui.Add("Text", "x82 y517 w470 h20", "Henüz seçim yapılmadı.")

    pickerGui.SetFont("s8.5 bold cFFFFFF", "Segoe UI")
    btnBrowseManual := RegPickerBtn(pickerGui.Add("Text",
        "x28 y548 w154 h30 Background" accentBlue " cFFFFFF Center 0x200",
        "📁  Dosyadan Seç"))

    btnCancel := RegPickerBtn(pickerGui.Add("Text",
        "x566 y548 w136 h30 Background" cardBg2 " c" subTextColor " Center 0x200",
        "İptal"))

    ; ── DATA ──
    allRunningWindows := []
    allInstalledApps := []

    presetApps := [
        ; Yapay Zeka
        { name: "ChatGPT", cat: "🤖 Yapay Zeka", path: 'explorer.exe "shell:AppsFolder\OpenAI.Codex_2p2nqsd0c76g0!App"' },
        { name: "Microsoft Copilot", cat: "🤖 Yapay Zeka", path: 'explorer.exe "shell:AppsFolder\Microsoft.Copilot_8wekyb3d8bbwe!App"' },
        { name: "Gemini", cat: "🤖 Yapay Zeka", path: "https://gemini.google.com" },
        { name: "Claude", cat: "🤖 Yapay Zeka", path: "https://claude.ai" },
        { name: "Perplexity", cat: "🤖 Yapay Zeka", path: "https://www.perplexity.ai" },
        { name: "DeepSeek", cat: "🤖 Yapay Zeka", path: "https://chat.deepseek.com" },

        ; İletişim
        { name: "Discord", cat: "💬 İletişim", path: "discord:" },
        { name: "Telegram", cat: "💬 İletişim", path: "telegram:" },
        { name: "WhatsApp", cat: "💬 İletişim", path: "whatsapp:" },
        { name: "Gmail", cat: "💬 İletişim", path: "https://mail.google.com" },

        ; Medya
        { name: "Spotify", cat: "🎵 Medya", path: "spotify:" },
        { name: "YouTube", cat: "🎵 Medya", path: "https://www.youtube.com" },
        { name: "YouTube Music", cat: "🎵 Medya", path: "https://music.youtube.com" },
        { name: "Twitch", cat: "🎵 Medya", path: "https://www.twitch.tv" },
        { name: "Netflix", cat: "🎵 Medya", path: "https://www.netflix.com" },

        ; Geliştirme
        { name: "GitHub", cat: "🧑‍💻 Geliştirme", path: "https://github.com" },
        { name: "Stack Overflow", cat: "🧑‍💻 Geliştirme", path: "https://stackoverflow.com" },
        { name: "NPM", cat: "🧑‍💻 Geliştirme", path: "https://www.npmjs.com" },
        { name: "Vercel", cat: "🧑‍💻 Geliştirme", path: "https://vercel.com" },
        { name: "Supabase", cat: "🧑‍💻 Geliştirme", path: "https://supabase.com" },

        ; Oyun
        { name: "Steam", cat: "🎮 Oyun", path: "steam:" },
        { name: "Epic Games", cat: "🎮 Oyun", path: "com.epicgames.launcher://" },

        ; Günlük
        { name: "Google", cat: "🔗 Günlük", path: "https://www.google.com" },
        { name: "Google Drive", cat: "🔗 Günlük", path: "https://drive.google.com" },
        { name: "Google Maps", cat: "🔗 Günlük", path: "https://maps.google.com" },
        { name: "Google Translate", cat: "🔗 Günlük", path: "https://translate.google.com" },
        { name: "Reddit", cat: "🔗 Günlük", path: "https://www.reddit.com" }
    ]

    ; ── AÇIK PENCERELER ──
    RefreshOpenWindows(*) {
        allRunningWindows := []
        seen := Map()

        for hwnd in WinGetList() {
            title := WinGetTitle(hwnd)
            if (title = "")
                continue

            style := WinGetStyle(hwnd)
            if !(style & 0x10000000)
                continue

            exStyle := WinGetExStyle(hwnd)
            if (exStyle & 0x00000080)
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
            if (query = "" || InStr(StrLower(item.title), query) || InStr(StrLower(item.name), query))
                lvOpen.Add(, item.title, item.name, item.path)
        }
    }

    ; ── YÜKLÜ PROGRAMLAR ──
    ScanInstalledApps() {
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
                try FileGetShortcut(shortcutPath, &targetPath)

                finalPath := (targetPath != "" && FileExist(targetPath)) ? targetPath : shortcutPath
                exeName := RegExReplace(finalPath, "^.*\\", "")

                if (seen.Has(StrLower(baseName)))
                    continue

                seen[StrLower(baseName)] := true
                allInstalledApps.Push({ name: baseName, exe: exeName, path: finalPath })
            }
        }

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
            if (query = "" || InStr(StrLower(item.name), query) || InStr(StrLower(item.exe), query))
                lvInstalled.Add(, item.name, item.exe, item.path)
        }
    }

    ; ── ÖNAYARLAR ──
    FilterPresets(*) {
        query := StrLower(Trim(edtSearchPreset.Value))
        lvPresets.Delete()

        for item in presetApps {
            if (query = "" || InStr(StrLower(item.name), query) || InStr(StrLower(item.cat), query))
                lvPresets.Add(, item.name, item.cat, item.path)
        }
    }

    ; ── SEÇİM ──
    SelectAndClose(selectedPath, displayName := "") {
        if (selectedPath = "")
            return

        if (pickerTargetEdit && IsObject(pickerTargetEdit))
            pickerTargetEdit.Value := selectedPath

        if (displayName = "")
            displayName := RegExReplace(selectedPath, "^.*\\", "")

        if (displayName = "")
            displayName := selectedPath

        ShowTip("✓ Uygulama seçildi: " displayName, 2200)
        CloseAppPicker()
    }

    ShowSelectedPath(path, name := "") {
        if (name = "")
            name := RegExReplace(path, "^.*\\", "")

        if (name = "")
            name := path

        lblSelectedPath.Text := name
        try lblSelectedPath.Opt("c" textColor)
        try lblSelectedPath.Redraw()
    }

    ChooseFromListView(lv, pathCol := 3) {
        rowNumber := lv.GetNext(0)

        if (rowNumber = 0) {
            MsgBox("Lütfen listeden bir uygulama seçin.", "Uygulama Seçici", "Icon! 262144")
            return
        }

        pathVal := lv.GetText(rowNumber, pathCol)
        if (pathVal = "")
            return

        name := lv.GetText(rowNumber, 1)
        ShowSelectedPath(pathVal, name)
        SelectAndClose(pathVal, name)
    }

    ; ── HEDEF SEÇİCİ ──
    StartTargetPicker(*) {
        pickerGui.Hide()

        if (pickerParentGui && IsObject(pickerParentGui))
            pickerParentGui.Hide()

        ToolTip("🎯 Seçmek istediğiniz pencereye SOL TIKLAYIN...`nESC ile vazgeçebilirsiniz.", 20, 20)

        KeyWait "LButton", "U"

        loop {
            Sleep 25

            if GetKeyState("Escape", "P") {
                ToolTip()

                if (pickerParentGui && IsObject(pickerParentGui))
                    pickerParentGui.Show()

                pickerGui.Show()
                return
            }

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

                            SelectAndClose(pPath, pName)
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

    ; ── DOSYADAN SEÇ ──
    BrowseManualFile(*) {
        selectedFile := FileSelect(3, , "Çalıştırılacak Uygulama veya Dosyayı Seçin",
            "Programlar (*.exe; *.bat; *.cmd; *.lnk; *.vbs; *.ps1; *.*)")

        if (selectedFile != "")
            SelectAndClose(selectedFile)
    }

    ; ── ONAY / ENTER ──
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

    ; ── EVENTS ──
    edtSearchOpen.OnEvent("Change", FilterOpenWindows)
    btnRefreshOpen.OnEvent("Click", RefreshOpenWindows)
    lvOpen.OnEvent("DoubleClick", (*) => ChooseFromListView(lvOpen, 3))

    edtSearchInstalled.OnEvent("Change", FilterInstalledApps)
    lvInstalled.OnEvent("DoubleClick", (*) => ChooseFromListView(lvInstalled, 3))

    btnStartTarget.OnEvent("Click", StartTargetPicker)

    edtSearchPreset.OnEvent("Change", FilterPresets)
    lvPresets.OnEvent("DoubleClick", (*) => ChooseFromListView(lvPresets, 3))

    btnBrowseManual.OnEvent("Click", BrowseManualFile)
    btnCancel.OnEvent("Click", (*) => CloseAppPicker())

    OnMessage(0x0200, PickerMouseMove)

    pickerGui.OnEvent("Close", (*) => CloseAppPicker())
    pickerGui.OnEvent("Escape", (*) => CloseAppPicker())

    RefreshOpenWindows()
    ScanInstalledApps()
    FilterPresets()

    ApplyThemeToControls(pickerGui, isDark)

    pickerGui.Show("w720 h590")
}

; ══════════════════════════════════════════
;  FARE İMLECİ
; ══════════════════════════════════════════

PickerMouseMove(wParam, lParam, msg, hwnd) {
    global pickerBtnHwnds

    if (pickerBtnHwnds.Has(hwnd)) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))
    }
}

; ══════════════════════════════════════════
;  PENCEREYİ KAPAT
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
