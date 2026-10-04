$env:JAVA_HOME = "C:\tools\jdk17"
$env:ANDROID_HOME = "C:\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Android\sdk"
$env:Path = "C:\tools\git\cmd;C:\tools\jdk17\bin;C:\Android\sdk\platform-tools;C:\Android\sdk\cmdline-tools\latest\bin;C:\src\flutter\bin;" + [Environment]::GetEnvironmentVariable("Path", "Machine")

Write-Host "Acceptation des licences..."
"y`ny`ny`ny`ny`ny`ny`ny`ny`ny`ny`ny`ny`n" | & "C:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat" --licenses

Write-Host "Vérification Flutter Doctor..."
& "C:\src\flutter\bin\flutter.bat" doctor -v
