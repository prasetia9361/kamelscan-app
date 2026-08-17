# Menjalankan KamelScan dengan kredensial dari env.dev.json.
#
# Dibuat karena `flutter run` polos akan berhenti di layar "Konfigurasi belum
# lengkap": tanpa --dart-define-from-file, tidak ada satu pun kunci Supabase
# yang ikut ke dalam aplikasi.
#
#   .\run.ps1                  -> jalankan (debug) di perangkat pertama
#   .\run.ps1 -Profile         -> jalankan mode profile
#   .\run.ps1 -Device chrome
#   .\run.ps1 -Build           -> hanya membangun APK debug
#   .\run.ps1 -Build -Profile  -> hanya membangun APK profile
#   .\run.ps1 -Release         -> APK release memakai env.prod.json
#
# Kapan memakai -Profile:
#   Mode debug SENGAJA lambat — tiap perintah diperiksa berkali-kali dan tidak
#   ada optimasi. Pratinjau kamera akan terasa patah-patah, dan itu bukan cacat
#   produk. Untuk menilai kelancaran atau mengukur kecepatan yang sesungguhnya,
#   pakai -Profile. Terukur di Redmi Note 9: watermark video 30 detik butuh
#   32 detik di debug, tetapi hanya 17 detik di profile.

param(
    [string]$Device = '',
    [switch]$Build,
    [switch]$Profile,
    [switch]$Release
)

$ErrorActionPreference = 'Stop'

$flutter = 'E:\flutter_sdk\flutter_3.44.8\bin\flutter.bat'
$env:JAVA_HOME = 'E:\Android\Android Studio\jbr'

if ($Profile -and $Release) {
    Write-Host "BERHENTI: -Profile dan -Release tidak bisa dipakai bersamaan." -ForegroundColor Red
    Write-Host "Pilih salah satu: -Profile untuk mengukur, -Release untuk rilis."
    exit 1
}

$envFile = if ($Release) { 'env.prod.json' } else { 'env.dev.json' }

if (-not (Test-Path $envFile)) {
    Write-Host "BERHENTI: $envFile tidak ada." -ForegroundColor Red
    Write-Host "Salin env.example.json menjadi $envFile lalu isi nilainya."
    Write-Host "Berkas itu sengaja tidak masuk git karena berisi kredensial."
    exit 1
}

$mode = if ($Release) { '--release' } elseif ($Profile) { '--profile' } else { '--debug' }

# Sengaja BUKAN $args: nama itu variabel otomatis PowerShell yang sudah berisi
# argumen tak dikenal, dan menimpanya membuat perilaku skrip sulit ditebak.
$flutterArgs = @("--dart-define-from-file=$envFile")
if ($Device) { $flutterArgs += @('-d', $Device) }

if ($Build) {
    Write-Host "Membangun APK $mode dengan $envFile ..." -ForegroundColor Cyan
    & $flutter build apk $mode @flutterArgs
} else {
    Write-Host "Menjalankan $mode dengan $envFile ..." -ForegroundColor Cyan
    & $flutter run $mode @flutterArgs
}
