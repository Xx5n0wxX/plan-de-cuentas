$ErrorActionPreference = "Stop"
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.8-hotspot"
$env:ANDROID_HOME = "C:\Users\diego\AppData\Local\Android\sdk"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

Write-Output "0/5 Verificando consistencia de versión y build..."
$vJson = Get-Content "web\version.json" -Raw | ConvertFrom-Json
$pubMatch = (Select-String -Path "pubspec.yaml" -Pattern "version:\s*([0-9\.]+)\+([0-9]+)").Matches[0]
$pubVer = $pubMatch.Groups[1].Value
$pubBuild = $pubMatch.Groups[2].Value

$dartV = (Select-String -Path "lib\services\app_update_service.dart" -Pattern "currentVersion\s*=\s*'([^']+)'").Matches[0].Groups[1].Value
$dartB = (Select-String -Path "lib\services\app_update_service.dart" -Pattern "currentBuildNumber\s*=\s*([0-9]+)").Matches[0].Groups[1].Value

if ($vJson.version -ne $pubVer -or $vJson.version -ne $dartV -or [string]$vJson.buildNumber -ne $pubBuild -or [string]$vJson.buildNumber -ne $dartB) {
    throw "ERROR: Versiones desalineadas! version.json=$($vJson.version)+$($vJson.buildNumber), pubspec=$pubVer+$pubBuild, app_update_service=$dartV+$dartB"
}
Write-Output "✓ Versiones verificadas y sincronizadas: $pubVer+$pubBuild"

Write-Output "1/5 Compilando version Web/Cloud..."
& "C:\src\flutter\bin\flutter.bat" build web --release
Copy-Item "web\version.json" "build\web\version.json" -Force
Remove-Item "build\web\downloads" -Recurse -Force -ErrorAction SilentlyContinue

Write-Output "2/5 Compilando APK de Android con motor Shorebird OTA..."
Remove-Item -Recurse -Force ".dart_tool\hooks_runner" -ErrorAction SilentlyContinue
& "$HOME\.shorebird\bin\shorebird.ps1" release android --artifact apk
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\instaladores\PlanDeCuentas_Android.apk" -Force
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$env:USERPROFILE\Desktop\PlanDeCuentas_Android.apk" -Force

Write-Output "3/5 Actualizando ejecutable e instalador de Windows (.exe)..."
Stop-Process -Name "PlanDeCuentas*" -Force -ErrorAction SilentlyContinue
$stageDir = "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\windows_installer\staging"
if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
dotnet publish "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\windows_installer\AppHost\PlanDeCuentas.csproj" -c Release -r win-x64 --self-contained false -o $stageDir
Copy-Item "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\windows_installer\app_icon.ico" "$stageDir\app_icon.ico" -Force
New-Item -ItemType Directory -Force -Path "$stageDir\data\web" | Out-Null
Copy-Item "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\build\web\*" "$stageDir\data\web" -Recurse -Force

$zipPath = "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\windows_installer\payload.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$stageDir\*" -DestinationPath $zipPath -Force

$setupOut = "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\windows_installer\out"
if (Test-Path $setupOut) { Remove-Item $setupOut -Recurse -Force }
dotnet publish "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\windows_installer\SetupWizard\PlanDeCuentas_Setup.csproj" -c Release -r win-x64 -o $setupOut

Copy-Item "$setupOut\PlanDeCuentas_Setup.exe" "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\instaladores\PlanDeCuentas_Setup.exe" -Force
Copy-Item "$setupOut\PlanDeCuentas_Setup.exe" "$env:USERPROFILE\Desktop\PlanDeCuentas_Setup.exe" -Force

Start-Process -FilePath "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\instaladores\PlanDeCuentas_Setup.exe" -ArgumentList "--silent" -Wait

Write-Output "4/5 Publicando instaladores en GitHub Releases..."
$ghPath = "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe"
if (-not (Test-Path $ghPath)) {
    $ghPath = "gh"
}

$vJson = Get-Content "web\version.json" -Raw | ConvertFrom-Json
$verTag = "v$($vJson.version)"
$apkFile = "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\instaladores\PlanDeCuentas_Android.apk"
$exeFile = "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\instaladores\PlanDeCuentas_Setup.exe"

$relExists = $false
try {
    & $ghPath release view $verTag 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $relExists = $true }
} catch {
    $relExists = $false
}

if ($relExists) {
    Write-Output "Actualizando instaladores en release existente $verTag..."
    & $ghPath release upload $verTag $apkFile $exeFile --clobber
} else {
    Write-Output "Creando nuevo release $verTag en GitHub..."
    & $ghPath release create $verTag $apkFile $exeFile --title "Plan de Cuentas $verTag" --notes "$($vJson.changelog)"
}

Write-Output "5/5 Publicando actualizacion OTA en Firebase Hosting..."
firebase deploy --only hosting --project plan-de-cuentas-45670

Write-Output "PUBLICACION_COMPLETADA_OK"
