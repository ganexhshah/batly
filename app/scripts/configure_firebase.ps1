# Regenerate lib/firebase_options.dart for all platforms.
# Requires: firebase login (firebase login) once per machine.
#
# From the app/ directory:
#   dart pub global activate flutterfire_cli
#   flutterfire configure --project=zone-e4bb4

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..

$flutterfire = Join-Path $env:LOCALAPPDATA 'Pub\Cache\bin\flutterfire.bat'
if (-not (Test-Path $flutterfire)) {
  Write-Host 'Installing flutterfire_cli...'
  dart pub global activate flutterfire_cli
}

& $flutterfire configure --project=zone-e4bb4 --yes --platforms=android,ios,web,macos,windows
Write-Host 'Done. Commit lib/firebase_options.dart and platform config files.'
