$env:JAVA_HOME = "C:\Program Files\Amazon Corretto\jdk17.0.18_9"
$env:Path = $env:JAVA_HOME + "\bin;" + $env:Path
Set-Location D:\music-player
Write-Host "=== Flutter Build APK Release ==="
Write-Host "Java: $(& java -version 2>&1 | Select-Object -First 1)"
& C:\flutter\bin\flutter.bat build apk --release
$code = $LASTEXITCODE
if ($code -eq 0) {
    $apkDir = "D:\music-player\build\app\outputs\flutter-apk"
    $apk = Get-ChildItem $apkDir -Filter "*.apk" -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notlike "*.sha1" } |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($apk) {
        # If Gradle renaming didn't work, rename manually using version.json
        $vj = [System.IO.File]::ReadAllText("D:\music-player\scripts\version.json", [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        $expectedName = "WuAiMusic-$($vj.versionName)-build$($vj.versionCode).apk"
        if ($apk.Name -ne $expectedName) {
            $dest = Join-Path $apkDir $expectedName
            Copy-Item $apk.FullName $dest -Force
            $apk = Get-Item $dest
            Write-Host "(Renamed to $expectedName)"
        }
        Write-Host ""
        Write-Host "=== Build OK ==="
        Write-Host "APK : $($apk.Name)"
        Write-Host "Path: $($apk.FullName)"
        Write-Host "Size: $([math]::Round($apk.Length/1MB,1)) MB"
        Write-Host "Ver : $($vj.versionName) (build $($vj.versionCode))"
    }
} else {
    Write-Host "=== Build Failed (exit $code) ==="
    exit $code
}

