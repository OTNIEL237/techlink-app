$path = "C:\src\flutter\bin\internal\shared.bat"
$raw = [System.IO.File]::ReadAllText($path)
$target = 'SET compilekey="%revision%:%FLUTTER_TOOL_ARGS%"'
$replacement = @"
IF "%revision%"=="" SET revision=c7de6a6a80c950cc9fcbeef3d030c93ca089f4f7
  SET compilekey="%revision%:%FLUTTER_TOOL_ARGS%"
"@
if ($raw.Contains($target)) {
    $raw = $raw.Replace($target, $replacement)
    [System.IO.File]::WriteAllText($path, $raw)
    Write-Host "shared.bat patched!"
} else {
    Write-Host "Already patched or target not found"
}
(Get-Item "C:\src\flutter\packages\flutter_tools\pubspec.lock").LastWriteTime = (Get-Date).AddDays(2)
Remove-Item -Force -ErrorAction SilentlyContinue "C:\src\flutter\bin\cache\*.lock"
