param(
    [ValidateSet("debug", "release")]
    [string]$Variant = "release",
    [switch]$SkipBump,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
Push-Location $projectRoot

function Write-Step($msg) {
    Write-Host ""
    Write-Host "=== $msg ===" -ForegroundColor Cyan
}

try {
    Write-Host ""
    Write-Host "=== WuAiMusic Build Script ===" -ForegroundColor Green

    # Step 1: Bump version
    if (-not $SkipBump) {
        Write-Step "Step 1: Bump Version"
        & "$scriptDir\bump_version.ps1"
        if ($LASTEXITCODE -ne 0) { throw "bump_version.ps1 failed" }
    } else {
        Write-Step "Step 1: Skip Version Bump"
    }

    # Step 2: Clean (optional)
    if ($Clean) {
        Write-Step "Step 2: Clean Build Cache"
        Write-Host "  Killing java processes..."
        Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Milliseconds 500
        Write-Host "  Removing build/..."
        Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue
        Write-Host "  Removing android/.gradle/..."
        Remove-Item -Recurse -Force "android\.gradle" -ErrorAction SilentlyContinue
        Write-Host "  Removing android/build/..."
        Remove-Item -Recurse -Force "android\build" -ErrorAction SilentlyContinue
        Write-Host "[OK] Clean complete"
    }

    # Step 3: Build APK
    Write-Step "Step 3: Build APK ($Variant)"

    $env:JAVA_HOME = "C:\Program Files\Amazon Corretto\jdk17.0.18_9"
    $env:Path = "$($env:JAVA_HOME)\bin;$env:Path"
    Write-Host "  JAVA_HOME: $env:JAVA_HOME"

    $flutterArgs = @("build", "apk", "--$Variant")
    & "C:\flutter\bin\flutter.bat" $flutterArgs 2>&1

    if ($LASTEXITCODE -ne 0) { throw "flutter build failed (exit $LASTEXITCODE)" }

    # Step 4: Report APK and rename if needed
    $apkDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
    $apk = Get-ChildItem $apkDir -Filter "*.apk" -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notlike "*.sha1" } |
           Sort-Object LastWriteTime -Descending |
           Select-Object -First 1

    Write-Step "Step 4: Build Complete"
    if ($apk) {
        $vj = [System.IO.File]::ReadAllText("$scriptDir\version.json", [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        $expectedName = "WuAiMusic-$($vj.versionName)-build$($vj.versionCode).apk"
        if ($apk.Name -ne $expectedName) {
            $dest = Join-Path $apkDir $expectedName
            Copy-Item $apk.FullName $dest -Force
            $apk = Get-Item $dest
            Write-Host "  Renamed to: $expectedName"
        }
        Write-Host ""
        Write-Host "  APK : $($apk.Name)" -ForegroundColor Yellow
        Write-Host "  Path: $($apk.FullName)" -ForegroundColor Gray
        Write-Host "  Size: $([math]::Round($apk.Length/1MB, 1)) MB" -ForegroundColor Gray
        Write-Host "  Ver : $($vj.versionName) (build $($vj.versionCode))" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "=== Build Successful! ===" -ForegroundColor Green
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "=== Build Failed! ===" -ForegroundColor Red
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
