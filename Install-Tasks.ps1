# Install-Tasks.ps1
# Creates scheduled tasks for Lively wallpaper and lock screen switching
# Requires Administrator privileges

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait
    exit
}

Write-Host "=== Installing Scheduled Tasks ===" -ForegroundColor Cyan
Write-Host ""

$ScriptPath = Join-Path $PSScriptRoot "Switch-Wallpapers.ps1"

# Verify script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Switch-Wallpapers.ps1 not found at: $ScriptPath"
    exit 1
}

# Task settings (shared)
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

# Triggers: every hour from 5h to 22h + at logon
$Triggers = @()
for ($hour = 5; $hour -le 22; $hour++) {
    $TimeString = "{0:D2}:00" -f $hour
    $Triggers += New-ScheduledTaskTrigger -Daily -At $TimeString
}
$Triggers += New-ScheduledTaskTrigger -AtLogOn

# ========================================
# Task 1: Lively Wallpaper (user level)
# ========================================
$LivelyTaskName = "LivelyWallpaperSunriseSunset"

Write-Host "[1/2] Creating Lively wallpaper task..." -ForegroundColor Yellow

# Remove existing task
$ExistingTask = Get-ScheduledTask -TaskName $LivelyTaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    Unregister-ScheduledTask -TaskName $LivelyTaskName -Confirm:$false
    Write-Host "  Removed existing task" -ForegroundColor Gray
}

# Also remove old task names
@("LivelyWallpaperDayNightSwitch") | ForEach-Object {
    $OldTask = Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue
    if ($OldTask) {
        Unregister-ScheduledTask -TaskName $_ -Confirm:$false
    }
}

$LivelyAction = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -LivelyOnly"

$LivelyPrincipal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $LivelyTaskName `
    -Action $LivelyAction `
    -Trigger $Triggers `
    -Settings $Settings `
    -Principal $LivelyPrincipal `
    -Description "Switches Lively wallpaper based on Paris sunrise/sunset times" | Out-Null

Write-Host "  Created: $LivelyTaskName" -ForegroundColor Green

# ========================================
# Task 2: Lock Screen (SYSTEM level)
# ========================================
$LockScreenTaskName = "AppaLockScreenSwitcher"

Write-Host "[2/2] Creating lock screen task..." -ForegroundColor Yellow

# Remove existing task
$ExistingTask = Get-ScheduledTask -TaskName $LockScreenTaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    Unregister-ScheduledTask -TaskName $LockScreenTaskName -Confirm:$false
    Write-Host "  Removed existing task" -ForegroundColor Gray
}

$LockScreenAction = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -LockScreenOnly"

$LockScreenPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $LockScreenTaskName `
    -Action $LockScreenAction `
    -Trigger $Triggers `
    -Settings $Settings `
    -Principal $LockScreenPrincipal `
    -Description "Switches Windows lock screen based on Paris sunrise/sunset times" | Out-Null

Write-Host "  Created: $LockScreenTaskName" -ForegroundColor Green

# ========================================
# Summary
# ========================================
Write-Host ""
Write-Host "=== Tasks Installed ===" -ForegroundColor Green
Write-Host ""
Write-Host "Scheduled tasks:" -ForegroundColor Cyan
Write-Host "  - $LivelyTaskName (runs as $env:USERNAME)"
Write-Host "  - $LockScreenTaskName (runs as SYSTEM)"
Write-Host ""
Write-Host "Schedule:" -ForegroundColor Cyan
Write-Host "  - Every hour from 5:00 to 22:00"
Write-Host "  - At user logon"
Write-Host ""
Write-Host "Test now: .\Switch-Wallpapers.ps1" -ForegroundColor Yellow
Write-Host ""
