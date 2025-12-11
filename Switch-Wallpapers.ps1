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
$LockScreenDayGif = "$ScriptFolder\assets\lockscreen\appa-day.gif"
$LockScreenNightGif = "$ScriptFolder\assets\lockscreen\appa-night.gif"

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

    # Get current user SID
    $UserSID = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value

    # Paths (matching LockscreenGif exactly)
    $PermanentFolder = "$env:USERPROFILE\Pictures\LockscreenGif"
    $PermanentPath = "$PermanentFolder\wallpaper.jpg"  # LockscreenGif uses .jpg extension
    $SystemCachePath = "C:\ProgramData\Microsoft\Windows\SystemData\$UserSID\ReadOnly"

    try {
        # Create permanent folder
        if (-not (Test-Path $PermanentFolder)) {
            New-Item -ItemType Directory -Path $PermanentFolder -Force | Out-Null
        }

        # Copy GIF to permanent location (as wallpaper.jpg like LockscreenGif)
        Copy-Item -Path $GifPath -Destination $PermanentPath -Force

        # Set registry (PersonalizationCSP) - requires admin
        $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        if (-not (Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }
        Set-ItemProperty -Path $RegPath -Name "LockScreenImagePath" -Value $PermanentPath -Type String -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $RegPath -Name "LockScreenImageUrl" -Value $PermanentPath -Type String -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $RegPath -Name "LockScreenImageStatus" -Value 1 -Type DWord -ErrorAction SilentlyContinue

        # Take ownership of entire ReadOnly folder first (like LockscreenGif does)
        if (Test-Path $SystemCachePath) {
            & takeown /f "$SystemCachePath" /r /a 2>$null | Out-Null
            & icacls "$SystemCachePath" /grant "*S-1-1-0:(F)" /T /C 2>$null | Out-Null

            # Get screen resolution in LockscreenGif format (0000_0000)
            Add-Type -AssemblyName System.Windows.Forms
            $screen = [System.Windows.Forms.Screen]::PrimaryScreen
            $resolution = "{0:0000}_{1:0000}" -f $screen.Bounds.Width, $screen.Bounds.Height

            # Copy to SUBFOLDERS only (LockscreenGif uses Directory.EnumerateDirectories)
            $subfolders = Get-ChildItem $SystemCachePath -Directory -ErrorAction SilentlyContinue

            foreach ($folder in $subfolders) {
                $folderPath = $folder.FullName

                # Copy main LockScreen.jpg
                $mainFile = "$folderPath\LockScreen.jpg"
                Copy-Item -Path $GifPath -Destination $mainFile -Force -ErrorAction SilentlyContinue

                # Copy resolution-specific file with correct format
                $resFile = "$folderPath\LockScreen___${resolution}_notdimmed.jpg"
                Copy-Item -Path $GifPath -Destination $resFile -Force -ErrorAction SilentlyContinue
            }
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
