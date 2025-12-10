# Switch-Wallpapers.ps1
# Switches Lively wallpaper and Windows lock screen based on Paris sunrise/sunset

param(
    [switch]$LivelyOnly,
    [switch]$LockScreenOnly
)

# Configuration
$LivelyDayWallpaper = "$env:LOCALAPPDATA\Lively Wallpaper\Library\wallpapers\appa-day"
$LivelyNightWallpaper = "$env:LOCALAPPDATA\Lively Wallpaper\Library\wallpapers\appa-night"
$LockScreenDayImage = "$env:USERPROFILE\Pictures\Appa Lockscreen\appa-day-lockscreen.jpg"
$LockScreenNightImage = "$env:USERPROFILE\Pictures\Appa Lockscreen\appa-night-lockscreen.jpg"

# Paris coordinates
$Latitude = 48.8566
$Longitude = 2.3522

# Check admin status for lock screen
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

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

function Find-LivelyExe {
    $Paths = @(
        "$env:LOCALAPPDATA\Programs\Lively Wallpaper\Lively.exe"
        "C:\Program Files\Lively Wallpaper\Lively.exe"
        "$env:ProgramFiles\Lively Wallpaper\Lively.exe"
    )

    # Check running process first
    $Process = Get-Process -Name "Lively" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "*\Lively.exe" } |
        Select-Object -First 1
    if ($Process) { return $Process.Path }

    # Check known paths
    foreach ($Path in $Paths) {
        if (Test-Path $Path) { return $Path }
    }

    return $null
}

function Set-LivelyWallpaper {
    param([string]$WallpaperPath)

    $LivelyExe = Find-LivelyExe
    if (-not $LivelyExe) {
        Write-Warning "Lively not found"
        return $false
    }

    if (-not (Test-Path $WallpaperPath)) {
        Write-Warning "Wallpaper not found: $WallpaperPath"
        return $false
    }

    try {
        $null = & $LivelyExe setwp --file "$WallpaperPath" 2>&1
        return $true
    } catch {
        Write-Warning "Lively error: $_"
        return $false
    }
}

function Set-LockScreenImage {
    param([string]$ImagePath)

    if (-not $isAdmin) {
        Write-Warning "Lock screen requires admin privileges"
        return $false
    }

    if (-not (Test-Path $ImagePath)) {
        Write-Warning "Lock screen image not found: $ImagePath"
        return $false
    }

    $Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
    if (-not (Test-Path $Key)) {
        New-Item -Path $Key -Force | Out-Null
    }

    Set-ItemProperty -Path $Key -Name "LockScreenImage" -Value $ImagePath -Type String
    Set-ItemProperty -Path $Key -Name "NoLockScreen" -Value 0 -Type DWord
    return $true
}

# Get Paris time
$ParisTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Romance Standard Time")
$ParisTime = [System.TimeZoneInfo]::ConvertTime([DateTime]::Now, $ParisTimeZone)

Write-Host "Paris time: $($ParisTime.ToString('HH:mm:ss'))"

# Get sunrise/sunset
$SunTimes = Get-SunriseSunset -Lat $Latitude -Lon $Longitude -Date $ParisTime

if ($SunTimes) {
    $Sunrise = [System.TimeZoneInfo]::ConvertTime($SunTimes.Sunrise, $ParisTimeZone)
    $Sunset = [System.TimeZoneInfo]::ConvertTime($SunTimes.Sunset, $ParisTimeZone)
    Write-Host "Sunrise: $($Sunrise.ToString('HH:mm')) | Sunset: $($Sunset.ToString('HH:mm'))"
    $IsDay = ($ParisTime -ge $Sunrise -and $ParisTime -lt $Sunset)
} else {
    Write-Warning "Using fallback times (7h-19h)"
    $IsDay = ($ParisTime.Hour -ge 7 -and $ParisTime.Hour -lt 19)
}

$Period = if ($IsDay) { "Day" } else { "Night" }
Write-Host "Period: $Period" -ForegroundColor $(if ($IsDay) { "Yellow" } else { "Blue" })

# Set wallpapers
$LivelyWallpaper = if ($IsDay) { $LivelyDayWallpaper } else { $LivelyNightWallpaper }
$LockScreenImage = if ($IsDay) { $LockScreenDayImage } else { $LockScreenNightImage }

if (-not $LockScreenOnly) {
    Write-Host "Setting Lively wallpaper..."
    if (Set-LivelyWallpaper -WallpaperPath $LivelyWallpaper) {
        Write-Host "  Lively: OK" -ForegroundColor Green
    } else {
        Write-Host "  Lively: FAILED" -ForegroundColor Red
    }
}

if (-not $LivelyOnly) {
    Write-Host "Setting lock screen..."
    if (Set-LockScreenImage -ImagePath $LockScreenImage) {
        Write-Host "  Lock screen: OK" -ForegroundColor Green
    } else {
        Write-Host "  Lock screen: SKIPPED (no admin)" -ForegroundColor Yellow
    }
}
