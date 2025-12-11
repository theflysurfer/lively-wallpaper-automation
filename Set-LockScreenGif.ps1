<#
.SYNOPSIS
    Sets an animated GIF as the Windows lock screen (requires admin rights)
.DESCRIPTION
    Copies a GIF file to all Windows lock screen cache locations, replacing
    the existing lock screen images. This replicates what LockscreenGif does.
.PARAMETER GifPath
    Path to the GIF file to set as lock screen
.EXAMPLE
    .\Set-LockScreenGif.ps1 -GifPath "C:\path\to\wallpaper.gif"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$GifPath
)

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires administrator privileges. Please run as admin."
    exit 1
}

# Resolve path (handle relative paths)
if (-not [System.IO.Path]::IsPathRooted($GifPath)) {
    $GifPath = Join-Path $PSScriptRoot $GifPath
}

# Validate GIF file exists
if (-not (Test-Path $GifPath)) {
    Write-Error "GIF file not found: $GifPath"
    exit 1
}

# Get absolute path
$GifPath = (Resolve-Path $GifPath).Path

# Get current user SID
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$userSid = $currentUser.User.Value

Write-Host "User SID: $userSid"
Write-Host "Setting lock screen from: $GifPath"

# Base path for lock screen data
$basePath = "C:\ProgramData\Microsoft\Windows\SystemData\$userSid\ReadOnly"

# Lock screen folders
$lockScreenFolders = @(
    "$basePath",
    "$basePath\LockScreen_A",
    "$basePath\LockScreen_B",
    "$basePath\LockScreen_C",
    "$basePath\LockScreen_Z"
)

# File names to copy the GIF to (all with .jpg extension but contain GIF data)
$filePatterns = @(
    "LockScreen.jpg",
    "LockScreen___1366x768_notdimmed.jpg",
    "LockScreen___1440x900_notdimmed.jpg",
    "LockScreen___1920x1080_notdimmed.jpg",
    "LockScreen___1920_1200_notdimmed.jpg",
    "LockScreen___2560x1440_notdimmed.jpg",
    "LockScreen___3840x2160_notdimmed.jpg"
)

# Take ownership and set permissions using takeown/icacls (same as LockscreenGif)
Write-Host "Taking ownership of lock screen cache..."
try {
    # Take ownership recursively (like LockscreenGif does)
    $takeownResult = & takeown /f "$basePath" /r /a 2>&1
    Write-Host "takeown result: $takeownResult"

    # Grant everyone full control (like LockscreenGif does with *S-1-1-0)
    $icaclsResult = & icacls "$basePath" /grant "*S-1-1-0:(F)" /T /C 2>&1
    Write-Host "icacls result: $icaclsResult"
} catch {
    Write-Warning "Could not modify permissions: $_"
}

# Copy GIF to all lock screen locations
$successCount = 0
$totalCount = 0

foreach ($folder in $lockScreenFolders) {
    if (-not (Test-Path $folder)) {
        Write-Warning "Folder not found: $folder"
        continue
    }

    # Get all jpg files in this folder that match lock screen patterns
    $files = Get-ChildItem -Path $folder -Filter "LockScreen*.jpg" -ErrorAction SilentlyContinue

    foreach ($file in $files) {
        $totalCount++
        try {
            # Copy GIF content, overwriting existing file
            Copy-Item -Path $GifPath -Destination $file.FullName -Force -ErrorAction Stop
            Write-Host "  Copied to: $($file.FullName)"
            $successCount++
        } catch {
            Write-Warning "  Failed to copy to $($file.FullName): $_"
        }
    }

    # Also copy the standard patterns if they don't exist
    foreach ($pattern in $filePatterns) {
        $targetPath = Join-Path $folder $pattern
        if (-not (Test-Path $targetPath)) {
            # Create the file
            $totalCount++
            try {
                Copy-Item -Path $GifPath -Destination $targetPath -Force -ErrorAction Stop
                Write-Host "  Created: $targetPath"
                $successCount++
            } catch {
                Write-Warning "  Failed to create $targetPath`: $_"
            }
        }
    }
}

# Also copy to the Pictures folder (where LockscreenGif stores its wallpaper)
$picturesPath = [Environment]::GetFolderPath('MyPictures')
$lockscreenGifFolder = Join-Path $picturesPath "LockscreenGif"
if (-not (Test-Path $lockscreenGifFolder)) {
    New-Item -ItemType Directory -Path $lockscreenGifFolder -Force | Out-Null
}
$wallpaperPath = Join-Path $lockscreenGifFolder "wallpaper.gif"
try {
    Copy-Item -Path $GifPath -Destination $wallpaperPath -Force
    Write-Host "  Copied to: $wallpaperPath"
} catch {
    Write-Warning "  Failed to copy to $wallpaperPath`: $_"
}

Write-Host ""
Write-Host "Done! Copied GIF to $successCount/$totalCount locations."
Write-Host "Lock your screen (Win+L) to see the animated lock screen."
