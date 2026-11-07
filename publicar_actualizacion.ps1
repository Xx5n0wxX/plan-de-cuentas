$ErrorActionPreference = "Stop"
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.8-hotspot"
$env:ANDROID_HOME = "C:\Users\diego\AppData\Local\Android\sdk"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

Write-Output "1/4 Compilando version Web/Cloud..."
& "C:\src\flutter\bin\flutter.bat" build web --release

Write-Output "2/4 Compilando APK de Android..."
& "C:\src\flutter\bin\flutter.bat" build apk --release
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "c:\Herramientas\MICROAPPS\PLAN DE CUENTAS\instaladores\PlanDeCuentas_Android.apk" -Force
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$env:USERPROFILE\Desktop\PlanDeCuentas_Android.apk" -Force

Write-Output "3/4 Actualizando ejecutable e instalador de Windows (.exe)..."
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

Write-Output "4/4 Publicando actualizacion OTA en Firebase Hosting..."
firebase deploy --only hosting --project plan-de-cuentas-45670
Write-Output "PUBLICACION_COMPLETADA_OK"
