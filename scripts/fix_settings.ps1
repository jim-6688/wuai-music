$path = "C:\Users\Administrator\.qclaw\workspace\music-player\lib\features\settings\presentation\pages\settings_page.dart"
$content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
$content = $content -replace "'1\.2\.0'", "'1.3.1'"
$content = $content -replace "applicationVersion:\s*'1\.2\.0'", "applicationVersion: '1.3.1'"
[System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
Write-Host "done"
