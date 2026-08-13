#requires -version 5.1
<#
.SYNOPSIS
    Copilot Button - Otomatik Derle (AHK -> EXE), Imzala ve GitHub'a Dagit
.DESCRIPTION
    AutoHotkey v2 scriptini (copilot-buton.ahk) Ahk2Exe ile derler,
    signtool ile imzalar, C:\Users\Kerem\Projects\Outputs klasorune kopyalar
    ve GitHub Release olusturarak EXE dosyasini yukler.
.NOTES
    Proje kokunde calistirilmalidir.
#>

param(
    [Parameter(Mandatory = $false)][switch]$NoPrompt,
    [Parameter(Mandatory = $false)][switch]$SkipRelease,
    [Parameter(Mandatory = $false)][switch]$CreateRelease,
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

    $distPath       = "C:\Users\Kerem\Projects\Outputs"
    $ahkScriptName  = "copilot-buton.ahk"
    $ahkScriptPath  = Join-Path $projectRoot $ahkScriptName
    $outputExeName  = "CopilotButton.exe"
    $outputExePath  = Join-Path $projectRoot $outputExeName
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

    $pfxPath           = "C:\Users\Kerem\Projects\imza-bilgileri\KeremKuyucu.pfx"
    $pfxPropertiesPath = "C:\Users\Kerem\Projects\imza-bilgileri\pfx.properties"
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
    $versionMatch = Select-String -Path $ahkScriptPath -Pattern '(?:global\s+)?APP_VERSION\s*:=\s*["'']([^"'']+)["'']'
    if ($versionMatch) {
        $currentVersion = $versionMatch.Matches[0].Groups[1].Value.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($currentVersion)) {
        Write-Warn "Versiyon bilgisi $ahkScriptName dosyasindan alinamadi."
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
            [pscustomobject]@{ Name = "AHK Derle (Ahk2Exe -> EXE)";  Key = "Compile"; Selected = $true }
            [pscustomobject]@{ Name = "Kod Imzalama (SignTool)";       Key = "Sign";    Selected = (Test-Path $pfxPath) }
            [pscustomobject]@{ Name = "Cikti Klasorune Kopyala";      Key = "Dist";    Selected = $true }
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

    $selectedActions = Show-ActionMenu
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
        Write-Info "Hedef: $outputExeName"

        $ahk2exeArgs = @(
            "/in", $ahkScriptPath,
            "/out", $outputExePath,
            "/base", $ahkBasePath
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
            Write-Ok "EXE basariyla olusturuldu: $outputExeName ($sizeMB) - $(Format-Elapsed $sw.Elapsed)"
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

    # -- 4) Kod Imzalama (SignTool + PFX) ------------------------------------------
    if ($selectedKeys -contains "Sign") {
        Write-Step "EXE Dosyasi Imzalaniyor..."
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        if (-not (Test-Path $outputExePath)) {
            throw "Imzalanacak EXE bulunamadi: $outputExePath (Once derleme yapilmalidir)"
        }
        if (-not $signtoolPath -or -not (Test-Path $signtoolPath)) {
            throw "signtool.exe bulunamadi: $signtoolPath"
        }
        if (-not (Test-Path $pfxPath)) {
            throw "PFX sertifika dosyasi bulunamadi: $pfxPath"
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

            $signed = $false
            $lastSignErr = $null

            foreach ($ts in $tsServers) {
                try {
                    Write-Info "Zaman damgasi sunucusu deneniyor: $ts"
                    Run-Exe -FilePath $signtoolPath -ArgumentList @(
                        "sign", "/fd", "SHA256",
                        "/tr", $ts, "/td", "SHA256",
                        "/f", $pfxPath, "/p", $pfxPassPlain,
                        $outputExePath
                    )
                    $signed = $true
                    break
                }
                catch {
                    $lastSignErr = $_.Exception.Message
                    Write-Warn "Zaman damgasi sunucusu yanit vermedi ($ts), digeri deneniyor..."
                    Start-Sleep -Milliseconds 500
                }
            }

            if (-not $signed) {
                throw "Imzalama basarisiz oldu. Son hata: $lastSignErr"
            }

            $verifyExit = Run-Exe -FilePath $signtoolPath -ArgumentList @("verify", "/pa", "/v", $outputExePath) -AllowNonZero
            $sw.Stop()

            if ($verifyExit -eq 0) {
                $stepResults["Imzalama"] = [pscustomobject]@{
                    Elapsed = $sw.Elapsed
                    Success = $true
                    Detail  = "Imzalandi & Dogrulandi"
                }
                Write-Ok "EXE basariyla imzalandi ve dogrulandi - $(Format-Elapsed $sw.Elapsed)"
            } else {
                $stepResults["Imzalama"] = [pscustomobject]@{
                    Elapsed = $sw.Elapsed
                    Success = $true
                    Detail  = "Imzalandi (Self-Signed)"
                }
                Write-Warn "EXE imzalandi ancak dogrulama uyarisi verdi (Self-signed sertifika olabilir)."
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

    # -- 5) Cikti Klasorune Dagitim ($distPath) -------------------------------------
    if ($selectedKeys -contains "Dist") {
        Write-Step "EXE Dagitim Klasorune Kopyalaniyor ($distPath)..."
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Ensure-Dir $distPath

        $copiedFiles = @()

        if (Test-Path $outputExePath) {
            $destExe = Join-Path $distPath $outputExeName
            Copy-Item $outputExePath $destExe -Force
            $copiedFiles += $outputExeName
            Write-Info "Kopyalandi: $outputExeName -> $distPath"
        }

        $sw.Stop()
        $stepResults["Dagitim"] = [pscustomobject]@{
            Elapsed = $sw.Elapsed
            Success = $true
            Detail  = "$outputExeName kopyalandi"
        }
        Write-Ok "Dagitim klasorune kopyalama tamamlandi - $(Format-Elapsed $sw.Elapsed)"
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

        # GitHub'a sadece derlenen EXE dosyasi yuklenir
        if (Test-Path $outputExePath) {
            $releaseFiles += $outputExePath
        }

        if ($releaseFiles.Count -eq 0) {
            Write-Warn "Release icin yuklenecek EXE dosyasi bulunamadi: $outputExePath"
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
                    # Release notu dosyasini ara: RELEASE_1.0.2.md, RELEASE_v1.0.2.md, RELEASE_NOTES.md, RELEASE.md, CHANGELOG.md
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
                        Write-Step "Mevcut GitHub Release'e EXE yukleniyor: $tagName"

                        # Eger release notu dosyasi varsa release aciklamasini da guncelle
                        if ($releaseNotesFile) {
                            Write-Info "Release notu dosyasi ile aciklama guncelleniyor: $(Split-Path $releaseNotesFile -Leaf)"
                            Run-Exe -FilePath "gh" -ArgumentList @("release", "edit", $tagName, "--notes-file", $releaseNotesFile) -WorkingDirectory $projectRoot
                        }

                        foreach ($file in $releaseFiles) {
                            Write-Info "Yukleniyor: $(Split-Path $file -Leaf)"
                            Run-Exe -FilePath "gh" -ArgumentList @("release", "upload", $tagName, $file, "--clobber") -WorkingDirectory $projectRoot
                        }
                        Write-Ok "EXE mevcut release'e yuklendi: $tagName"
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
                                $releaseNotesContent = Read-Host "   Release notlari (bos birakilirsa otomatik tarihli not atanir)"
                            }
                            if ([string]::IsNullOrWhiteSpace($releaseNotesContent)) {
                                $releaseNotesContent = "Copilot Button v$currentVersion - $(Get-Date -Format 'yyyy-MM-dd')"
                            }
                            $ghArgs += @("--notes", $releaseNotesContent)
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
        $line    = "|  {0,-20}  {1,-10}  {2,-10}  {3,-18}|" -f $name, $status, $elapsed, $r.Detail
        Write-Host $line -ForegroundColor $sColor
    }

    # Cikti Dosyalarini Listele
    $outputItems = @()
    if (Test-Path $outputExePath) { $outputItems += (Get-Item $outputExePath) }

    if ($outputItems.Count -gt 0) {
        Write-Host "+-------------------------------------------------------------------+" -ForegroundColor Green
        Write-Host "|  Uretilen Dosyalar (Proje Dizini)" -ForegroundColor Green
        foreach ($f in $outputItems) {
            $sizeStr = if ($f.Length -ge 1MB) { "{0:N2} MB" -f ($f.Length / 1MB) } else { "{0:N0} KB" -f ($f.Length / 1KB) }
            $fLine   = "|    {0,-38} {1,23}|" -f $f.Name, $sizeStr
            Write-Host $fLine -ForegroundColor White
        }
    }

    if (Test-Path $distPath) {
        $distFiles = Get-ChildItem -Path $distPath -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*CopilotButton.exe*" } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 5
        if ($distFiles) {
            Write-Host "+-------------------------------------------------------------------+" -ForegroundColor Green
            Write-Host "|  Dagitim Klasoru ($distPath)" -ForegroundColor Green
            foreach ($f in $distFiles) {
                $sizeStr = if ($f.Length -ge 1MB) { "{0:N2} MB" -f ($f.Length / 1MB) } else { "{0:N0} KB" -f ($f.Length / 1KB) }
                $fLine   = "|    {0,-38} {1,23}|" -f $f.Name, $sizeStr
                Write-Host $fLine -ForegroundColor White
            }
        }
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
