# Setup-Assets.ps1
# Creates symlinks for Lively wallpapers and lock screen images
# Requires Administrator privileges

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait
    exit
}

Write-Host "=== Setting up Lively Assets ===" -ForegroundColor Cyan
Write-Host ""

$RepoPath = $PSScriptRoot
$AssetsPath = Join-Path $RepoPath "assets"

# Source files
$Sources = @{
    "appa-day.mp4" = "C:\Users\julien\OneDrive\Documents\04.Fichiers images et photos\05.Wallpapers\YTDown.com_YouTube_flying-on-appa-avatar-the-last-airbender_Media_E5LrYdPVY4M_001_1080p.mp4"
    "appa-night.mp4" = "C:\Users\julien\OneDrive\Documents\04.Fichiers images et photos\05.Wallpapers\YTDown.com_YouTube_Appa-Night-Ride_Media_qWyPbnAFscY_001_1080p.mp4"
    "appa-day-lockscreen.jpg" = "$env:USERPROFILE\Pictures\Appa Lockscreen\appa-day-lockscreen.jpg"
    "appa-night-lockscreen.jpg" = "$env:USERPROFILE\Pictures\Appa Lockscreen\appa-night-lockscreen.jpg"
}

# Create assets folder
if (-not (Test-Path $AssetsPath)) {
    New-Item -ItemType Directory -Path $AssetsPath -Force | Out-Null
    Write-Host "Created: $AssetsPath" -ForegroundColor Green
}

# Create symlinks
Write-Host ""
Write-Host "Creating symlinks..." -ForegroundColor Yellow

foreach ($Link in $Sources.Keys) {
    $LinkPath = Join-Path $AssetsPath $Link
    $Target = $Sources[$Link]

    # Remove existing link/file
    if (Test-Path $LinkPath) {
        Remove-Item $LinkPath -Force
    }

    # Check if source exists
    if (-not (Test-Path $Target)) {
        Write-Host "  [SKIP] $Link - Source not found: $Target" -ForegroundColor Red
        continue
    }

    # Create symlink
    $null = cmd /c mklink "$LinkPath" "$Target" 2>&1
    if (Test-Path $LinkPath) {
        Write-Host "  [OK] $Link" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Link" -ForegroundColor Red
    }
}

# Also setup Lively library wallpapers if they don't exist
Write-Host ""
Write-Host "Checking Lively library..." -ForegroundColor Yellow

$LivelyLibrary = "$env:LOCALAPPDATA\Lively Wallpaper\Library\wallpapers"

$LivelyWallpapers = @{
    "appa-day" = @{
        Video = $Sources["appa-day.mp4"]
        Title = "Appa Flying (Day)"
    }
    "appa-night" = @{
        Video = $Sources["appa-night.mp4"]
        Title = "Appa Night Ride"
    }
}

foreach ($Name in $LivelyWallpapers.Keys) {
    $WallpaperPath = Join-Path $LivelyLibrary $Name
    $VideoSource = $LivelyWallpapers[$Name].Video
    $Title = $LivelyWallpapers[$Name].Title

    if (Test-Path $WallpaperPath) {
        Write-Host "  [EXISTS] $Name" -ForegroundColor Gray
        continue
    }

    if (-not (Test-Path $VideoSource)) {
        Write-Host "  [SKIP] $Name - Video not found" -ForegroundColor Red
        continue
    }

    # Create wallpaper folder
    New-Item -ItemType Directory -Path $WallpaperPath -Force | Out-Null

    # Copy video
    $VideoName = "$Name.mp4"
    Copy-Item $VideoSource (Join-Path $WallpaperPath $VideoName)

    # Create LivelyInfo.json
    $LivelyInfo = @{
        Preview = ""
        FileName = $VideoName
        Type = "video"
        AppVersion = "2.2.1.0"
        IsAbsolutePath = $false
        Author = "Avatar: The Last Airbender"
        Desc = ""
        Contact = ""
        Arguments = $null
        Title = $Title
        License = ""
        Thumbnail = ""
    } | ConvertTo-Json

    Set-Content -Path (Join-Path $WallpaperPath "LivelyInfo.json") -Value $LivelyInfo

    Write-Host "  [CREATED] $Name" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Assets folder: $AssetsPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run Install-Tasks.ps1 to create scheduled tasks"
Write-Host "  2. Run Switch-Wallpapers.ps1 to test"
Write-Host ""
