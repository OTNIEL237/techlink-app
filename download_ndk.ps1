$NdkVersion = "android-ndk-r26c"
$NdkUrl = "https://dl.google.com/android/repository/${NdkVersion}-windows.zip"
$ZipFile = "C:\Android\${NdkVersion}-windows.zip"
$NdkDest = "C:\Android\sdk\ndk"
$NdkVersionDirName = "26.2.11394342"
$FinalNdkPath = "$NdkDest\$NdkVersionDirName"
$ExtractedDir = "C:\Android\$NdkVersion"

Write-Host "============================================="
Write-Host "Téléchargement sécurisé du NDK Android avec curl..."
Write-Host "Reprise automatique activée pour gérer les pannes de connexion"
Write-Host "============================================="

$success = $false
for ($i=1; $i -le 30; $i++) {
    curl.exe -L -C - -o $ZipFile $NdkUrl
    if ($LASTEXITCODE -eq 0) {
        $success = $true
        break
    }
    Write-Host "Coupure réseau ou problème DNS détecté. Nouvelle tentative ($i/30) dans 15 secondes..."
    Start-Sleep -Seconds 15
}

if (-not $success) {
    Write-Host "Erreur : Échec du téléchargement du NDK après 30 tentatives." -ForegroundColor Red
    exit 1
}

Write-Host "============================================="
Write-Host "Extraction de l'archive ZIP (veuillez patienter)..."
Write-Host "============================================="

if (Test-Path $FinalNdkPath) { Remove-Item -Path $FinalNdkPath -Recurse -Force }
if (Test-Path $ExtractedDir) { Remove-Item -Path $ExtractedDir -Recurse -Force }

tar.exe -xf $ZipFile -C "C:\Android"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur : L'extraction a échoué. Le fichier ZIP est peut-être corrompu." -ForegroundColor Red
    exit 1
}

Write-Host "============================================="
Write-Host "Déplacement vers le dossier SDK ($FinalNdkPath)..."
Write-Host "============================================="

if (!(Test-Path -Path $NdkDest)) {
    New-Item -ItemType Directory -Force -Path $NdkDest | Out-Null
}

if (Test-Path -Path $ExtractedDir) {
    Move-Item -Path $ExtractedDir -Destination $FinalNdkPath -Force
    Write-Host "Dossier NDK déplacé avec succès." -ForegroundColor Green
} else {
    Write-Host "Erreur : Le dossier extrait $ExtractedDir est introuvable." -ForegroundColor Red
    exit 1
}

Remove-Item -Path $ZipFile -Force
Write-Host "NDK installé avec succès !" -ForegroundColor Green
