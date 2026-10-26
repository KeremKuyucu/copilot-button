param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$NewVersion
)

$NewVersion = $NewVersion.Trim().TrimStart("v")
if ($NewVersion -notmatch '^\d+\.\d+\.\d+$') {
    Write-Error "Gecersiz surum formati! Ornek format: 2.0.2 veya 2.1.0"
    exit 1
}

$parts = $NewVersion.Split('.')
$major = $parts[0]
$minor = $parts[1]
$patch = $parts[2]
$fourPart = "$major,$minor,$patch,0"
$fourPartDot = "$major.$minor.$patch.0"

Write-Host "Surum yukseltiliyor: $NewVersion ($fourPartDot)..." -ForegroundColor Cyan

# 1. gui/include/WebViewSettings.hpp
$file = "gui/include/WebViewSettings.hpp"
if (Test-Path $file) {
    (Get-Content $file -Raw) -replace 'APP_VERSION\s*=\s*"[^"]+"', "APP_VERSION = `"$NewVersion`"" | Set-Content $file -NoNewline
    Write-Host "  [OK] $file" -ForegroundColor Green
}

# 2. html/index.html
$file = "html/index.html"
if (Test-Path $file) {
    $content = Get-Content $file -Raw
    $content = $content -replace '(<span[^>]*id="versionBadge"[^>]*>)v[^<]+(</span>)', "`${1}v$NewVersion`${2}"
    $content = $content -replace "let g_currentVersion = '[^']+';", "let g_currentVersion = '$NewVersion';"
    Set-Content $file $content -NoNewline
    Write-Host "  [OK] $file" -ForegroundColor Green
}

# 3. gui/app.rc & engine/app.rc
$rcFiles = @("gui/app.rc", "engine/app.rc")
foreach ($file in $rcFiles) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        $content = $content -replace 'FILEVERSION\s+[\d,]+', "FILEVERSION     $fourPart"
        $content = $content -replace 'PRODUCTVERSION\s+[\d,]+', "PRODUCTVERSION  $fourPart"
        $content = $content -replace 'VALUE\s+"FileVersion",\s*"[^"]+"', "VALUE `"FileVersion`",      `"$fourPartDot\0`""
        $content = $content -replace 'VALUE\s+"ProductVersion",\s*"[^"]+"', "VALUE `"ProductVersion`",   `"$fourPartDot\0`""
        Set-Content $file $content -NoNewline
        Write-Host "  [OK] $file" -ForegroundColor Green
    }
}

# 4. gui/app.manifest & engine/app.manifest
$manifestFiles = @("gui/app.manifest", "engine/app.manifest")
foreach ($file in $manifestFiles) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        $content = $content -replace '(<assemblyIdentity[\s\S]*?\bversion=")[^"]+(")', "`${1}$fourPartDot`${2}"
        Set-Content $file $content -NoNewline
        Write-Host "  [OK] $file" -ForegroundColor Green
    }
}

Write-Host "`nTum dosyalar $NewVersion surumune basariyla guncellendi!" -ForegroundColor Green
Write-Host "Git commit ve tag icin:" -ForegroundColor Yellow
Write-Host "  git commit -am `"chore: bump version to $NewVersion`"" -ForegroundColor Gray
Write-Host "  git tag v$NewVersion" -ForegroundColor Gray
Write-Host "  git push origin main --tags" -ForegroundColor Gray
