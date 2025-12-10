# Schedule-DailyTasks.ps1
# Runs once daily (at startup or 4 AM) to schedule wallpaper changes at exact sunrise/sunset times

# Paris coordinates
$Latitude = 48.8566
$Longitude = 2.3522

$ScriptFolder = $PSScriptRoot
$SwitchScript = Join-Path $ScriptFolder "Switch-Wallpapers.ps1"

function Get-SunriseSunset {
    param([double]$Lat, [double]$Lon, [DateTime]$Date)

    $DateString = $Date.ToString("yyyy-MM-dd")
    $Url = "https://api.sunrise-sunset.org/json?lat=$Lat&lng=$Lon&date=$DateString&formatted=0"

    try {
        $Response = Invoke-RestMethod -Uri $Url -TimeoutSec 10
        if ($Response.status -eq "OK") {
            return @{
                Sunrise = [DateTime]::Parse($Response.results.sunrise)
                Sunset = [DateTime]::Parse($Response.results.sunset)
            }
        }
    } catch {
        Write-Warning "API error: $_"
    }
    return $null
}

function Register-OneTimeTask {
    param(
        [string]$TaskName,
        [DateTime]$TriggerTime,
        [string]$Period  # "Day" or "Night"
    )

    # Remove existing task if any
    $Existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($Existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    # Don't schedule if time has passed
    if ($TriggerTime -lt (Get-Date)) {
        Write-Host "  $TaskName : skipped (time passed)" -ForegroundColor Gray
        return
    }

    # Create action - run Switch-Wallpapers.ps1 with -Period parameter
    $Action = New-ScheduledTaskAction -Execute "wscript.exe" `
        -Argument "`"$ScriptFolder\Run-Hidden.vbs`" $Period" `
        -WorkingDirectory $ScriptFolder

    # Create one-time trigger
    $Trigger = New-ScheduledTaskTrigger -Once -At $TriggerTime

    # Settings
    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
        -DeleteExpiredTaskAfter (New-TimeSpan -Hours 1)

    # Principal
    $Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

    # Register
    Register-ScheduledTask -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Settings $Settings `
        -Principal $Principal `
        -Description "One-time wallpaper switch for $Period" | Out-Null

    Write-Host "  $TaskName : $($TriggerTime.ToString('HH:mm'))" -ForegroundColor Green
}

# Get Paris time
$ParisTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Romance Standard Time")
$ParisNow = [System.TimeZoneInfo]::ConvertTime([DateTime]::Now, $ParisTimeZone)

Write-Host "=== Scheduling Wallpaper Changes ===" -ForegroundColor Cyan
Write-Host "Paris time: $($ParisNow.ToString('HH:mm:ss'))"
Write-Host ""

# Get sunrise/sunset for today
$SunTimes = Get-SunriseSunset -Lat $Latitude -Lon $Longitude -Date $ParisNow

if (-not $SunTimes) {
    Write-Warning "Could not get sunrise/sunset times. Using fallback (7h/19h)."
    $Sunrise = $ParisNow.Date.AddHours(7)
    $Sunset = $ParisNow.Date.AddHours(19)
} else {
    $Sunrise = [System.TimeZoneInfo]::ConvertTime($SunTimes.Sunrise, $ParisTimeZone)
    $Sunset = [System.TimeZoneInfo]::ConvertTime($SunTimes.Sunset, $ParisTimeZone)
}

Write-Host "Sunrise: $($Sunrise.ToString('HH:mm'))" -ForegroundColor Yellow
Write-Host "Sunset:  $($Sunset.ToString('HH:mm'))" -ForegroundColor Blue
Write-Host ""

# Determine current period and set wallpaper now
$IsDay = ($ParisNow -ge $Sunrise -and $ParisNow -lt $Sunset)
$CurrentPeriod = if ($IsDay) { "Day" } else { "Night" }

Write-Host "Current period: $CurrentPeriod"
Write-Host "Setting wallpaper now..."

# Run the switch script immediately with current period
& $SwitchScript -Period $CurrentPeriod

Write-Host ""
Write-Host "Scheduling today's changes:" -ForegroundColor Cyan

# Schedule sunrise task (switch to Day)
Register-OneTimeTask -TaskName "AppaWallpaper_Sunrise" -TriggerTime $Sunrise -Period "Day"

# Schedule sunset task (switch to Night)
Register-OneTimeTask -TaskName "AppaWallpaper_Sunset" -TriggerTime $Sunset -Period "Night"

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
