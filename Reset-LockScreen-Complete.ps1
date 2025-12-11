<#
.SYNOPSIS
    Complete reset of Windows lock screen to default state
.DESCRIPTION
    This script performs a comprehensive reset of the Windows lock screen by:
    1. Deleting the PersonalizationCSP registry key
    2. Taking ownership and clearing SystemData lock screen cache
    3. Clearing Windows Spotlight assets and settings
    4. Clearing LockscreenGif app data
    5. Re-registering ContentDeliveryManager
.NOTES
    Requires administrator privileges
    Based on research from multiple sources for complete lock screen reset
#>

param(
    [switch]$Force
)

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires administrator privileges. Please run as admin."
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Complete Lock Screen Reset Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get current user SID
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$userSid = $currentUser.User.Value
Write-Host "User SID: $userSid" -ForegroundColor Gray

# ============================================
# STEP 1: Delete PersonalizationCSP registry key
# ============================================
Write-Host ""
Write-Host "[1/6] Deleting PersonalizationCSP registry key..." -ForegroundColor Yellow

$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
if (Test-Path $regPath) {
    try {
        Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
        Write-Host "  SUCCESS: PersonalizationCSP registry key deleted" -ForegroundColor Green
    } catch {
        Write-Warning "  Could not delete PersonalizationCSP: $_"
    }
} else {
    Write-Host "  INFO: PersonalizationCSP key does not exist (already clean)" -ForegroundColor Gray
}

# ============================================
# STEP 2: Clear SystemData lock screen cache
# ============================================
Write-Host ""
Write-Host "[2/6] Clearing SystemData lock screen cache..." -ForegroundColor Yellow

$systemDataPath = "C:\ProgramData\Microsoft\Windows\SystemData\$userSid\ReadOnly"

if (Test-Path $systemDataPath -ErrorAction SilentlyContinue) {
    Write-Host "  Taking ownership of: $systemDataPath"

    # Use cmd /c to run takeown and icacls properly
    # First take ownership for Administrators group
    cmd /c "takeown /f `"$systemDataPath`" /r /a /d o" 2>&1 | Out-Null
    Write-Host "  takeown completed" -ForegroundColor Gray

    # Grant full control to Administrators and Everyone
    cmd /c "icacls `"$systemDataPath`" /grant Administrateurs:(OI)(CI)F /T /C /Q" 2>&1 | Out-Null
    cmd /c "icacls `"$systemDataPath`" /grant Administrators:(OI)(CI)F /T /C /Q" 2>&1 | Out-Null
    cmd /c "icacls `"$systemDataPath`" /grant *S-1-1-0:(OI)(CI)F /T /C /Q" 2>&1 | Out-Null
    Write-Host "  icacls completed" -ForegroundColor Gray

    # Small delay to let permissions propagate
    Start-Sleep -Milliseconds 500

    # Delete LockScreen folders (A, B, C, but keep Z which is default)
    $lockScreenFolders = @("LockScreen_A", "LockScreen_B", "LockScreen_C")
    foreach ($folder in $lockScreenFolders) {
        $folderPath = Join-Path $systemDataPath $folder
        if (Test-Path $folderPath -ErrorAction SilentlyContinue) {
            # Use cmd /c rd to force delete
            cmd /c "rd /s /q `"$folderPath`"" 2>&1 | Out-Null
            if (-not (Test-Path $folderPath -ErrorAction SilentlyContinue)) {
                Write-Host "  Deleted: $folder" -ForegroundColor Green
            } else {
                Write-Warning "  Could not delete $folder (may be in use)"
            }
        }
    }

    # Also clear any LockScreen*.jpg files in the base ReadOnly folder using cmd del
    $jpgFiles = cmd /c "dir /b `"$systemDataPath\LockScreen*.jpg`" 2>nul"
    if ($jpgFiles) {
        cmd /c "del /f /q `"$systemDataPath\LockScreen*.jpg`"" 2>&1 | Out-Null
        Write-Host "  Cleared LockScreen*.jpg files" -ForegroundColor Green
    }

    Write-Host "  SUCCESS: SystemData cache cleared" -ForegroundColor Green
} else {
    Write-Host "  INFO: SystemData path does not exist" -ForegroundColor Gray
}

# Also clear SYSTEM user's lock screen cache (S-1-5-18)
$systemUserPath = "C:\ProgramData\Microsoft\Windows\SystemData\S-1-5-18\ReadOnly"
# Skip if access denied - this is less critical
try {
    if (Test-Path $systemUserPath -ErrorAction Stop) {
        Write-Host "  Clearing SYSTEM user lock screen cache..."
        cmd /c "takeown /f `"$systemUserPath`" /r /a /d o" 2>&1 | Out-Null
        cmd /c "icacls `"$systemUserPath`" /grant *S-1-1-0:(OI)(CI)F /T /C /Q" 2>&1 | Out-Null

        $systemLockScreenFolders = Get-ChildItem -Path $systemUserPath -Directory -Filter "LockScreen_*" -ErrorAction SilentlyContinue
        foreach ($folder in $systemLockScreenFolders) {
            if ($folder.Name -ne "LockScreen_Z") {
                cmd /c "rd /s /q `"$($folder.FullName)`"" 2>&1 | Out-Null
                if (-not (Test-Path $folder.FullName -ErrorAction SilentlyContinue)) {
                    Write-Host "  Deleted SYSTEM: $($folder.Name)" -ForegroundColor Green
                }
            }
        }
    }
} catch {
    Write-Host "  INFO: SYSTEM user path not accessible (normal)" -ForegroundColor Gray
}

# ============================================
# STEP 3: Clear Windows Spotlight assets
# ============================================
Write-Host ""
Write-Host "[3/6] Clearing Windows Spotlight assets..." -ForegroundColor Yellow

$spotlightAssetsPath = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets"
if (Test-Path $spotlightAssetsPath) {
    try {
        Remove-Item -Path "$spotlightAssetsPath\*" -Force -ErrorAction SilentlyContinue
        Write-Host "  SUCCESS: Spotlight assets cleared" -ForegroundColor Green
    } catch {
        Write-Warning "  Could not clear Spotlight assets: $_"
    }
} else {
    Write-Host "  INFO: Spotlight assets folder does not exist" -ForegroundColor Gray
}

# ============================================
# STEP 4: Clear Windows Spotlight settings
# ============================================
Write-Host ""
Write-Host "[4/6] Clearing Windows Spotlight settings..." -ForegroundColor Yellow

$spotlightSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\Settings"
if (Test-Path $spotlightSettingsPath) {
    $filesToDelete = @("settings.dat", "roaming.lock")
    foreach ($file in $filesToDelete) {
        $filePath = Join-Path $spotlightSettingsPath $file
        if (Test-Path $filePath) {
            try {
                Remove-Item -Path $filePath -Force -ErrorAction Stop
                Write-Host "  Deleted: $file" -ForegroundColor Green
            } catch {
                Write-Warning "  Could not delete $file`: $_"
            }
        }
    }
    Write-Host "  SUCCESS: Spotlight settings cleared" -ForegroundColor Green
} else {
    Write-Host "  INFO: Spotlight settings folder does not exist" -ForegroundColor Gray
}

# ============================================
# STEP 5: Clear LockscreenGif app data
# ============================================
Write-Host ""
Write-Host "[5/6] Clearing LockscreenGif app data..." -ForegroundColor Yellow

$picturesPath = [Environment]::GetFolderPath('MyPictures')
$lockscreenGifFolder = Join-Path $picturesPath "LockscreenGif"
if (Test-Path $lockscreenGifFolder) {
    try {
        Remove-Item -Path "$lockscreenGifFolder\*" -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "  SUCCESS: LockscreenGif folder cleared" -ForegroundColor Green
    } catch {
        Write-Warning "  Could not clear LockscreenGif folder: $_"
    }
} else {
    Write-Host "  INFO: LockscreenGif folder does not exist" -ForegroundColor Gray
}

# ============================================
# STEP 6: Re-register ContentDeliveryManager
# ============================================
Write-Host ""
Write-Host "[6/6] Re-registering ContentDeliveryManager..." -ForegroundColor Yellow

try {
    $cdmPackage = Get-AppxPackage -AllUsers *ContentDeliveryManager* -ErrorAction SilentlyContinue
    if ($cdmPackage) {
        foreach ($pkg in $cdmPackage) {
            $manifest = Join-Path $pkg.InstallLocation "AppxManifest.xml"
            if (Test-Path $manifest) {
                Add-AppxPackage -Register $manifest -DisableDevelopmentMode -ErrorAction SilentlyContinue
            }
        }
        Write-Host "  SUCCESS: ContentDeliveryManager re-registered" -ForegroundColor Green
    } else {
        Write-Host "  INFO: ContentDeliveryManager package not found" -ForegroundColor Gray
    }
} catch {
    Write-Warning "  Could not re-register ContentDeliveryManager: $_"
}

# ============================================
# DONE
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Lock Screen Reset Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now apply your GIF with LockscreenGif." -ForegroundColor Yellow
