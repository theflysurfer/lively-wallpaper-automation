# Setup-LivelyScreensaver.ps1
# Configures Lively Wallpaper as Windows screensaver

Write-Host "=== Configuring Lively as Screensaver ===" -ForegroundColor Cyan
Write-Host ""

$LivelyPath = "C:\Users\julien\AppData\Local\Programs\Lively Wallpaper"
$LivelyExe = Join-Path $LivelyPath "Lively.exe"

# Check if Lively is installed
if (-not (Test-Path $LivelyExe)) {
    Write-Error "Lively not found at: $LivelyExe"
    exit 1
}

# Lively screensaver utility path
$ScreensaverUtil = Join-Path $LivelyPath "plugins\screensaver\Lively.Screensaver.exe"

if (Test-Path $ScreensaverUtil) {
    Write-Host "Found Lively Screensaver utility!" -ForegroundColor Green
    Write-Host "Path: $ScreensaverUtil" -ForegroundColor Gray
    Write-Host ""

    # Copy to Windows System32 as .scr file
    Write-Host "Installing Lively screensaver..." -ForegroundColor Yellow

    $ScreensaverDest = "$env:SystemRoot\System32\LivelyScreensaver.scr"

    try {
        Copy-Item -Path $ScreensaverUtil -Destination $ScreensaverDest -Force
        Write-Host "  Screensaver installed to: $ScreensaverDest" -ForegroundColor Green
    } catch {
        Write-Warning "Could not copy screensaver (may need admin rights)"
    }

    Write-Host ""
    Write-Host "=== Manual Setup Required ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To activate Lively as your screensaver:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Open Lively Wallpaper application" -ForegroundColor White
    Write-Host "2. Go to Settings (gear icon)" -ForegroundColor White
    Write-Host "3. Navigate to: General > Screensaver" -ForegroundColor White
    Write-Host "4. Enable 'Use current wallpaper as screensaver'" -ForegroundColor White
    Write-Host "5. Set timeout (e.g., 5 minutes)" -ForegroundColor White
    Write-Host ""
    Write-Host "OR via Windows Settings:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Right-click Desktop > Personalize > Lock screen" -ForegroundColor White
    Write-Host "2. Click 'Screen saver settings'" -ForegroundColor White
    Write-Host "3. Select 'LivelyScreensaver' from dropdown" -ForegroundColor White
    Write-Host "4. Set wait time and click OK" -ForegroundColor White
    Write-Host ""

} else {
    Write-Warning "Lively Screensaver utility not found"
    Write-Host ""
    Write-Host "Alternative setup:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Open Lively Wallpaper" -ForegroundColor White
    Write-Host "2. Go to Settings > General > Screensaver" -ForegroundColor White
    Write-Host "3. Enable the screensaver feature" -ForegroundColor White
    Write-Host "4. Configure your preferences" -ForegroundColor White
    Write-Host ""
}

Write-Host "Recommended Screensaver Settings:" -ForegroundColor Cyan
Write-Host "  - Timeout: 5-10 minutes" -ForegroundColor Gray
Write-Host "  - Lock on resume: Enabled (for security)" -ForegroundColor Gray
Write-Host "  - Use current wallpaper: Enabled" -ForegroundColor Gray
Write-Host ""

Write-Host "Once configured, your Appa videos will play as screensaver!" -ForegroundColor Green
Write-Host ""
