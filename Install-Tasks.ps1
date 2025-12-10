# Install-Tasks.ps1
# Creates a single scheduled task that runs daily at 4 AM (and at logon)
# to schedule the exact sunrise/sunset wallpaper changes for the day
# Requires Administrator privileges

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait
    exit
}

Write-Host "=== Installing Scheduled Task ===" -ForegroundColor Cyan
Write-Host ""

$SchedulerScript = Join-Path $PSScriptRoot "Schedule-DailyTasks.ps1"

# Verify script exists
if (-not (Test-Path $SchedulerScript)) {
    Write-Error "Schedule-DailyTasks.ps1 not found at: $SchedulerScript"
    exit 1
}

$TaskName = "AppaWallpaper_DailyScheduler"

# Remove existing tasks
Write-Host "Cleaning up old tasks..." -ForegroundColor Yellow
@($TaskName, "LivelyWallpaperSunriseSunset", "AppaLockScreenSwitcher", "LivelyWallpaperDayNightSwitch") | ForEach-Object {
    $Existing = Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue
    if ($Existing) {
        Unregister-ScheduledTask -TaskName $_ -Confirm:$false
        Write-Host "  Removed: $_" -ForegroundColor Gray
    }
}

# Also clean up any one-time tasks from previous runs
@("AppaWallpaper_Sunrise", "AppaWallpaper_Sunset") | ForEach-Object {
    $Existing = Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue
    if ($Existing) {
        Unregister-ScheduledTask -TaskName $_ -Confirm:$false
    }
}

Write-Host ""
Write-Host "Creating daily scheduler task..." -ForegroundColor Yellow

# Action: run the scheduler script (hidden)
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SchedulerScript`"" `
    -WorkingDirectory $PSScriptRoot

# Triggers: at 4 AM daily + at logon
$Triggers = @(
    (New-ScheduledTaskTrigger -Daily -At "04:00"),
    (New-ScheduledTaskTrigger -AtLogOn)
)

# Settings
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

# Principal (run as current user)
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

# Register task
Register-ScheduledTask -TaskName $TaskName `
    -Action $Action `
    -Trigger $Triggers `
    -Settings $Settings `
    -Principal $Principal `
    -Description "Daily scheduler for Appa wallpaper changes at sunrise/sunset (Paris time)" | Out-Null

Write-Host "  Created: $TaskName" -ForegroundColor Green

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "How it works:" -ForegroundColor Cyan
Write-Host "  1. At 4 AM (or login), calculates today's sunrise/sunset for Paris"
Write-Host "  2. Schedules 2 one-time tasks at exact sunrise and sunset times"
Write-Host "  3. Those tasks change wallpaper + lock screen silently"
Write-Host ""
Write-Host "Running initial setup now..." -ForegroundColor Yellow
Write-Host ""

# Run the scheduler now to set up today's tasks
& $SchedulerScript
