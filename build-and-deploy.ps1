#requires -version 5.1
<#
.SYNOPSIS
    Copilot Button - Otomatik Derle (AHK -> EXE), Inno Setup (Setup.exe), Imzala ve GitHub'a Dagit
.DESCRIPTION
    AutoHotkey v2 scriptini (copilot-buton.ahk) Ahk2Exe ile C:\Users\Kerem\Projects\Outputs klasorune derler,
    Inno Setup 6 ile CopilotButton-Setup.exe kurulum paketini olusturur, signtool ile imzalar
    ve GitHub Release olusturarak dosyalari yukler.
.NOTES
    Proje kokunde calistirilmalidir.
#>

param(
    [Parameter(Mandatory = $false)][switch]$NoPrompt,
    [Parameter(Mandatory = $false)][switch]$SkipRelease,
    [Parameter(Mandatory = $false)][switch]$CreateRelease,
    [Parameter(Mandatory = $false)][switch]$InnoSetupOnly,
    [Parameter(Mandatory = $false)][switch]$CompileOnly,
    [Parameter(Mandatory = $false)][string]$ReleaseNotes
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# -- Renk & Log Yardimcilari -------------------------------------------------------
function Write-Step   ([string]$msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-Info   ([string]$msg) { Write-Host "   [i] $msg" -ForegroundColor DarkGray }
function Write-Ok     ([string]$msg) { Write-Host "   [OK] $msg" -ForegroundColor Green }
function Write-Warn   ([string]$msg) { Write-Host "   [!] $msg" -ForegroundColor Yellow }
function Write-Err    ([string]$msg) { Write-Host "   [X] $msg" -ForegroundColor Red }

# -- Islem Suresi Olcumu -----------------------------------------------------------
function Format-Elapsed ([TimeSpan]$ts) {
    if ($ts.TotalMinutes -ge 1) {
        return "{0:N0}dk {1:N0}sn" -f $ts.TotalMinutes, $ts.Seconds
    }
    return "{0:N1}sn" -f $ts.TotalSeconds
}

try {
    $scriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # -- 0) Yapilandirma -----------------------------------------------------------
    $projectRoot = $PSScriptRoot
    Set-Location $projectRoot

    $projectsParent = Split-Path -Parent $projectRoot
    $distPath = if (Test-Path (Join-Path $projectsParent "Outputs")) { Join-Path $projectsParent "Outputs" } else { "C:\Users\Kerem\Projects\Outputs" }
    $ahkScriptName  = "copilot-buton.ahk"
    $ahkScriptPath  = Join-Path $projectRoot $ahkScriptName
    $outputExeName  = "CopilotButton.exe"
    $outputExePath  = Join-Path $distPath $outputExeName
    $setupExeName   = "CopilotButton-Setup.exe"
    $setupExePath   = Join-Path $distPath $setupExeName
    $issScriptPath  = Join-Path $projectRoot "installer.iss"
    $iconPath       = Join-Path $projectRoot "logo.ico"

    # Ahk2Exe Derleyici Yolu Arama
    $ahk2exeCandidates = @(
        "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe",
        "C:\Program Files (x86)\AutoHotkey\Compiler\Ahk2Exe.exe",
        (Join-Path $projectRoot "tools\Ahk2Exe\Ahk2Exe.exe")
    )
    $ahk2exePath = $null
    foreach ($cand in $ahk2exeCandidates) {
        if (Test-Path $cand) { $ahk2exePath = $cand; break }
    }
    if (-not $ahk2exePath) {
        $candCmd = Get-Command "Ahk2Exe.exe" -ErrorAction SilentlyContinue
        if ($candCmd) { $ahk2exePath = $candCmd.Source }
    }

    # AHK v2 Taban Ikili Dosya Yolu (Base .exe)
    $ahkBaseCandidates = @(
        "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe",
        "C:\Program Files\AutoHotkey\AutoHotkey64.exe",
        "C:\Program Files (x86)\AutoHotkey\v2\AutoHotkey64.exe",
        "C:\Program Files (x86)\AutoHotkey\AutoHotkey64.exe",
        "C:\Program Files\AutoHotkey\v2\AutoHotkey32.exe",
        (Join-Path $projectRoot "tools\AHK2\AutoHotkey64.exe")
    )
    $ahkBasePath = $null
    foreach ($cand in $ahkBaseCandidates) {
        if (Test-Path $cand) { $ahkBasePath = $cand; break }
    }

    # Inno Setup Derleyici Yolu (ISCC.exe)
    $isccCandidates = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 5\ISCC.exe",
        "C:\Program Files\Inno Setup 5\ISCC.exe"
    )
    $isccPath = $null
    foreach ($cand in $isccCandidates) {
        if (Test-Path $cand) { $isccPath = $cand; break }
    }
    if (-not $isccPath) {
        $candCmd = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
        if ($candCmd) { $isccPath = $candCmd.Source }
    }

    # SignTool / PFX
    $signtoolCandidates = @(
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x86\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x86\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x86\signtool.exe"
    )
    $signtoolPath = $null
    foreach ($cand in $signtoolCandidates) {
        if (Test-Path $cand) { $signtoolPath = $cand; break }
    }
    if (-not $signtoolPath) {
        $signtoolCmd = Get-Command "signtool.exe" -ErrorAction SilentlyContinue
        if ($signtoolCmd) { $signtoolPath = $signtoolCmd.Source }
    }

    $imzaDir           = if (Test-Path (Join-Path $projectsParent "imza-bilgileri")) { Join-Path $projectsParent "imza-bilgileri" } else { "C:\Users\Kerem\Projects\imza-bilgileri" }
    $pfxPath           = Join-Path $imzaDir "KeremKuyucu.pfx"
    $pfxPropertiesPath = Join-Path $imzaDir "pfx.properties"
    $timestampUrl      = "http://timestamp.digicert.com"

    # -- Yardimci Fonksiyonlar -----------------------------------------------------
    function Ensure-Dir ([string]$path) {
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }

    function Escape-ProcessArg ([string]$arg) {
        if ($arg -match '\s') {
            return "`"$arg`""
        }
        return $arg
    }

    function Run-Exe {
        param(
            [Parameter(Mandatory = $true)][string]$FilePath,
            [Parameter(Mandatory = $false)][string[]]$ArgumentList = @(),
            [Parameter(Mandatory = $false)][string]$WorkingDirectory = $projectRoot,
            [Parameter(Mandatory = $false)][switch]$AllowNonZero
        )

        $resolvedPath = $FilePath
        $prependArgs  = @()
        $cmd = Get-Command $FilePath -ErrorAction SilentlyContinue
        if ($cmd) {
            $resolvedPath = $cmd.Source
            if ($resolvedPath -match '\.(bat|cmd)$') {
                $prependArgs  = @("/c", $resolvedPath)
                $resolvedPath = "$env:SystemRoot\System32\cmd.exe"
            }
        }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $resolvedPath
        $psi.WorkingDirectory       = $WorkingDirectory
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

        $allArgs = $prependArgs + $ArgumentList
        if ($allArgs.Count -gt 0) {
            $psi.Arguments = ($allArgs | ForEach-Object { Escape-ProcessArg $_ }) -join ' '
        }

        $proc           = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi

        $stdoutBuilder = New-Object System.Text.StringBuilder
        $stderrBuilder = New-Object System.Text.StringBuilder

        $onStdout = { if ($EventArgs.Data) { [void]$Event.MessageData.AppendLine($EventArgs.Data) } }
        $onStderr = { if ($EventArgs.Data) { [void]$Event.MessageData.AppendLine($EventArgs.Data) } }

        $stdoutEvent = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action $onStdout -MessageData $stdoutBuilder
        $stderrEvent = Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived  -Action $onStderr -MessageData $stderrBuilder

        Write-Host "   >> $FilePath $($psi.Arguments)" -ForegroundColor DarkGray

        try {
            [void]$proc.Start()
            $proc.BeginOutputReadLine()
            $proc.BeginErrorReadLine()
            $proc.WaitForExit()

            Start-Sleep -Milliseconds 200

            $stdout = $stdoutBuilder.ToString().TrimEnd()
            $stderr = $stderrBuilder.ToString().TrimEnd()

            if ($stdout) { Write-Host $stdout }
            if ($stderr -and $proc.ExitCode -ne 0) {
                Write-Host $stderr -ForegroundColor Red
            }
            elseif ($stderr) {
                Write-Host $stderr -ForegroundColor DarkYellow
            }

            if ($proc.ExitCode -ne 0 -and -not $AllowNonZero) {
                throw "Komut basarisiz (ExitCode=$($proc.ExitCode)): $FilePath $($psi.Arguments)"
            }
            return $proc.ExitCode
        }
        finally {
            Unregister-Event -SourceIdentifier $stdoutEvent.Name -ErrorAction SilentlyContinue
            Unregister-Event -SourceIdentifier $stderrEvent.Name -ErrorAction SilentlyContinue
            Remove-Job -Id $stdoutEvent.Id -Force -ErrorAction SilentlyContinue
            Remove-Job -Id $stderrEvent.Id -Force -ErrorAction SilentlyContinue
            $proc.Dispose()
        }
    }

    # -- 1) Versiyon Bilgisi -------------------------------------------------------
    if (-not (Test-Path $ahkScriptPath)) {
        throw "AHK kaynak dosyasi bulunamadi: $ahkScriptPath"
    }

    $currentVersion = $null
    $globalsScriptPath = Join-Path $projectRoot "lib\Globals.ahk"
    $versionSearchPaths = @($globalsScriptPath, $ahkScriptPath) | Where-Object { Test-Path $_ }

    foreach ($vPath in $versionSearchPaths) {
        $versionMatch = Select-String -Path $vPath -Pattern '(?:global\s+)?APP_VERSION\s*:=\s*["'']([^"'']+)["'']'
        if ($versionMatch) {
            $currentVersion = $versionMatch.Matches[0].Groups[1].Value.Trim()
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($currentVersion)) {
        Write-Warn "Versiyon bilgisi kaynak dosyalardan alinamadi."
        $userInput = Read-Host "Lutfen versiyon numarasini girin (Orn: 1.0.1)"
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            throw "HATA: Versiyon girmeden devam edilemez!"
        }
        $currentVersion = $userInput.Trim()
    }

    Ensure-Dir $distPath

    $verPadded = $currentVersion.PadRight(12)
    Write-Host ""
    Write-Host "+=======================================================+" -ForegroundColor Cyan
    Write-Host "|   Copilot Button Build & Deploy - Versiyon $verPadded|" -ForegroundColor Cyan
    Write-Host "+=======================================================+" -ForegroundColor Cyan

    # -- 2) Islem Secim Menusu -----------------------------------------------------
    function Show-ActionMenu {
        $actions = @(
            [pscustomobject]@{ Name = "AHK Derle (Ahk2Exe -> EXE)";      Key = "Compile";   Selected = $true }
            [pscustomobject]@{ Name = "Inno Setup Paketi (Setup.exe)";   Key = "InnoSetup"; Selected = ($null -ne $isccPath) }
            [pscustomobject]@{ Name = "Kod Imzalama (SignTool)";         Key = "Sign";      Selected = (Test-Path $pfxPath) }
        )

        if ([Console]::IsInputRedirected -or $env:CI -eq "true") {
            Write-Info "Interaktif olmayan ortam tespit edildi. Tum varsayilan adimlar secildi."
            return $actions | Where-Object { $_.Selected }
        }

        $currentIndex = 0
        $menuActive   = $true

        Write-Host "`n-- Calistirilacak Adimlar --" -ForegroundColor Cyan
        Write-Host "   Yukari/Asagi: Gezinme | Space: Sec/Kaldir | Enter: Onayla" -ForegroundColor DarkGray
        Write-Host ""

        try {
            $menuTop = [Console]::CursorTop
            for ($i = 0; $i -lt $actions.Count; $i++) { Write-Host "" }

            while ($menuActive) {
                [Console]::SetCursorPosition(0, $menuTop)

                for ($i = 0; $i -lt $actions.Count; $i++) {
                    if ($i -eq $currentIndex) { $prefix = " > " } else { $prefix = "   " }
                    if ($actions[$i].Selected) { $checkbox = "[X]" } else { $checkbox = "[ ]" }
                    if ($i -eq $currentIndex) { $color = "Yellow" } else { $color = "White" }
                    $line = "{0}{1} {2}" -f $prefix, $checkbox, $actions[$i].Name
                    Write-Host $line.PadRight(45) -ForegroundColor $color
                }

                $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                switch ($key.VirtualKeyCode) {
                    38 { if ($currentIndex -gt 0) { $currentIndex-- } }
                    40 { if ($currentIndex -lt ($actions.Count - 1)) { $currentIndex++ } }
                    32 { $actions[$currentIndex].Selected = -not $actions[$currentIndex].Selected }
                    13 { $menuActive = $false }
                }
            }
            Write-Host ""
        }
        catch {
            Write-Warn "Menu interaktif olarak acilamadi, secili varsayilan adimlarla devam ediliyor."
        }

        return $actions | Where-Object { $_.Selected }
    }

    $selectedActions = $null
    if ($InnoSetupOnly) {
        $selectedActions = @(
            [pscustomobject]@{ Name = "Inno Setup Paketi (Setup.exe)"; Key = "InnoSetup"; Selected = $true }
        )
    }
    elseif ($CompileOnly) {
        $selectedActions = @(
            [pscustomobject]@{ Name = "AHK Derle (Ahk2Exe -> EXE)"; Key = "Compile"; Selected = $true }
        )
    }
    else {
        $selectedActions = Show-ActionMenu
    }

    if (-not $selectedActions -or @($selectedActions).Count -eq 0) {
        Write-Warn "Hicbir adim secilmedi. Cikiliyor..."
        return
    }

    $selectedKeys = @($selectedActions | ForEach-Object { $_.Key })
    $stepResults  = @{}

    # -- 3) AHK Derleme (Ahk2Exe) --------------------------------------------------
    if ($selectedKeys -contains "Compile") {
        Write-Step "AutoHotkey Scripti EXE Olarak Derleniyor..."
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        if (-not $ahk2exePath -or -not (Test-Path $ahk2exePath)) {
            throw "Ahk2Exe derleyicisi bulunamadi! Lutfen AutoHotkey kurulumunu veya Ahk2Exe yolunu kontrol edin."
        }
        if (-not $ahkBasePath -or -not (Test-Path $ahkBasePath)) {
            throw "AutoHotkey v2 taban ikili dosyasi (AutoHotkey64.exe) bulunamadi!"
        }

        Write-Info "Derleyici: $ahk2exePath"
        Write-Info "Taban EXE: $ahkBasePath"
        Write-Info "Kaynak: $ahkScriptName"
        Write-Info "Hedef: $outputExePath"

        # False-positive riskini azaltmak icin /compress 0 ile derlenir
        $ahk2exeArgs = @(
            "/in", $ahkScriptPath,
            "/out", $outputExePath,
            "/base", $ahkBasePath,
            "/compress", "0"
        )

        if (Test-Path $iconPath) {
            $ahk2exeArgs += @("/icon", $iconPath)
            Write-Info "Ikon: logo.ico"
        }

        try {
            Run-Exe -FilePath $ahk2exePath -ArgumentList $ahk2exeArgs -WorkingDirectory $projectRoot

            if (-not (Test-Path $outputExePath)) {
                throw "Derleme tamamlandi ancak cikti dosyasi olusmadi: $outputExePath"
            }

            $exeItem = Get-Item $outputExePath
            $sizeMB = "{0:N2} MB" -f ($exeItem.Length / 1MB)
            $sw.Stop()

            $stepResults["Derleme (EXE)"] = [pscustomobject]@{
                Elapsed = $sw.Elapsed
                Success = $true
                Detail  = "$outputExeName ($sizeMB)"
            }
            Write-Ok "EXE basariyla olusturuldu: $outputExePath ($sizeMB) - $(Format-Elapsed $sw.Elapsed)"
        }
        catch {
            $sw.Stop()
            $stepResults["Derleme (EXE)"] = [pscustomobject]@{
                Elapsed = $sw.Elapsed
                Success = $false
                Detail  = $_.Exception.Message
            }
            Write-Err "Derleme basarisiz: $($_.Exception.Message)"
            throw
        }
    }

    # -- 4) Inno Setup Kurulum Paketi (Setup.exe) ----------------------------------
    if ($selectedKeys -contains "InnoSetup") {
        Write-Step "Inno Setup Kurulum Paketi (Setup.exe) Olusturuluyor..."
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        if (-not $isccPath -or -not (Test-Path $isccPath)) {
            throw "Inno Setup derleyicisi (ISCC.exe) bulunamadi! Lutfen Inno Setup 6 kurulumunu kontrol edin."
        }
        if (-not (Test-Path $issScriptPath)) {
            throw "Inno Setup scripti bulunamadi: $issScriptPath"
        }
        if (-not (Test-Path $outputExePath)) {
            throw "Setup paketi icin CopilotButton.exe bulunamadi: $outputExePath (Once derleme yapilmalidir)"
        }

        Write-Info "Inno Derleyici: $isccPath"
        Write-Info "Inno Script: $issScriptPath"
        Write-Info "Hedef: $setupExePath"

        $isccArgs = @(
            "/DMyAppVersion=$currentVersion",
            "/DSourceExePath=$outputExePath",
            "/DOutputDirPath=$distPath",
            $issScriptPath
        )

        try {
            Run-Exe -FilePath $isccPath -ArgumentList $isccArgs -WorkingDirectory $projectRoot

            if (-not (Test-Path $setupExePath)) {
                throw "Inno Setup derlemesi tamamlandi ancak cikti dosyasi olusmadi: $setupExePath"
            }

            $setupItem = Get-Item $setupExePath
            $sizeMB = "{0:N2} MB" -f ($setupItem.Length / 1MB)
            $sw.Stop()

            $stepResults["Inno Setup (Setup.exe)"] = [pscustomobject]@{
                Elapsed = $sw.Elapsed
                Success = $true
                Detail  = "$setupExeName ($sizeMB)"
            }
            Write-Ok "Setup.exe basariyla olusturuldu: $setupExePath ($sizeMB) - $(Format-Elapsed $sw.Elapsed)"
        }
        catch {
            $sw.Stop()
            $stepResults["Inno Setup (Setup.exe)"] = [pscustomobject]@{
                Elapsed = $sw.Elapsed
                Success = $false
                Detail  = $_.Exception.Message
            }
            Write-Err "Inno Setup derleme basarisiz: $($_.Exception.Message)"
            throw
        }
    }

    # -- 5) Kod Imzalama (SignTool + PFX) ------------------------------------------
    if ($selectedKeys -contains "Sign") {
        Write-Step "Dosyalar Imzalaniyor..."
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        if (-not $signtoolPath -or -not (Test-Path $signtoolPath)) {
            throw "signtool.exe bulunamadi: $signtoolPath"
        }
        if (-not (Test-Path $pfxPath)) {
            throw "PFX sertifika dosyasi bulunamadi: $pfxPath"
        }

        $filesToSign = @()
        if (Test-Path $outputExePath) { $filesToSign += $outputExePath }
        if (Test-Path $setupExePath)  { $filesToSign += $setupExePath }

        if ($filesToSign.Count -eq 0) {
            throw "Imzalanacak dosya bulunamadi! Once derleme veya Setup olusturma adimi secilmelidir."
        }

        $pfxPassPlain = $null
        if (Test-Path $pfxPropertiesPath) {
            $propLine = Get-Content $pfxPropertiesPath | Select-String "^\s*password\s*="
            if ($propLine) {
                $pfxPassPlain = ($propLine.ToString().Split("=", 2)[1]).Trim()
                Write-Info "PFX sifresi pfx.properties dosyasindan okundu."
            }
        }
        if ([string]::IsNullOrWhiteSpace($pfxPassPlain)) {
            Write-Warn "pfx.properties bulunamadi veya password satiri yok."
            $pfxPassSecure = Read-Host "PFX password" -AsSecureString
            $bstr          = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pfxPassSecure)
            $pfxPassPlain  = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }

        try {
            $tsServers = @(
                $timestampUrl,
                "http://timestamp.sectigo.com",
                "http://tsa.starfieldtech.com",
                "http://timestamp.globalsign.com/scripts/timstamp.dll"
            )

            foreach ($fileToSign in $filesToSign) {
                $fileName = Split-Path $fileToSign -Leaf
                Write-Info "Imzalaniyor: $fileName"

                $signed = $false
                $lastSignErr = $null

                foreach ($ts in $tsServers) {
                    try {
                        Write-Info "  Zaman damgasi deneniyor ($ts)..."
                        Run-Exe -FilePath $signtoolPath -ArgumentList @(
                            "sign", "/fd", "SHA256",
                            "/tr", $ts, "/td", "SHA256",
                            "/f", $pfxPath, "/p", $pfxPassPlain,
                            $fileToSign
                        )
                        $signed = $true
                        break
                    }
                    catch {
                        $lastSignErr = $_.Exception.Message
                        Write-Warn "  Zaman damgasi yanit vermedi ($ts), digeri deneniyor..."
                        Start-Sleep -Milliseconds 500
                    }
                }

                if (-not $signed) {
                    throw "Imzalama basarisiz ($fileName). Son hata: $lastSignErr"
                }

                $verifyExit = Run-Exe -FilePath $signtoolPath -ArgumentList @("verify", "/pa", "/v", $fileToSign) -AllowNonZero
                if ($verifyExit -eq 0) {
                    Write-Ok "$fileName basariyla imzalandi ve dogrulandi."
                } else {
                    Write-Warn "$fileName imzalandi (Self-signed sertifika uyarisi olabilir)."
                }
            }

            $sw.Stop()
            $stepResults["Imzalama"] = [pscustomobject]@{
                Elapsed = $sw.Elapsed
                Success = $true
                Detail  = "$($filesToSign.Count) dosya imzalandi"
            }
        }
        catch {
            $sw.Stop()
            $stepResults["Imzalama"] = [pscustomobject]@{
                Elapsed = $sw.Elapsed
                Success = $false
                Detail  = $_.Exception.Message
            }
            Write-Err "Imzalama basarisiz: $($_.Exception.Message)"
            throw
        }
        finally {
            Remove-Variable -Name pfxPassPlain -Force -ErrorAction SilentlyContinue
        }
    }

    # -- 6) GitHub Release (Otomatik Aciklama Dosyasi Tespiti Ile) -----------------
    $shouldCreateRelease = $false
    if ($CreateRelease) {
        $shouldCreateRelease = $true
    }
    elseif ($SkipRelease) {
        Write-Info "GitHub Release adimi parametre ile atlandi (-SkipRelease)."
    }
    elseif ([Console]::IsInputRedirected -or $NoPrompt) {
        Write-Info "Interaktif olmayan modda calisiyor; GitHub Release adimi atlandi."
    }
    else {
        Write-Host ""
        Write-Host "-- GitHub Release --" -ForegroundColor Cyan
        $answer = Read-Host "   GitHub Release olusturulsun / guncellensin mi? (e/H)"
        if ($answer -match '^[Ee]$') {
            $shouldCreateRelease = $true
        }
    }

    if ($shouldCreateRelease) {
        $releaseFiles = @()

        # Inno Setup paketi (Ana dagitim dosyasi - Sadece Setup dosyasi yuklenir)
        if (Test-Path $setupExePath) {
            $releaseFiles += $setupExePath

            # SHA256 checksum
            $sha256Setup = (Get-FileHash -Path $setupExePath -Algorithm SHA256).Hash.ToLower()
            $sha256SetupFile = "$setupExePath.sha256"
            "$sha256Setup  $setupExeName" | Set-Content -Path $sha256SetupFile -Encoding ascii
            $releaseFiles += $sha256SetupFile
            Write-Info "SHA256 checksum olusturuldu: $sha256Setup ($setupExeName)"
        }

        if ($releaseFiles.Count -eq 0) {
            Write-Warn "Release icin yuklenecek dosya bulunamadi."
        }
        else {
            $ghCheck = Get-Command "gh" -ErrorAction SilentlyContinue
            if (-not $ghCheck) {
                Write-Warn "GitHub CLI ('gh') bulunamadi. Release islemi atlandi."
            }
            else {
                $tagName      = "v$currentVersion"
                $releaseTitle = "Copilot Button v$currentVersion"

                Push-Location $projectRoot
                try {
                    $releaseNotesFile = $null
                    $notesCandidates = @(
                        (Join-Path $projectRoot "RELEASE_$currentVersion.md"),
                        (Join-Path $projectRoot "RELEASE_v$currentVersion.md"),
                        (Join-Path $projectRoot "RELEASE_NOTES.md"),
                        (Join-Path $projectRoot "RELEASE.md"),
                        (Join-Path $projectRoot "CHANGELOG.md")
                    )

                    foreach ($nc in $notesCandidates) {
                        if (Test-Path $nc) {
                            $releaseNotesFile = $nc
                            break
                        }
                    }

                    $releaseExists = $false
                    try {
                        $null = & gh release view $tagName 2>&1
                        if ($LASTEXITCODE -eq 0) { $releaseExists = $true }
                    }
                    catch { $releaseExists = $false }

                    if ($releaseExists) {
                        Write-Step "Mevcut GitHub Release'e dosyalar yukleniyor: $tagName"

                        if ($releaseNotesFile) {
                            Write-Info "Release notu dosyasi ile aciklama guncelleniyor: $(Split-Path $releaseNotesFile -Leaf)"
                            Run-Exe -FilePath "gh" -ArgumentList @("release", "edit", $tagName, "--notes-file", $releaseNotesFile) -WorkingDirectory $projectRoot
                        }

                        foreach ($file in $releaseFiles) {
                            Write-Info "Yukleniyor: $(Split-Path $file -Leaf)"
                            Run-Exe -FilePath "gh" -ArgumentList @("release", "upload", $tagName, $file, "--clobber") -WorkingDirectory $projectRoot
                        }
                        Write-Ok "Dosyalar mevcut release'e yuklendi: $tagName"
                        $stepResults["GitHub Release"] = [pscustomobject]@{
                            Elapsed = [TimeSpan]::Zero
                            Success = $true
                            Detail  = "Guncellendi ($tagName)"
                        }
                    }
                    else {
                        Write-Step "Yeni GitHub Release Olusturuluyor: $tagName"

                        $ghArgs = @("release", "create", $tagName, "--title", $releaseTitle)

                        if ($releaseNotesFile) {
                            Write-Info "Release notu dosyasi bulundu: $(Split-Path $releaseNotesFile -Leaf)"
                            $ghArgs += @("--notes-file", $releaseNotesFile)
                        }
                        else {
                            $releaseNotesContent = $ReleaseNotes
                            if ([string]::IsNullOrWhiteSpace($releaseNotesContent) -and -not [Console]::IsInputRedirected -and -not $NoPrompt) {
                                $releaseNotesContent = Read-Host "   Release notlari (bos birakilirsa GitHub otomatik uretir)"
                            }
                            if ([string]::IsNullOrWhiteSpace($releaseNotesContent)) {
                                $ghArgs += @("--generate-notes")
                            }
                            else {
                                $ghArgs += @("--notes", $releaseNotesContent)
                            }
                        }

                        foreach ($file in $releaseFiles) {
                            $ghArgs += $file
                        }

                        Run-Exe -FilePath "gh" -ArgumentList $ghArgs -WorkingDirectory $projectRoot
                        Write-Ok "GitHub Release basariyla olusturuldu: $tagName"
                        $stepResults["GitHub Release"] = [pscustomobject]@{
                            Elapsed = [TimeSpan]::Zero
                            Success = $true
                            Detail  = "Olusturuldu ($tagName)"
                        }
                    }
                }
                catch {
                    Write-Err "GitHub Release islemi basarisiz: $($_.Exception.Message)"
                    $stepResults["GitHub Release"] = [pscustomobject]@{
                        Elapsed = [TimeSpan]::Zero
                        Success = $false
                        Detail  = $_.Exception.Message
                    }
                }
                finally {
                    Pop-Location
                }
            }
        }
    }

    # -- 7) Ozet Tablosu -----------------------------------------------------------
    $scriptStopwatch.Stop()

    Write-Host ""
    Write-Host "+===================================================================+" -ForegroundColor Green
    Write-Host "|                           BUILD OZETI                             |" -ForegroundColor Green
    Write-Host "+===================================================================+" -ForegroundColor Green

    foreach ($name in $stepResults.Keys) {
        $r       = $stepResults[$name]
        $status  = if ($r.Success) { "Basarili" } else { "HATALI" }
        $sColor  = if ($r.Success) { "Green" }    else { "Red" }
        $elapsed = if ($r.Elapsed -gt [TimeSpan]::Zero) { Format-Elapsed $r.Elapsed } else { "-" }
        $line    = "|  {0,-22}  {1,-10}  {2,-10}  {3,-18}|" -f $name, $status, $elapsed, $r.Detail
        Write-Host $line -ForegroundColor $sColor
    }

    # Cikti Dosyalarini Listele
    Write-Host "+-------------------------------------------------------------------+" -ForegroundColor Green
    Write-Host "|  Uretilen Dosyalar ($distPath)" -ForegroundColor Green

    $outItems = @($outputExePath, $setupExePath) | Where-Object { Test-Path $_ }
    foreach ($itemPath in $outItems) {
        $f = Get-Item $itemPath
        $sizeStr = if ($f.Length -ge 1MB) { "{0:N2} MB" -f ($f.Length / 1MB) } else { "{0:N0} KB" -f ($f.Length / 1KB) }
        $fLine   = "|    {0,-38} {1,23}|" -f $f.Name, $sizeStr
        Write-Host $fLine -ForegroundColor White
    }

    Write-Host "+-------------------------------------------------------------------+" -ForegroundColor Green
    $totalLine = "|  Toplam Sure: {0,-52}|" -f (Format-Elapsed $scriptStopwatch.Elapsed)
    Write-Host $totalLine -ForegroundColor Cyan
    Write-Host "+===================================================================+" -ForegroundColor Green

    Write-Host ""
    Write-Ok "Copilot Button v$currentVersion yayina hazir!"
}
catch {
    Write-Host ""
    Write-Host "+=======================================================+" -ForegroundColor Red
    Write-Host "|              KRITIK HATA                              |" -ForegroundColor Red
    Write-Host "+=======================================================+" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Satir: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor DarkGray
    Write-Host "   Dosya: $($_.InvocationInfo.ScriptName)" -ForegroundColor DarkGray

    if ($null -ne $projectRoot -and (Test-Path $projectRoot)) { Set-Location $projectRoot }
}
finally {
    if (-not [Console]::IsInputRedirected -and -not $NoPrompt) {
        Write-Host "`nCikmak icin bir tusa basin..." -ForegroundColor Yellow
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch { }
    }
}
