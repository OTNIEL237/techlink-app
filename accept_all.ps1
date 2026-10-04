$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "cmd.exe"
$psi.Arguments = '/c "C:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat --licenses"'
$psi.EnvironmentVariables["JAVA_HOME"] = "C:\tools\jdk17"
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.UseShellExecute = $false

$p = [System.Diagnostics.Process]::Start($psi)

# Read output asynchronously and write 'y' on every prompt
$reader = [System.IO.StreamReader]$p.StandardOutput
$writer = [System.IO.StreamWriter]$p.StandardInput

while (-not $p.HasExited) {
    Start-Sleep -Milliseconds 500
    try {
        $writer.WriteLine("y")
        $writer.Flush()
    } catch {}
}

$p.WaitForExit()
Write-Host "ExitCode:" $p.ExitCode

# Check with flutter doctor
& "C:\src\flutter\bin\flutter.bat" doctor
