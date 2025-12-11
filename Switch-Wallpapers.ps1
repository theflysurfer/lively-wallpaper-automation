# Switch-Wallpapers.ps1
# Switches Lively wallpaper and Windows lock screen to Day or Night mode

param(
    [ValidateSet("Day", "Night")]
    [string]$Period,
    [switch]$LivelyOnly,
    [switch]$LockScreenOnly
)

# Configuration
$ScriptFolder = $PSScriptRoot
$LivelyDayWallpaper = "$env:LOCALAPPDATA\Lively Wallpaper\Library\wallpapers\appa-day"
$LivelyNightWallpaper = "$env:LOCALAPPDATA\Lively Wallpaper\Library\wallpapers\appa-night"
# GIF lock screen files (both small and large work, using large for better quality)
$LockScreenDayGif = "$ScriptFolder\assets\lockscreen-gif\appa-day.gif"
$LockScreenNightGif = "$ScriptFolder\assets\lockscreen-gif\appa-night.gif"
# LockscreenGif.exe path (bundled with project)
$LockscreenGifExe = "$ScriptFolder\LockscreenGif\LockscreenGif.exe"

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

function Set-GifLockScreen {
    param([string]$GifPath)

    if (-not (Test-Path $GifPath)) {
        Write-Warning "GIF not found: $GifPath"
        return $false
    }

    # LockscreenGif reads from Pictures\LockscreenGif\wallpaper.gif
    $LockscreenGifFolder = "$env:USERPROFILE\Pictures\LockscreenGif"
    $WallpaperPath = "$LockscreenGifFolder\wallpaper.gif"

    try {
        # Create folder if needed
        if (-not (Test-Path $LockscreenGifFolder)) {
            New-Item -ItemType Directory -Path $LockscreenGifFolder -Force | Out-Null
        }

        # Copy GIF to the location LockscreenGif expects
        Copy-Item -Path $GifPath -Destination $WallpaperPath -Force
        Write-Host "  Copied GIF to: $WallpaperPath"

        # Run LockscreenGif.exe to apply it (requires admin)
        if (Test-Path $LockscreenGifExe) {
            # LockscreenGif runs and applies the wallpaper.gif automatically
            $process = Start-Process -FilePath $LockscreenGifExe -PassThru -WindowStyle Hidden
            Start-Sleep -Seconds 3

            # Kill the process after it has applied the lockscreen
            if (-not $process.HasExited) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
            Write-Host "  LockscreenGif applied"
        } else {
            Write-Warning "LockscreenGif.exe not found at: $LockscreenGifExe"
            Write-Warning "Please run LockscreenGif manually to apply the GIF"
            return $false
        }

        return $true
    } catch {
        Write-Warning "GIF lock screen error: $_"
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
$LockScreenGif = if ($Period -eq "Day") { $LockScreenDayGif } else { $LockScreenNightGif }

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
    Write-Host "Setting GIF lock screen..."
    if (Set-GifLockScreen -GifPath $LockScreenGif) {
        Write-Host "  Lock screen: OK" -ForegroundColor Green
    } else {
        Write-Host "  Lock screen: FAILED" -ForegroundColor Red
    }
}
