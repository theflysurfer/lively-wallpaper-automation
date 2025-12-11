# Set-LockScreenDirect.ps1
# Directly sets a GIF as lock screen by copying to Windows SystemData folder
# Bypasses LockscreenGif.exe UI completely
# REQUIRES: Administrator privileges

param(
    [Parameter(Mandatory=$true)]
    [string]$GifPath,

    [Parameter(Mandatory=$false)]
    [string]$UserSid
)

# Verify admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator, or use:" -ForegroundColor Yellow
    Write-Host "  Start-Process powershell -Verb RunAs -ArgumentList '-File `"$PSCommandPath`" -GifPath `"$GifPath`"'" -ForegroundColor Cyan
    exit 1
}

# Verify GIF exists (must be absolute path when running as admin)
if (-not (Test-Path $GifPath)) {
    Write-Error "GIF not found: $GifPath"
    Write-Error "Note: When running as admin, the path must be absolute."
    exit 1
}

$GifPath = (Resolve-Path $GifPath).Path
Write-Host "Setting lock screen from: $GifPath"

# Get user SID - use provided SID or detect from existing SystemData folders
if (-not $UserSid) {
    # First try: current user's SID (works if same user ran elevated)
    $currentSid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    $testPath = "C:\ProgramData\Microsoft\Windows\SystemData\$currentSid"

    if (Test-Path $testPath -ErrorAction SilentlyContinue) {
        $UserSid = $currentSid
    } else {
        # Second try: find existing user SID folder in SystemData (not SYSTEM S-1-5-18)
        $systemDataPath = "C:\ProgramData\Microsoft\Windows\SystemData"
        $userFolders = Get-ChildItem $systemDataPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^S-1-5-21-' }

        if ($userFolders) {
            $UserSid = ($userFolders | Select-Object -First 1).Name
        } else {
            # Last resort: use current SID
            $UserSid = $currentSid
        }
    }
}
Write-Host "User SID: $UserSid"

# Define paths
$systemDataBase = "C:\ProgramData\Microsoft\Windows\SystemData"
$readOnlyPath = "$systemDataBase\$UserSid\ReadOnly"

# Common screen resolutions to create
$resolutions = @(
    @{Width=1366; Height=768},
    @{Width=1400; Height=1050},
    @{Width=1440; Height=900},
    @{Width=1920; Height=1080},
    @{Width=1920; Height=1200},
    @{Width=2560; Height=1440},
    @{Width=2560; Height=1600},
    @{Width=3840; Height=2160},
    @{Width=3840; Height=2400}
)

# Function to take ownership and grant permissions
function Set-FolderPermissions {
    param([string]$Path)

    Write-Host "  Taking ownership of: $Path"

    # Take ownership for Administrators
    $takeownResult = cmd /c "takeown /f `"$Path`" /r /a /d o" 2>&1

    # Grant full control using SID (works regardless of language)
    # S-1-5-32-544 = Administrators
    # S-1-1-0 = Everyone
    cmd /c "icacls `"$Path`" /grant *S-1-5-32-544:(OI)(CI)F /T /C /Q" 2>&1 | Out-Null
    cmd /c "icacls `"$Path`" /grant *S-1-1-0:(OI)(CI)F /T /C /Q" 2>&1 | Out-Null

    Start-Sleep -Milliseconds 300
}

# Ensure ReadOnly folder exists and has permissions
if (-not (Test-Path $readOnlyPath)) {
    Write-Host "Creating ReadOnly folder..."
    New-Item -ItemType Directory -Path $readOnlyPath -Force | Out-Null
}

Set-FolderPermissions -Path $readOnlyPath

# Use LockScreen_C for custom lock screen (LockScreen_Z is for Spotlight default)
$lockScreenFolder = "$readOnlyPath\LockScreen_C"

# Create or clear the folder
if (Test-Path $lockScreenFolder) {
    Write-Host "Clearing existing LockScreen_C folder..."
    # Delete existing files (errors are OK - files will be overwritten anyway)
    Get-ChildItem $lockScreenFolder -ErrorAction SilentlyContinue | ForEach-Object {
        try { Remove-Item $_.FullName -Force -ErrorAction Stop } catch { }
    }
} else {
    Write-Host "Creating LockScreen_C folder..."
    New-Item -ItemType Directory -Path $lockScreenFolder -Force | Out-Null
}

Set-FolderPermissions -Path $lockScreenFolder

# Copy the GIF as LockScreen.jpg (Windows reads it despite the extension)
$mainLockScreenPath = "$lockScreenFolder\LockScreen.jpg"
Write-Host "Copying GIF to: $mainLockScreenPath"
Copy-Item -Path $GifPath -Destination $mainLockScreenPath -Force

# Create resolution-specific copies (same file, different names)
Write-Host "Creating resolution-specific copies..."
foreach ($res in $resolutions) {
    $fileName = "LockScreen___$($res.Width)_$($res.Height)_notdimmed.jpg"
    $destPath = "$lockScreenFolder\$fileName"
    Copy-Item -Path $GifPath -Destination $destPath -Force
    Write-Host "  Created: $fileName"
}

# Clear the registry key that might override our setting
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
if (Test-Path $regPath) {
    Write-Host "Removing PersonalizationCSP registry key..."
    Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Also update the user's personalization setting
$userRegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lock Screen"
if (-not (Test-Path $userRegPath)) {
    New-Item -Path $userRegPath -Force | Out-Null
}

# Point to our custom lock screen
# The value tells Windows which LockScreen_ folder to use
# We don't need to set this if LockScreen_C is already the active one

Write-Host ""
Write-Host "Lock screen set successfully!" -ForegroundColor Green
Write-Host "The change should be visible on your next lock screen."
