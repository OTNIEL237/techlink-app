# =============================================================================
# SCRIPT : build_apk_rapide.ps1
# RÔLE : Nettoyage des daemons Gradle bloqués et compilation ultra-rapide de l'APK TechLink
# USAGE : Exécutez ce script dans PowerShell : .\build_apk_rapide.ps1
# =============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   COMPILATION RAPIDE DE L'APK TECHLINK (POUR LA SOUTENANCE)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Configuration des variables d'environnement
$env:JAVA_HOME = "C:\tools\jdk17"
$env:ANDROID_HOME = "C:\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Android\sdk"
$env:Path = "C:\tools\git\cmd;C:\tools\jdk17\bin;C:\Android\sdk\platform-tools;C:\Android\sdk\cmdline-tools\latest\bin;C:\src\flutter\bin;" + [Environment]::GetEnvironmentVariable("Path", "Machine")

# 2. Arrêt des processus Java/Gradle zombies (qui bloquent le cache après Ctrl+C)
Write-Host "`n[1/5] Fermeture des processus Gradle et Java bloqués..." -ForegroundColor Yellow
Stop-Process -Name java -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 3. Arrêt propre du démon Gradle dans le dossier mobile
$currentDir = Get-Location
Set-Location "$PSScriptRoot\mobile\android"
Write-Host "[2/5] Arrêt des démons Gradle existants..." -ForegroundColor Yellow
cmd.exe /c "gradlew.bat --stop"
Set-Location "$PSScriptRoot\mobile"

# 4. Nettoyage Flutter et récupération des dépendances
Write-Host "`n[3/5] Nettoyage du cache Flutter (flutter clean)..." -ForegroundColor Yellow
& "C:\src\flutter\bin\flutter.bat" clean

Write-Host "`n[4/5] Récupération des packages Flutter (flutter pub get)..." -ForegroundColor Yellow
& "C:\src\flutter\bin\flutter.bat" pub get

# 5. Compilation optimisée de l'APK (séparation par architecture ABI)
# L'option --split-per-abi évite de compiler un APK universel monstrueux de 300 Mo avec ZegoCloud
Write-Host "`n[5/5] Compilation de l'APK Release avec --split-per-abi..." -ForegroundColor Green
Write-Host "-> Cela va générer des APK légers (~40 Mo) en 2 à 3 minutes au lieu de 48 minutes !" -ForegroundColor Cyan

& "C:\src\flutter\bin\flutter.bat" build apk --split-per-abi

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "VERIFICATION DE L'APK GÉNÉRÉ :" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

$apkDir = "$PSScriptRoot\mobile\build\app\outputs\flutter-apk"
if (Test-Path $apkDir) {
    Get-ChildItem -Path $apkDir -Filter "*.apk" | ForEach-Object {
        $tailleMo = [math]::Round($_.Length / 1MB, 2)
        Write-Host "✅ APK trouvé : $($_.Name) ($tailleMo Mo)" -ForegroundColor Green
        Write-Host "   Chemin : $($_.FullName)" -ForegroundColor White
    }
    Write-Host "`n👉 Pour votre téléphone Android moderne, installez : app-arm64-v8a-release.apk" -ForegroundColor Cyan
} else {
    Write-Host "Dossier de sortie non trouvé." -ForegroundColor Red
}

Set-Location $currentDir
