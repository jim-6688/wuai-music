param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir    = Split-Path -Parent $scriptDir

$pubspecPath     = Join-Path $rootDir "pubspec.yaml"
$versionJsonPath = Join-Path $scriptDir "version.json"
$gradlePath      = Join-Path $rootDir "android\app\build.gradle.kts"
$vpPath          = Join-Path $rootDir "android\version.properties"
$settingsPath    = Join-Path $rootDir "lib\features\settings\presentation\pages\settings_page.dart"

Push-Location $rootDir

try {
    Write-Host ""
    Write-Host "=== Bump Version ===" -ForegroundColor Cyan

    # Read current version from pubspec.yaml (single source of truth)
    if (-not (Test-Path $pubspecPath)) { throw "pubspec.yaml not found: $pubspecPath" }
    $yamlContent = [System.IO.File]::ReadAllText($pubspecPath, [System.Text.Encoding]::UTF8)
    $m = [regex]::Match($yamlContent, 'version:\s*([\d.]+)\+(\d+)')
    if (-not $m.Success) { throw "version field not found in pubspec.yaml" }
    $curName = $m.Groups[1].Value
    $curCode = [int]$m.Groups[2].Value

    # Parse and increment
    $parts = $curName -split '\.'
    $major = [int]$parts[0]; $minor = [int]$parts[1]; $patch = [int]$parts[2]
    Write-Host "Current: $major.$minor.$patch+$curCode"

    $patch++
    if ($patch -gt 9) { $patch = 0; $minor++ }
    if ($minor -gt 9) { $minor = 0; $major++ }

    $newName = "$major.$minor.$patch"
    $newCode = $curCode + 1
    Write-Host "New:     $newName+$newCode" -ForegroundColor Green

    if ($DryRun) {
        Write-Host "[DryRun] No files written" -ForegroundColor Yellow
        return
    }

    # 1. pubspec.yaml
    $yamlNew = $yamlContent -replace 'version:\s*[\d.]+\+\d+', "version: $newName+$newCode"
    [System.IO.File]::WriteAllText($pubspecPath, $yamlNew, [System.Text.Encoding]::UTF8)
    Write-Host "  pubspec.yaml        -> $newName+$newCode"

    # 2. scripts/version.json
    $newJson = '{"versionName":"' + $newName + '","versionCode":' + $newCode + '}'
    [System.IO.File]::WriteAllText($versionJsonPath, $newJson, [System.Text.Encoding]::UTF8)
    Write-Host "  scripts/version.json -> $newName+$newCode"

    # 3. android/app/build.gradle.kts  (update fallback values only)
    if (Test-Path $gradlePath) {
        $gc = [System.IO.File]::ReadAllText($gradlePath, [System.Text.Encoding]::UTF8)
        $gc = $gc -replace '"versionName" to "[^"]+"', ('"versionName" to "' + $newName + '"')
        $gc = $gc -replace '"versionCode" to \d+', ('"versionCode" to ' + $newCode)
        [System.IO.File]::WriteAllText($gradlePath, $gc, [System.Text.Encoding]::UTF8)
        Write-Host "  build.gradle.kts    -> fallback $newName+$newCode"
    } else {
        Write-Host "  [WARN] build.gradle.kts not found" -ForegroundColor Yellow
    }

    # 4. android/version.properties
    $vpContent = "# Auto-generated - do not edit manually`r`nVERSION_NAME=$newName`r`nVERSION_CODE=$newCode"
    [System.IO.File]::WriteAllText($vpPath, $vpContent, [System.Text.Encoding]::UTF8)
    Write-Host "  version.properties  -> $newName+$newCode"

    # 5. settings_page.dart
    if (Test-Path $settingsPath) {
        $sc = [System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8)
        $sc = $sc -replace "'[\d]+\.[\d]+\.[\d]+'", "'$newName'"
        $sc = $sc -replace "applicationVersion:\s*'[^']+'", "applicationVersion: '$newName'"
        [System.IO.File]::WriteAllText($settingsPath, $sc, [System.Text.Encoding]::UTF8)
        Write-Host "  settings_page.dart  -> $newName"
    }

    Write-Host ""
    Write-Host "=== Done: $newName+$newCode ===" -ForegroundColor Cyan
    Write-Host ""
    exit 0

} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
