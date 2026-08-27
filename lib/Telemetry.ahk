; ══════════════════════════════════════════
;  TELEMETRİ & LOG SİSTEMİ
; ══════════════════════════════════════════

GenerateUUID() {
    try {
        tl := ComObject("Scriptlet.TypeLib")
        guid := tl.Guid
        guid := RegExReplace(guid, "[\{\}\r\n\s]", "")
        if (StrLen(guid) == 36)
            return StrLower(guid)
    }
    try {
        mGuid := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography", "MachineGuid")
        if (mGuid != "")
            return StrLower(mGuid)
    }
    ; Rastgele UUID v4 üretimi (Fallback)
    randGuid := ""
    loop 32 {
        r := Random(0, 15)
        randGuid .= Format("{:x}", r)
    }
    return SubStr(randGuid, 1, 8) "-" SubStr(randGuid, 9, 4) "-4" SubStr(randGuid, 14, 3) "-a" SubStr(randGuid, 18, 3) "-" SubStr(randGuid, 21, 12)
}

GetOrCreateUID() {
    global configFile
    savedUid := IniRead(configFile, "Settings", "UID", "")
    if (savedUid != "")
        return savedUid

    newUid := GenerateUUID()
    try IniWrite(newUid, configFile, "Settings", "UID")
    return newUid
}

GetIsoTimestamp() {
    return FormatTime(A_NowUTC, "yyyy-MM-ddTHH:mm:ss") . ".000Z"
}

SendAppLog() {
    global configFile, APP_VERSION, telemetryEnabled
    try {
        if (!telemetryEnabled)
            return

        uid := GetOrCreateUID()
        timestamp := GetIsoTimestamp()
        jsonPayload := '{"uid":"' . uid . '","timestamp":"' . timestamp . '","event":"app_opened","platform":"windows","app":"copilot-button"}'

        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", "https://keremkk.com.tr/api/logs", true)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetRequestHeader("User-Agent", "CopilotButton-App/" . APP_VERSION)
        whr.Send(jsonPayload)
        whr.WaitForResponse(5)
    } catch {
        ; Sessiz hata yakalama: Ağ veya sunucu hatalarında kullanıcı deneyimi / tuş kancaları kesintiye uğramaz
    }
}
