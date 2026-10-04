# Install Android SDK Command-line Tools
$env:JAVA_HOME = "C:\tools\jdk17"
$env:ANDROID_HOME = "C:\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Android\sdk"
$env:Path = "C:\tools\git\cmd;C:\tools\jdk17\bin;C:\Android\sdk\platform-tools;C:\Android\sdk\cmdline-tools\latest\bin;C:\src\flutter\bin;" + [Environment]::GetEnvironmentVariable("Path", "Machine")

Write-Host "Téléchargement de Android Command-Line Tools (~140 Mo)..."
curl.exe -L -o "$env:TEMP\cmdline-tools.zip" 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip'

Write-Host "Extraction..."
New-Item -ItemType Directory -Force -Path "C:\Android\sdk\cmdline-tools" | Out-Null
tar.exe -xf "$env:TEMP\cmdline-tools.zip" -C "$env:TEMP"
Remove-Item -Force "$env:TEMP\cmdline-tools.zip"

if (Test-Path "C:\Android\sdk\cmdline-tools\latest") {
    Remove-Item -Recurse -Force "C:\Android\sdk\cmdline-tools\latest"
}
Move-Item -Path "$env:TEMP\cmdline-tools" -Destination "C:\Android\sdk\cmdline-tools\latest" -Force
Write-Host "cmdline-tools installé avec succès dans C:\Android\sdk\cmdline-tools\latest !"

Write-Host "--- Test sdkmanager ---"
& "C:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat" --version

Write-Host "--- Acceptation des licences Android ---"
$answers = "y`ny`ny`ny`ny`ny`ny`ny`ny`ny`ny`ny`n"
$answers | & "C:\src\flutter\bin\flutter.bat" doctor --android-licenses

Write-Host "--- Flutter Doctor Final ---"
& "C:\src\flutter\bin\flutter.bat" doctor -v
