$env:JAVA_HOME = "C:\tools\jdk17"
$env:ANDROID_HOME = "C:\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Android\sdk"
$env:Path = "C:\tools\git\cmd;C:\tools\jdk17\bin;C:\Android\sdk\platform-tools;C:\src\flutter\bin;" + [Environment]::GetEnvironmentVariable("Path", "Machine")

Write-Host "--- Test ADB Devices ---"
& "C:\Android\sdk\platform-tools\adb.exe" devices -l

Write-Host "--- Flutter Doctor ---"
& "C:\src\flutter\bin\flutter.bat" doctor -v
