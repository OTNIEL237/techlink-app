Get-ChildItem -Path lib -Filter *.dart -Recurse | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match "NetworkImage\(") {
        if (-not ($content -match "cached_network_image\.dart")) {
            $content = "import 'package:cached_network_image/cached_network_image.dart';`n" + $content
        }
        $content = $content -replace "NetworkImage\(", "CachedNetworkImageProvider("
        Set-Content -Path $_.FullName -Value $content -Encoding UTF8
        Write-Host "Updated $($_.FullName)"
    }
}
