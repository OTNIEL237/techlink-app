$env:JAVA_HOME = "C:\tools\jdk17"
$env:ANDROID_HOME = "C:\Android\sdk"
$env:ANDROID_SDK_ROOT = "C:\Android\sdk"
$env:Path = "C:\tools\git\cmd;C:\tools\jdk17\bin;C:\Android\sdk\platform-tools;C:\Android\sdk\cmdline-tools\latest\bin;C:\src\flutter\bin;" + [Environment]::GetEnvironmentVariable("Path", "Machine")

New-Item -ItemType Directory -Force -Path "C:\Android\sdk\licenses" | Out-Null

$lics = @{
    "android-sdk-license" = @(
        "24333f8a6341dd722848148e61469b01677887f3",
        "8933bad161af4178b1185d1a37fbf41ea5269c55",
        "d56f5187479451eabf01fb78af6dfcb131a6481e"
    )
    "android-sdk-preview-license" = @(
        "84831b9409646a918e30573bab4c9c91346d8abd",
        "79944a42c040c1438d6c41e87b7fb382527f4f73"
    )
    "android-googletv-license" = @(
        "601085b94cd77f0b54ff86406957099150008536"
    )
    "android-sdk-arm-dbt-license" = @(
        "859f317696f67ef3d7f30a50a5560e7834b43903"
    )
    "google-gdk-license" = @(
        "33b6a2b64607f11b759f320ef9dff4ae5c47d97a"
    )
    "mips-android-sysimage-license" = @(
        "e9acab5b5fbb560a72cfa4f404098939e60a92d4"
    )
}

foreach ($k in $lics.Keys) {
    Set-Content -Path "C:\Android\sdk\licenses\$k" -Value ($lics[$k] -join "`r`n")
}

Write-Host "Licences enregistrées !"
& "C:\src\flutter\bin\flutter.bat" doctor
