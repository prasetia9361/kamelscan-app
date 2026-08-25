# Menyusun folder yang siap diunggah ke Cloudflare Pages.
#
# Kenapa skrip tersendiri, bukan cukup `flutter build web`:
# folder yang diunggah ke Cloudflare BUKAN `build\web`. Bab 10.2 menetapkan
# akar situs ditempati landing page statis, sedangkan Flutter Web menempati
# `/app/`. Jadi `build\web` hanyalah ISI dari salah satu subfolder:
#
#   build\deploy\
#     +- index.html      <- landing page (dikerjakan desainer)
#     +- app\            <- seluruh isi build\web
#     +- v\              <- halaman bukti publik
#     +- _redirects      <- aturan alamat, WAJIB di akar
#
# Berkas `_redirects` tidak bisa diletakkan di folder `web\` proyek ini: ia
# akan ikut terbangun ke `build\web\_redirects` dan berakhir sebagai
# `/app/_redirects`, tempat Cloudflare tidak pernah membacanya.
#
#   .\deploy_web.ps1                          -> pakai env.dev.json
#   .\deploy_web.ps1 -Release                 -> pakai env.prod.json
#   .\deploy_web.ps1 -Landing ..\landing-page -> ikutkan landing page desainer
#   .\deploy_web.ps1 -SkipBuild               -> susun ulang tanpa membangun
#
# CATATAN: jalankan dari PowerShell, JANGAN dari terminal Git Bash. Git Bash
# menerjemahkan argumen `/app/` menjadi `C:/Program Files/Git/app/` sebelum
# Flutter melihatnya, dan perintahnya tetap melaporkan berhasil.

param(
    [switch]$Release,
    [string]$Landing = '',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$flutter = 'E:\flutter_sdk\flutter_3.44.8\bin\flutter.bat'
$envFile = if ($Release) { 'env.prod.json' } else { 'env.dev.json' }
$out     = 'build\deploy'

if (-not (Test-Path $envFile)) {
    Write-Host "BERHENTI: $envFile tidak ada." -ForegroundColor Red
    Write-Host "Salin env.example.json menjadi $envFile lalu isi nilainya."
    exit 1
}

# ---------------------------------------------------------------------------
# Peringatan alamat web.
#
# WEB_APP_BASE_URL menentukan tujuan tautan verifikasi email dan reset
# password. Bila ia masih localhost, tautan yang dikirim ke pengguna sungguhan
# akan menunjuk ke komputer mereka sendiri. Supabase TIDAK melaporkan ini
# sebagai kesalahan - ia diam-diam memakai Site URL sebagai gantinya.
# ---------------------------------------------------------------------------
$cfg = Get-Content $envFile -Raw | ConvertFrom-Json
$baseUrl = $cfg.WEB_APP_BASE_URL
if ([string]::IsNullOrWhiteSpace($baseUrl)) {
    Write-Host "BERHENTI: WEB_APP_BASE_URL kosong di $envFile." -ForegroundColor Red
    exit 1
}
if ($baseUrl -like '*localhost*' -or $baseUrl -like '*127.0.0.1*') {
    Write-Host ""
    Write-Host "PERINGATAN: WEB_APP_BASE_URL masih '$baseUrl'." -ForegroundColor Yellow
    Write-Host "Hasil build ini HANYA layak untuk uji coba di komputer sendiri."
    Write-Host "Sebelum diunggah untuk dipakai orang lain, isi dengan alamat"
    Write-Host "sungguhan yang berakhiran /app - lalu daftarkan alamat itu di"
    Write-Host "Supabase Dashboard, Authentication, URL Configuration."
    Write-Host ""
}

# ---------------------------------------------------------------------------
# 1. Bangun Flutter Web
# ---------------------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Host "Membangun Flutter Web dengan $envFile ..." -ForegroundColor Cyan
    & $flutter build web --release "--dart-define-from-file=$envFile" --base-href /app/
    if ($LASTEXITCODE -ne 0) {
        Write-Host "BERHENTI: flutter build web gagal." -ForegroundColor Red
        exit 1
    }
}

if (-not (Test-Path 'build\web\index.html')) {
    Write-Host "BERHENTI: build\web\index.html tidak ada." -ForegroundColor Red
    Write-Host "Jalankan tanpa -SkipBuild supaya aplikasinya dibangun lebih dulu."
    exit 1
}

$baseHref = Select-String -Path 'build\web\index.html' -Pattern '<base href="([^"]*)">' |
    ForEach-Object { $_.Matches[0].Groups[1].Value }
if ($baseHref -ne '/app/') {
    Write-Host "BERHENTI: base href hasil build adalah '$baseHref', seharusnya '/app/'." -ForegroundColor Red
    Write-Host "Penyebab paling sering: skrip dijalankan dari Git Bash, bukan PowerShell."
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Susun folder deploy dari nol
#
# Sengaja dihapus lebih dulu: sisa berkas dari build sebelumnya yang tidak lagi
# dihasilkan akan ikut terunggah dan tetap dilayani Cloudflare.
# ---------------------------------------------------------------------------
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force -Path $out | Out-Null

Copy-Item 'build\web' (Join-Path $out 'app') -Recurse
Write-Host "Flutter Web disalin ke $out\app" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 3. Landing page (opsional, milik desainer)
# ---------------------------------------------------------------------------
if ($Landing) {
    if (-not (Test-Path $Landing)) {
        Write-Host "BERHENTI: folder landing '$Landing' tidak ditemukan." -ForegroundColor Red
        exit 1
    }
    Copy-Item (Join-Path $Landing '*') $out -Recurse -Force
    Write-Host "Landing page disalin dari $Landing" -ForegroundColor Green
} else {
    Write-Host "Landing page dilewati - akar situs akan menjawab 404." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 3b. Halaman bukti publik /v/{token}
#
# Bab 10.2 mengeluarkan rute ini dari bundel Flutter supaya petugas resolusi
# marketplace tidak mengunduh 4,3 MB hanya untuk menonton satu video.
#
# Kredensial diisi DI SINI, bukan di dalam berkas sumbernya: web_public masuk
# git, env.dev.json tidak. Kunci anon memang kunci publik, tetapi tetap tidak
# dituliskan ke dalam repositori.
# ---------------------------------------------------------------------------
$sumberV = 'web_public/v/index.html'
if (Test-Path $sumberV) {
    if ([string]::IsNullOrWhiteSpace($cfg.SUPABASE_URL) -or
        [string]::IsNullOrWhiteSpace($cfg.SUPABASE_ANON_KEY)) {
        Write-Host "BERHENTI: SUPABASE_URL atau SUPABASE_ANON_KEY kosong di $envFile." -ForegroundColor Red
        exit 1
    }

    $html = Get-Content $sumberV -Raw -Encoding UTF8
    $html = $html.Replace('__SUPABASE_URL__', $cfg.SUPABASE_URL)
    $html = $html.Replace('__SUPABASE_ANON_KEY__', $cfg.SUPABASE_ANON_KEY)

    # Penjaga: penanda yang lolos berarti halaman terbit tanpa kredensial dan
    # setiap pembukanya hanya melihat pesan "belum disiapkan".
    if ($html -match '__SUPABASE_') {
        Write-Host "BERHENTI: penanda kredensial masih tersisa di halaman /v/." -ForegroundColor Red
        exit 1
    }

    $tujuanV = Join-Path (Resolve-Path $out).Path 'v'
    New-Item -ItemType Directory -Force -Path $tujuanV | Out-Null

    # WriteAllText dengan UTF8Encoding($false): tanpa BOM. Set-Content -Encoding
    # utf8 pada PowerShell 5.1 menyisipkan BOM, dan tiga byte tak terlihat di
    # depan <!DOCTYPE> membuat sebagian peramban jatuh ke mode quirks.
    [System.IO.File]::WriteAllText(
        (Join-Path $tujuanV 'index.html'), $html,
        (New-Object System.Text.UTF8Encoding($false)))

    Write-Host "Halaman bukti publik disusun di $out/v" -ForegroundColor Green
} else {
    Write-Host "Halaman /v/ dilewati - $sumberV tidak ada." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 4. Aturan alamat
#
# Tanpa aturan ini, menyegarkan halaman di /app/history membuat Cloudflare
# mencari berkas bernama 'history' dan menjawab 404. Aturannya memerintahkan
# Cloudflare mengembalikan index.html dengan status 200, lalu aplikasilah yang
# membaca alamatnya. Diperlukan karena tanda # sudah dibuang dari alamat.
#
# Aturan /v/ hanya ditulis bila halamannya memang ada, supaya tidak ada aturan
# yang menunjuk berkas yang tidak pernah dibuat.
# ---------------------------------------------------------------------------
# 🔴 DUA aturan mahal yang dipelajari 25 Agustus 2026, keduanya gagal DIAM:
#
# 1. Tujuan TIDAK boleh berakhiran `.html`.
#    Cloudflare punya kebiasaan sendiri membuang akhiran .html dan mengalihkan
#    alamatnya (308). Aturan `/app/* -> /app/index.html` karena itu tidak
#    pernah menyajikan apa pun; hasilnya 404 di situs yang sudah terbit,
#    padahal dashboard menampilkan aturannya terdaftar rapi tanpa galat.
#    Tulis tujuannya sebagai direktori: `/app/`.
#
# 2. Pola TIDAK boleh `/app/*`.
#    `_redirects` diproses SEBELUM berkas dicari, jadi `/app/*` ikut menelan
#    main.dart.js, flutter.js, manifest.json, dan seluruh isi assets/ -
#    semuanya berubah menjadi HTML dan aplikasinya jadi halaman putih.
#    Karena itu rutenya didaftarkan satu per satu di bawah ini.
#
# ⚠️ KONSEKUENSI: setiap rute baru di `route_names.dart` WAJIB ditambahkan ke
#    daftar ini. Yang terlupa akan bekerja saat diklik dari dalam aplikasi,
#    tetapi menjawab 404 begitu halamannya disegarkan atau alamatnya dikirim
#    ke orang lain - gejala yang mudah disalahartikan sebagai cacat aplikasi.
$rules = @()

# Halaman bukti publik: aman memakai bintang karena di bawah /v/ memang tidak
# ada berkas lain selain halamannya sendiri.
if (Test-Path (Join-Path $out 'v/index.html')) {
    $rules += '/v/*    /v/    200'
}

# Rute aplikasi (Bab 6, 9, 10) - cocokkan dengan lib/navigation/route_names.dart
foreach ($r in @(
    'login', 'register', 'verify-email', 'forgot-password',
    'change-password', 'complete-profile', 'reset-password',
    'dashboard', 'tutorial',
    'home', 'home/*',
    'history', 'history/*',
    'shops', 'shops/*',
    'account', 'account/*',
    'settings', 'settings/*',
    'payment', 'payment/*',
    'admin', 'admin/*',
    'auth/*'
)) {
    $rules += ('/app/{0}  /app/  200' -f $r)
}
# 🔴 Ditulis manual dengan akhir baris LF dan tanpa BOM. Set-Content TIDAK
# boleh dipakai di sini, dan ini bukan kerewelan gaya:
#
#   - Set-Content menulis akhir baris Windows (CRLF). Cloudflare TERNYATA
#     memaafkannya - diuji 25 Agustus 2026, CRLF bukan penyebab kegagalan
#     hari itu. LF tetap dipakai karena itu bentuk yang didokumentasikan, dan
#     karena bergantung pada kemurahan hati yang tidak dijanjikan itu bodoh.
#   - Set-Content -Encoding utf8 pada PowerShell 5.1 menambah BOM, yang
#     merusak baris pertama dengan cara yang sama diamnya.
# Tambalan sementara: akar situs dilempar ke aplikasi selama landing page
# belum diserahkan desainer (Bab 10.2). Tanpa ini, siapa pun yang mengetik
# kamelscan.com melihat halaman 404 Cloudflare berbahasa Inggris.
#
# 🔴 Sengaja 302 (sementara), BUKAN 301 (permanen). Peramban menyimpan 301
# di komputer pengunjung dan tetap mematuhinya walaupun aturannya sudah
# dihapus dari server - landing page yang baru tidak akan pernah terlihat
# oleh orang yang sempat membukanya lebih dulu.
#
# ⚠️ HAPUS baris ini begitu landing page dipasang di akar.
$rules += '/  /app/  302'

$isi = ($rules -join "`n") + "`n"
[System.IO.File]::WriteAllText(
    (Join-Path (Resolve-Path $out).Path '_redirects'), $isi,
    (New-Object System.Text.ASCIIEncoding))
Write-Host "_redirects ditulis:" -ForegroundColor Green
$rules | ForEach-Object { Write-Host "    $_" }

# ---------------------------------------------------------------------------
# 5. Ringkasan
# ---------------------------------------------------------------------------
$full = (Resolve-Path $out).Path
$sizeMb = [math]::Round(((Get-ChildItem $out -Recurse -File | Measure-Object Length -Sum).Sum / 1MB), 1)

Write-Host ""
Write-Host "SELESAI. Folder siap unggah:" -ForegroundColor Cyan
Write-Host "    $full   ($sizeMb MB)"
Write-Host ""
Write-Host "Langkah berikutnya di Cloudflare Pages:"
Write-Host "  1. Buka dash.cloudflare.com, pilih Workers & Pages."
Write-Host "  2. Create, lalu Pages, lalu Upload assets."
Write-Host "  3. Seret SELURUH ISI folder di atas - bukan foldernya."
Write-Host "  4. Setelah selesai, buka alamat yang diberikan lalu tambahkan /app"
Write-Host "     di belakangnya. Contoh: https://nama-proyek.pages.dev/app"
Write-Host ""
