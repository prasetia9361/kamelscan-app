# Menjalankan KamelScan dengan kredensial dari env.dev.json.
#
# Dibuat karena `flutter run` polos akan berhenti di layar "Konfigurasi belum
# lengkap": tanpa --dart-define-from-file, tidak ada satu pun kunci Supabase
# yang ikut ke dalam aplikasi.
#
#   .\run.ps1              -> jalankan di perangkat pertama yang terhubung
#   .\run.ps1 -Device chrome
#   .\run.ps1 -Build       -> hanya membangun APK debug
#   .\run.ps1 -Release     -> APK release memakai env.prod.json

param(
    [string]$Device = '',
    [switch]$Build,
    [switch]$Release
)

$ErrorActionPreference = 'Stop'

$flutter = 'E:\flutter_sdk\flutter_3.44.8\bin\flutter.bat'
$env:JAVA_HOME = 'E:\Android\Android Studio\jbr'

$envFile = if ($Release) { 'env.prod.json' } else { 'env.dev.json' }

if (-not (Test-Path $envFile)) {
    Write-Host "BERHENTI: $envFile tidak ada." -ForegroundColor Red
    Write-Host "Salin env.example.json menjadi $envFile lalu isi nilainya."
    Write-Host "Berkas itu sengaja tidak masuk git karena berisi kredensial."
    exit 1
}

$args = @("--dart-define-from-file=$envFile")
if ($Device) { $args += @('-d', $Device) }

if ($Build) {
    $mode = if ($Release) { '--release' } else { '--debug' }
    Write-Host "Membangun APK $mode dengan $envFile ..." -ForegroundColor Cyan
    & $flutter build apk $mode @args
} else {
    Write-Host "Menjalankan dengan $envFile ..." -ForegroundColor Cyan
    & $flutter run @args
}
