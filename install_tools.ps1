# Install Git and OpenJDK 17
New-Item -ItemType Directory -Force -Path 'C:\tools\git', 'C:\tools\jdk17' | Out-Null

Write-Host "1/3 : Téléchargement et installation de Git (~37 Mo)..."
curl.exe -L -o "$env:TEMP\mingit.zip" 'https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.5/MinGit-2.55.0.5-64-bit.zip'
tar.exe -xf "$env:TEMP\mingit.zip" -C 'C:\tools\git'
Remove-Item -Force "$env:TEMP\mingit.zip"
Write-Host "Git installé avec succès !"

Write-Host "2/3 : Téléchargement et installation de OpenJDK 17 (~186 Mo)..."
curl.exe -L -o "$env:TEMP\jdk17.zip" 'https://download.visualstudio.microsoft.com/download/pr/58dca6c6-c3c9-4daa-8e17-b7d0df501afc/667a0e2c93e1aab8df0707a31c42d190/microsoft-jdk-17.0.12-windows-x64.zip'
tar.exe -xf "$env:TEMP\jdk17.zip" -C "$env:TEMP"
$jdkDir = (Get-ChildItem -Path "$env:TEMP" -Filter "jdk-17*" | Select-Object -First 1).FullName
Copy-Item -Path "$jdkDir\*" -Destination 'C:\tools\jdk17' -Recurse -Force
Remove-Item -Recurse -Force $jdkDir, "$env:TEMP\jdk17.zip"
Write-Host "OpenJDK 17 installé avec succès !"

Write-Host "3/3 : Configuration des variables d'environnement..."
[Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\tools\jdk17', 'User')
[Environment]::SetEnvironmentVariable('ANDROID_HOME', 'C:\Android\sdk', 'User')
[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', 'C:\Android\sdk', 'User')

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $userPath) { $userPath = "" }
$newEntries = @('C:\tools\git\cmd', 'C:\tools\jdk17\bin', 'C:\Android\sdk\platform-tools', 'C:\src\flutter\bin')
foreach ($entry in $newEntries) {
    if ($userPath -notlike "*$entry*") {
        $userPath = "$entry;$userPath"
    }
}
[Environment]::SetEnvironmentVariable('Path', $userPath, 'User')
Write-Host "Toutes les variables ont été configurées !"

# Test versions
Write-Host "--- VERIFICATION ---"
& 'C:\tools\git\cmd\git.exe' --version
& 'C:\tools\jdk17\bin\java.exe' -version
