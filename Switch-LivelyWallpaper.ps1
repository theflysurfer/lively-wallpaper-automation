# Switch-LivelyWallpaper.ps1
# Automatically switches Lively wallpapers based on sunrise/sunset in Paris

# Configuration
$DayWallpaper = "C:\Users\julien\OneDrive\Documents\04.Fichiers images et photos\05.Wallpapers\YTDown.com_YouTube_flying-on-appa-avatar-the-last-airbender_Media_E5LrYdPVY4M_001_1080p.mp4"
$NightWallpaper = "C:\Users\julien\OneDrive\Documents\04.Fichiers images et photos\05.Wallpapers\YTDown.com_YouTube_Appa-Night-Ride_Media_qWyPbnAFscY_001_1080p.mp4"

# Try to find Lively.exe (supports both GitHub standalone and Microsoft Store versions)
$LivelyPath = $null
$PossiblePaths = @(
    # GitHub standalone common paths
    "$env:LOCALAPPDATA\Programs\Lively Wallpaper\Lively.exe"
    "C:\Program Files\Lively Wallpaper\Lively.exe"
    "$env:ProgramFiles\Lively Wallpaper\Lively.exe"
    # Legacy/alternative paths
    "$env:LOCALAPPDATA\Lively Wallpaper\Lively.exe"
)

# Method 1: Check if Lively is running to get its path (most reliable)
$LivelyProcess = Get-Process -Name "Lively" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*\Lively.exe" } | Select-Object -First 1
if ($LivelyProcess) {
    $LivelyPath = $LivelyProcess.Path
    Write-Host "Found Lively via running process: $LivelyPath" -ForegroundColor Gray
}

# Method 2: Try known installation paths
if (-not $LivelyPath) {
    foreach ($Path in $PossiblePaths) {
        if (Test-Path $Path) {
            $LivelyPath = $Path
            Write-Host "Found Lively at: $LivelyPath" -ForegroundColor Gray
            break
        }
    }
}

# Method 3: Search in WindowsApps (Microsoft Store version)
if (-not $LivelyPath) {
    $WindowsAppsLively = Get-ChildItem -Path "C:\Program Files\WindowsApps" -Filter "Lively.exe" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like "*LivelyWallpaper*\Build\Lively.exe" } |
        Select-Object -First 1
    if ($WindowsAppsLively) {
        $LivelyPath = $WindowsAppsLively.FullName
        Write-Host "Found Lively (Store version) at: $LivelyPath" -ForegroundColor Gray
    }
}

# Paris coordinates
$Latitude = 48.8566
$Longitude = 2.3522

function Get-SunriseSunset {
    param(
        [double]$Lat,
        [double]$Lon,
        [DateTime]$Date
    )

    # Using sunrise-sunset.org API (free, no key required)
    $DateString = $Date.ToString("yyyy-MM-dd")
    $Url = "https://api.sunrise-sunset.org/json?lat=$Lat&lng=$Lon&date=$DateString&formatted=0"

    try {
        $Response = Invoke-RestMethod -Uri $Url -TimeoutSec 10

        if ($Response.status -eq "OK") {
            $Sunrise = [DateTime]::Parse($Response.results.sunrise)
            $Sunset = [DateTime]::Parse($Response.results.sunset)

            return @{
                Sunrise = $Sunrise
                Sunset = $Sunset
            }
        } else {
            throw "API returned status: $($Response.status)"
        }
    } catch {
        Write-Warning "Failed to get sunrise/sunset data from API: $_"
        return $null
    }
}

# Get Paris time
$ParisTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Romance Standard Time")
$ParisTime = [System.TimeZoneInfo]::ConvertTime([DateTime]::Now, $ParisTimeZone)

Write-Host "Current Paris time: $($ParisTime.ToString('HH:mm:ss'))"

# Get sunrise and sunset times
Write-Host "Fetching sunrise/sunset data for Paris..."
$SunTimes = Get-SunriseSunset -Lat $Latitude -Lon $Longitude -Date $ParisTime

if ($SunTimes) {
    # Convert UTC times to Paris time
    $Sunrise = [System.TimeZoneInfo]::ConvertTime($SunTimes.Sunrise, $ParisTimeZone)
    $Sunset = [System.TimeZoneInfo]::ConvertTime($SunTimes.Sunset, $ParisTimeZone)

    Write-Host "Sunrise: $($Sunrise.ToString('HH:mm:ss'))"
    Write-Host "Sunset:  $($Sunset.ToString('HH:mm:ss'))"

    # Determine which wallpaper to use
    if ($ParisTime -ge $Sunrise -and $ParisTime -lt $Sunset) {
        $SelectedWallpaper = $DayWallpaper
        Write-Host "`nDay time (after sunrise) - switching to Appa flying wallpaper" -ForegroundColor Yellow
    } else {
        $SelectedWallpaper = $NightWallpaper
        Write-Host "`nNight time (after sunset) - switching to Appa night ride wallpaper" -ForegroundColor Blue
    }
} else {
    # Fallback to fixed times if API fails
    Write-Warning "Using fallback fixed times (7h-19h)"
    $CurrentHour = $ParisTime.Hour
    if ($CurrentHour -ge 7 -and $CurrentHour -lt 19) {
        $SelectedWallpaper = $DayWallpaper
        Write-Host "Day time (fallback) - switching to Appa flying wallpaper"
    } else {
        $SelectedWallpaper = $NightWallpaper
        Write-Host "Night time (fallback) - switching to Appa night ride wallpaper"
    }
}

# Check if Lively is installed
if (-not (Test-Path $LivelyPath)) {
    Write-Error "Lively Wallpaper not found at: $LivelyPath"
    Write-Host "Please ensure Lively Wallpaper is installed."
    exit 1
}

# Check if wallpaper file exists
if (-not (Test-Path $SelectedWallpaper)) {
    Write-Error "Wallpaper file not found: $SelectedWallpaper"
    exit 1
}

# Set the wallpaper using Lively CLI
Write-Host "`nSetting wallpaper..."
& $LivelyPath --setWallpaper "$SelectedWallpaper"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Wallpaper changed successfully!" -ForegroundColor Green
} else {
    Write-Warning "Lively command completed with exit code: $LASTEXITCODE"
}
