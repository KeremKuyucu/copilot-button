<# :
@echo off
setlocal
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -Command "$content = [System.IO.File]::ReadAllText('%~f0'); $sb = [ScriptBlock]::Create($content); & $sb @args" %*
set "EXIT_CODE=%ERRORLEVEL%"
if "%~1"=="" (
    echo.
    pause
)
exit /b %EXIT_CODE%
#>
param (
    [Parameter(Position = 0)]
    [string]$NewVersion
)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[HATA] Git bulunamadi! Lutfen Git'in kurulu ve PATH'e ekli oldugundan emin olun." -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($NewVersion)) {
    $NewVersion = Read-Host "Lutfen yeni surum numarasini girin (ornek: 2.1.1)"
}

if ([string]::IsNullOrWhiteSpace($NewVersion)) {
    Write-Host "[HATA] Surum numarasi bos birakilamaz!" -ForegroundColor Red
    exit 1
}

$NewVersion = $NewVersion.Trim().Trim('"', "'").TrimStart("v").TrimStart("V")
if ($NewVersion -notmatch '^\d+\.\d+\.\d+$') {
    Write-Host "[HATA] Gecersiz surum formati! Ornek format: 2.1.1 veya 2.2.0" -ForegroundColor Red
    exit 1
}

$tagName = "v$NewVersion"

# Tag'in yerel olarak mevcut olup olmadigini kontrol et
$existingTag = git tag -l $tagName
if ($existingTag) {
    Write-Host "[HATA] '$tagName' etiketi zaten mevcut! Lutfen farkli bir surum girin." -ForegroundColor Red
    exit 1
}

$currentBranch = (git branch --show-current).Trim()
if ([string]::IsNullOrWhiteSpace($currentBranch)) {
    Write-Host "[UYARI] Aktif bir git dali tespit edilemedi. HEAD uzerinde calisiliyor." -ForegroundColor Yellow
}

# Proje kök dizinine geç (garanti)
if ($PSScriptRoot) { Set-Location (Join-Path $PSScriptRoot "..") }

$parts = $NewVersion.Split('.')
$major = $parts[0]
$minor = $parts[1]
$patch = $parts[2]
$fourPart = "$major,$minor,$patch,0"
$fourPartDot = "$major.$minor.$patch.0"

Write-Host "Surum yukseltiliyor: $NewVersion ($fourPartDot)..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# 1. resources/app.rc
$rcFile = "resources/app.rc"
if (Test-Path $rcFile) {
    $content = [System.IO.File]::ReadAllText($rcFile, [System.Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, 'FILEVERSION\s+[\d,]+', "FILEVERSION     $fourPart")
    $content = [regex]::Replace($content, 'PRODUCTVERSION\s+[\d,]+', "PRODUCTVERSION  $fourPart")
    $content = [regex]::Replace($content, 'VALUE\s+"FileVersion",\s*"[^"]+"', "VALUE `"FileVersion`",      `"$fourPartDot\0`"")
    $content = [regex]::Replace($content, 'VALUE\s+"ProductVersion",\s*"[^"]+"', "VALUE `"ProductVersion`",   `"$fourPartDot\0`"")
    [System.IO.File]::WriteAllText($rcFile, $content, $utf8NoBom)
    Write-Host "  [OK] $rcFile" -ForegroundColor Green
}

# 2. resources/app.manifest
$manifestFile = "resources/app.manifest"
if (Test-Path $manifestFile) {
    $content = [System.IO.File]::ReadAllText($manifestFile, [System.Text.Encoding]::UTF8)
    $content = [regex]::Replace($content, '(<assemblyIdentity[\s\S]*?\bversion=")[^"]+(")', "`${1}$fourPartDot`${2}")
    [System.IO.File]::WriteAllText($manifestFile, $content, $utf8NoBom)
    Write-Host "  [OK] $manifestFile" -ForegroundColor Green
}

Write-Host "`nTum dosyalar $NewVersion surumune basariyla guncellendi!" -ForegroundColor Green

# 3. Git islemleri: commit, tag ve push
Write-Host "`nGit islemleri yurutuluyor..." -ForegroundColor Cyan

$filesToStage = @(
    "resources/app.rc",
    "resources/app.manifest"
)

git add @filesToStage
if ($LASTEXITCODE -ne 0) {
    Write-Host "[HATA] Dosyalar git staging alanina eklenemedi!" -ForegroundColor Red
    exit 1
}

$commitMsg = "chore: bump version to $NewVersion"
git commit -m $commitMsg
if ($LASTEXITCODE -ne 0) {
    Write-Host "[HATA] Git commit olusturulamadi!" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Commit: $commitMsg" -ForegroundColor Green

git tag $tagName
if ($LASTEXITCODE -ne 0) {
    Write-Host "[HATA] Git tag ($tagName) olusturulamadi!" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Etiket (Tag): $tagName" -ForegroundColor Green

Write-Host "`nUzak depoya gonderiliyor (git push)..." -ForegroundColor Cyan

if (-not [string]::IsNullOrWhiteSpace($currentBranch)) {
    git push origin $currentBranch
} else {
    git push origin HEAD
}
if ($LASTEXITCODE -ne 0) {
    Write-Host "[HATA] Commit uzak depoya (origin) gonderilemedi!" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Dal (branch) basariyla gonderildi." -ForegroundColor Green

git push origin $tagName
if ($LASTEXITCODE -ne 0) {
    Write-Host "[HATA] Tag ($tagName) uzak depoya gonderilemedi!" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Tag ($tagName) basariyla gonderildi!" -ForegroundColor Green

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "  BASARILI! $tagName surumu ve etiketi gonderildi." -ForegroundColor Green
Write-Host "  GitHub Actions release pipeline otomatik olarak tetiklendi." -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
