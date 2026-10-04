# Script pour installer automatiquement Android SDK 36 et NDK 27 si nécessaire
$env:JAVA_HOME = "C:\tools\jdk17"
$env:ANDROID_HOME = "C:\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Android\sdk"
$env:Path = "C:\tools\git\cmd;C:\tools\jdk17\bin;C:\Android\sdk\platform-tools;C:\Android\sdk\cmdline-tools\latest\bin;C:\src\flutter\bin;" + [Environment]::GetEnvironmentVariable("Path", "Machine")

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Vérification / Installation Android SDK 36 et NDK 27" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$sdkmanager = "C:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat"

if (Test-Path $sdkmanager) {
    Write-Host "1. Acceptation des licences Android..." -ForegroundColor Yellow
    cmd.exe /c "echo y|echo y|echo y|echo y|echo y|echo y|echo y|echo y|echo y|echo y| $sdkmanager --licenses"
    
    Write-Host "`n2. Téléchargement de la plateforme Android 36 et du NDK 27..." -ForegroundColor Yellow
    & $sdkmanager "platforms;android-36" "ndk;27.0.12077973"
    
    Write-Host "`nInstallation terminée avec succès !" -ForegroundColor Green
} else {
    Write-Host "sdkmanager introuvable à : $sdkmanager" -ForegroundColor Red
}
