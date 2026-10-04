$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "cmd.exe"
$psi.Arguments = '/c C:\src\flutter\bin\flutter.bat doctor --android-licenses'
$psi.EnvironmentVariables["JAVA_HOME"] = "C:\tools\jdk17"
$psi.EnvironmentVariables["ANDROID_HOME"] = "C:\Android\sdk"
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.UseShellExecute = $false

$p = [System.Diagnostics.Process]::Start($psi)

$sw = $p.StandardInput
$sr = $p.StandardOutput

while (-not $p.HasExited) {
    $line = $sr.ReadLine()
    if ($line) {
        Write-Host $line
        if ($line.Contains("?")) {
            $sw.WriteLine("y")
            $sw.Flush()
        }
    }
}
$p.WaitForExit()
Write-Host "Termine avec code:" $p.ExitCode

# Flutter doctor
& "C:\src\flutter\bin\flutter.bat" doctor
