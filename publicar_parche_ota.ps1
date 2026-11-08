$ErrorActionPreference = "Stop"
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.8-hotspot"
$env:ANDROID_HOME = "C:\Users\diego\AppData\Local\Android\sdk"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

Write-Output "=== Publicando Parche Rápido OTA con Shorebird ==="

Write-Output "1/3 Limpiando temporales de hooks de compilación..."
Remove-Item -Recurse -Force ".dart_tool\hooks_runner" -ErrorAction SilentlyContinue

Write-Output "2/3 Compilando y subiendo parche diferencial OTA para Android..."
& "$HOME\.shorebird\bin\shorebird.ps1" patch android --release-version=latest --track stable --allow-asset-diffs

Write-Output "3/3 Sincronizando versión Web en Firebase Hosting..."
& "C:\src\flutter\bin\flutter.bat" build web --release
firebase deploy --only hosting --project plan-de-cuentas-45670

Write-Output "=================================================="
Write-Output "✓ PARCHE_OTA_PUBLICADO_OK"
Write-Output "Tu parche ligero ya está disponible en la nube de Shorebird."
Write-Output "Los usuarios en Android lo recibirán en silencio en 1-2 segundos sin reinstalar el APK."
Write-Output "=================================================="
