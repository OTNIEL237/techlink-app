# Set up Android licenses and install platform 34
$env:JAVA_HOME = "C:\tools\jdk17"
$env:ANDROID_HOME = "C:\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Android\sdk"
$env:Path = "C:\tools\git\cmd;C:\tools\jdk17\bin;C:\Android\sdk\platform-tools;C:\Android\sdk\cmdline-tools\latest\bin;C:\src\flutter\bin;" + [Environment]::GetEnvironmentVariable("Path", "Machine")

# 1. Write Android SDK licenses directly
New-Item -ItemType Directory -Force -Path "C:\Android\sdk\licenses" | Out-Null
$androidSdkLicense = @"
24333f8a6341dd722848148e61469b01677887f3
8933bad161af4178b1185d1a37fbf41ea5269c55
d56f5187479451eabf01fb78af6dfcb131a6481e
"@
Set-Content -Path "C:\Android\sdk\licenses\android-sdk-license" -Value $androidSdkLicense

$androidPreviewLicense = "84831b9409646a918e30573bab4c9c91346d8abd"
Set-Content -Path "C:\Android\sdk\licenses\android-sdk-preview-license" -Value $androidPreviewLicense
Write-Host "Licences Android enregistrées avec succès !"

# 2. Configure flutter sdk path
& "C:\src\flutter\bin\flutter.bat" config --android-sdk "C:\Android\sdk"

# 3. Install platform 34 and build-tools 34.0.0
Write-Host "Installation de la plateforme Android (platforms;android-34 et build-tools;34.0.0)..."
& "C:\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="C:\Android\sdk" "platforms;android-34" "build-tools;34.0.0"

# 4. Verify with Flutter Doctor
Write-Host "--- Verification finale Flutter Doctor ---"
& "C:\src\flutter\bin\flutter.bat" doctor -v
