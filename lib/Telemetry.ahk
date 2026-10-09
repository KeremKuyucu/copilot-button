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
    static logSent := false
    static retryCount := 0
    static sessionTimestamp := ""

    ; Telemetri kapalıysa veya bu oturumda log zaten başarıyla gönderildiyse zamanlayıcıyı durdur ve çık
    if (!telemetryEnabled || logSent) {
        SetTimer(SendAppLog, 0)
        return
    }

    ; İlk açılış zamanını koru (gecikmeli gönderildiğinde de doğru oturum başlangıcı iletilsin)
    if (sessionTimestamp == "")
        sessionTimestamp := GetIsoTimestamp()

    success := false
    try {
        uid := GetOrCreateUID()
        jsonPayload := '{"uid":"' . uid . '","timestamp":"' . sessionTimestamp . '","event":"app_opened","platform":"windows","app":"copilot-button"}'

        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        ; Zaman aşımları: DNS çözme (3s), bağlantı (3s), gönderme (5s), alma (5s)
        whr.SetTimeouts(3000, 3000, 5000, 5000)
        ; TLS 1.2 & TLS 1.3 desteği
        try whr.Option[9] := 0x2800

        whr.Open("POST", "https://keremkk.com.tr/api/logs", true)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetRequestHeader("User-Agent", "CopilotButton-App/" . APP_VERSION)
        whr.Send(jsonPayload)

        if (whr.WaitForResponse(5)) {
            status := whr.Status
            if (status >= 200 && status < 300)
                success := true
        } else {
            try whr.Abort()
        }
    } catch {
        success := false
    }

    if (success) {
        logSent := true
        SetTimer(SendAppLog, 0)
        return
    }

    ; Gönderim başarısız olduysa (internet yoksa veya sunucu hatası), belirli aralıklarla yeniden dene
    retryCount++
    ; İlk denemeler hızlı (15 sn, 30 sn), sonrasında 60 sn ve en fazla 2 dk aralıkla periyodik olarak dene
    nextDelay := (retryCount <= 2) ? 15000 : (retryCount <= 5 ? 30000 : (retryCount <= 10 ? 60000 : 120000))
    SetTimer(SendAppLog, -nextDelay)
}

