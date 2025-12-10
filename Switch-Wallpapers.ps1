# Switch-Wallpapers.ps1
# Switches Lively wallpaper and Windows lock screen to Day or Night mode

param(
    [ValidateSet("Day", "Night")]
    [string]$Period,
    [switch]$LivelyOnly,
    [switch]$LockScreenOnly
)

# Configuration
$LivelyDayWallpaper = "$env:LOCALAPPDATA\Lively Wallpaper\Library\wallpapers\appa-day"
$LivelyNightWallpaper = "$env:LOCALAPPDATA\Lively Wallpaper\Library\wallpapers\appa-night"
$LockScreenDayImage = "$env:USERPROFILE\Pictures\Appa Lockscreen\appa-day-lockscreen.jpg"
$LockScreenNightImage = "$env:USERPROFILE\Pictures\Appa Lockscreen\appa-night-lockscreen.jpg"

function Find-LivelyExe {
    $Paths = @(
        "$env:LOCALAPPDATA\Programs\Lively Wallpaper\Lively.exe"
        "C:\Program Files\Lively Wallpaper\Lively.exe"
        "$env:ProgramFiles\Lively Wallpaper\Lively.exe"
    )

    $Process = Get-Process -Name "Lively" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "*\Lively.exe" } |
        Select-Object -First 1
    if ($Process) { return $Process.Path }

    foreach ($Path in $Paths) {
        if (Test-Path $Path) { return $Path }
    }
    return $null
}

function Restart-ExplorerIfNeeded {
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

        $StorageFile = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($ImagePath)) ([Windows.Storage.StorageFile])
        AwaitAction ([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($StorageFile))

        return $true
    } catch {
        Write-Warning "Lock screen error: $_"
        return $false
    }
}

# If no period specified, calculate from sunrise/sunset
if (-not $Period) {
    $Latitude = 48.8566
    $Longitude = 2.3522
    $ParisTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Romance Standard Time")
    $ParisTime = [System.TimeZoneInfo]::ConvertTime([DateTime]::Now, $ParisTimeZone)

    try {
        $DateString = $ParisTime.ToString("yyyy-MM-dd")
        $Url = "https://api.sunrise-sunset.org/json?lat=$Latitude&lng=$Longitude&date=$DateString&formatted=0"
        $Response = Invoke-RestMethod -Uri $Url -TimeoutSec 10

        if ($Response.status -eq "OK") {
            $Sunrise = [System.TimeZoneInfo]::ConvertTime([DateTime]::Parse($Response.results.sunrise), $ParisTimeZone)
            $Sunset = [System.TimeZoneInfo]::ConvertTime([DateTime]::Parse($Response.results.sunset), $ParisTimeZone)
            $Period = if ($ParisTime -ge $Sunrise -and $ParisTime -lt $Sunset) { "Day" } else { "Night" }
        } else {
            $Period = if ($ParisTime.Hour -ge 7 -and $ParisTime.Hour -lt 19) { "Day" } else { "Night" }
        }
    } catch {
        $Period = if ($ParisTime.Hour -ge 7 -and $ParisTime.Hour -lt 19) { "Day" } else { "Night" }
    }
}

Write-Host "Period: $Period" -ForegroundColor $(if ($Period -eq "Day") { "Yellow" } else { "Blue" })

# Select wallpapers based on period
$LivelyWallpaper = if ($Period -eq "Day") { $LivelyDayWallpaper } else { $LivelyNightWallpaper }
$LockScreenImage = if ($Period -eq "Day") { $LockScreenDayImage } else { $LockScreenNightImage }

# Apply wallpapers
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
