# Install-LivelyScheduledTask.ps1
# Creates a Windows scheduled task to switch Lively wallpapers based on sunrise/sunset

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait
    exit
}

$ScriptPath = "$PSScriptRoot\Switch-LivelyWallpaper.ps1"
$TaskName = "LivelyWallpaperSunriseSunset"

# Check if script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found: $ScriptPath"
    exit 1
}

# Remove existing task if it exists
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    Write-Host "Removing existing task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Also remove old task name if exists
$OldTaskName = "LivelyWallpaperDayNightSwitch"
$OldTask = Get-ScheduledTask -TaskName $OldTaskName -ErrorAction SilentlyContinue
if ($OldTask) {
    Write-Host "Removing old task..."
    Unregister-ScheduledTask -TaskName $OldTaskName -Confirm:$false
}

# Create action
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""

# Create triggers - check every hour to adapt to sunrise/sunset changes
$Triggers = @()

# Every hour from 5 AM to 10 PM (covers all possible sunrise/sunset times in Paris)
for ($hour = 5; $hour -le 22; $hour++) {
    $TimeString = "{0:D2}:00" -f $hour
    $Triggers += New-ScheduledTaskTrigger -Daily -At $TimeString
}

# At user logon (to set correct wallpaper on startup)
$Triggers += New-ScheduledTaskTrigger -AtLogOn

# Create settings
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

# Create principal (run as current user)
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

# Register task
Write-Host "Creating scheduled task: $TaskName"
Register-ScheduledTask -TaskName $TaskName `
    -Action $Action `
    -Trigger $Triggers `
    -Settings $Settings `
    -Principal $Principal `
    -Description "Automatically switches Lively wallpaper based on real sunrise/sunset times in Paris using API"

Write-Host "`nScheduled task created successfully!" -ForegroundColor Green
Write-Host "`nThe wallpaper will:"
Write-Host "  - Switch based on REAL sunrise/sunset times for Paris"
Write-Host "  - Check every hour (5h-22h) to adapt to daily changes"
Write-Host "  - Update at logon to set the appropriate wallpaper"
Write-Host "  - Use sunrise-sunset.org API (free, no key required)"
Write-Host "  - Fallback to 7h-19h if API is unavailable"
Write-Host "`nTest it now: .\Switch-LivelyWallpaper.ps1"
