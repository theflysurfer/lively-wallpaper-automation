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

function Restart-ExplorerIfNeeded {
    # Check Lively logs for WorkerW error
    $LogFolder = "$env:LOCALAPPDATA\Lively Wallpaper\logs"
    $LatestLog = Get-ChildItem $LogFolder -Filter "*.txt" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($LatestLog) {
        $RecentContent = Get-Content $LatestLog.FullName -Tail 20 -ErrorAction SilentlyContinue
        if ($RecentContent -match "Failed to set wallpaper as child of WorkerW") {
            Write-Host "  Detected WorkerW error, restarting Explorer..." -ForegroundColor Yellow
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep 3
            Start-Process explorer
            Start-Sleep 2
            return $true
        }
    }
    return $false
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
        Start-Sleep 2

        # Check if it failed and retry after Explorer restart
        if (Restart-ExplorerIfNeeded) {
            $null = & $LivelyExe setwp --file "$WallpaperPath" 2>&1
        }
        return $true
    } catch {
        Write-Warning "Lively error: $_"
        return $false
    }
}

function Set-LockScreenImage {
    param([string]$ImagePath)

    if (-not (Test-Path $ImagePath)) {
        Write-Warning "Lock screen image not found: $ImagePath"
        return $false
    }

    try {
        # Use Windows Runtime API (works on Windows 10/11)
        [Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime] | Out-Null
        [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
        Add-Type -AssemblyName System.Runtime.WindowsRuntime

        $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
            Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

        Function Await($WinRtTask, $ResultType) {
            $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
            $netTask = $asTask.Invoke($null, @($WinRtTask))
            $netTask.Wait(-1) | Out-Null
            $netTask.Result
        }

        Function AwaitAction($WinRtAction) {
            $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
                Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and !$_.IsGenericMethod })[0]
            $netTask = $asTask.Invoke($null, @($WinRtAction))
            $netTask.Wait(-1) | Out-Null
        }

        # Get StorageFile from path
        $StorageFile = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($ImagePath)) ([Windows.Storage.StorageFile])

        # Set as lock screen
        AwaitAction ([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($StorageFile))

        return $true
    } catch {
        Write-Warning "Lock screen error: $_"
        return $false
    }
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
        Write-Host "  Lock screen: FAILED" -ForegroundColor Red
    }
}
