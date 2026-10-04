$env:JAVA_HOME = "C:\tools\jdk17"
$env:ANDROID_HOME = "C:\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Android\sdk"
$env:Path = "C:\tools\git\cmd;C:\tools\jdk17\bin;C:\Android\sdk\platform-tools;C:\Android\sdk\cmdline-tools\latest\bin;C:\src\flutter\bin;" + [Environment]::GetEnvironmentVariable("Path", "Machine")

# Tell Flutter explicitly where JDK is
& "C:\src\flutter\bin\flutter.bat" config --jdk-dir "C:\tools\jdk17"
& "C:\src\flutter\bin\flutter.bat" config --android-sdk "C:\Android\sdk"

# Accept all licenses via sdkmanager with JAVA_HOME explicitly present
$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = "cmd.exe"
$processInfo.Arguments = '/c "echo y|echo y|echo y|echo y|echo y|echo y|echo y|echo y|echo y|echo y| C:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat --licenses"'
$processInfo.EnvironmentVariables["JAVA_HOME"] = "C:\tools\jdk17"
$processInfo.EnvironmentVariables["ANDROID_HOME"] = "C:\Android\sdk"
$processInfo.UseShellExecute = $false
$processInfo.RedirectStandardInput = $true
$processInfo.RedirectStandardOutput = $true
$process = [System.Diagnostics.Process]::Start($processInfo)
$output = $process.StandardOutput.ReadToEnd()
$process.WaitForExit()
Write-Host $output

# Verify Flutter Doctor
& "C:\src\flutter\bin\flutter.bat" doctor
