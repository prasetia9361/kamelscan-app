# Layar peluncur KamelScan — cara memasang

Berkas di folder ini menggantikan layar putih yang muncul saat aplikasi
pertama kali dibuka. Semuanya sudah jadi; tidak ada yang perlu digambar lagi.

**Dikerjakan desainer, dipasang programmer.** Folder `android/`, `ios/`, dan
`web/` berada di luar batas worktree desain, dan worktree sebelah sedang aktif
membangun Dasbor web — dua orang mengubah `web/index.html` bersamaan membuat
pekerjaan salah satunya hilang tanpa pesan galat apa pun.

---

## Masalahnya ada tiga, bukan satu

Gejalanya sama — layar putih — tetapi sebabnya berbeda di tiap tempat.

| Di mana | Sebab | Keadaan sebelum |
|---|---|---|
| Android | Layar peluncur diatur putih polos | `launch_background.xml` isinya `@android:color/white` |
| iOS | Gambar peluncurnya kosong | `LaunchImage.png` berukuran **1 × 1 piksel** warna putih |
| Web | `<body>` benar-benar kosong sampai Flutter selesai dimuat | isinya hanya `<script src="flutter_bootstrap.js" async>` |

Yang paling merugikan versi web. Bundelnya 4,3 MB, jadi di sinyal gudang yang
jelek calon pengguna menatap layar putih belasan detik tanpa tanda apa pun
bahwa sesuatu sedang berjalan. Sebagian menutup tabnya sebelum aplikasinya
sempat muncul.

---

## Rancangannya

Lambang KamelScan di dalam kotak membulat putih, dengan tulisan **KamelScan**
di bawahnya.

**Kenapa lambangnya dibungkus kotak putih.** Huruf K pada logo berwarna navy
`#001B4A`. Di atas latar gelap ia praktis hilang, dan di atas biru resmi
`#0D5EA6` pun nyaris tak terbaca. Dengan dibungkus kotak putih, lambangnya
selalu duduk di atas putih — jadi ia terbaca pada mode terang maupun gelap,
**dan logo aslinya tidak perlu diubah warnanya sama sekali.**

**Kenapa latar terangnya bukan putih.** Kotaknya putih; kalau latarnya juga
putih, kotak itu lenyap dan yang tampak hanya lambang melayang. Latarnya
memakai `#F2F5F9`, yaitu warna latar halaman di dalam aplikasi — jadi
peralihan dari layar peluncur ke aplikasi tidak terasa berkedip.

| | Latar | Tulisan |
|---|---|---|
| Mode terang | `#F2F5F9` surfaceContainer | `#101828` onSurface |
| Mode gelap | `#0F141A` surface gelap | `#E6EDF5` onSurface gelap |

Latar gelapnya bukan hitam murni, alasannya sama seperti di palet: hitam murni
pada layar OLED menghasilkan kontras terlalu keras dan efek *smearing*.

---

## 1. Android

Salin seluruh isi `android/res/` ke `android/app/src/main/res/`, menimpa yang
ada. Berkas yang terlibat:

```
res/drawable/launch_background.xml          diganti
res/drawable-v21/launch_background.xml      diganti   ← lihat peringatan
res/drawable-night/launch_background.xml    baru
res/values/colors.xml                       baru
res/values/styles.xml                       diganti
res/values-night/colors.xml                 baru
res/values-night/styles.xml                 diganti
res/drawable-{mdpi…xxxhdpi}/splash_logo.png             baru, 5 berkas
res/drawable-night-{mdpi…xxxhdpi}/splash_logo.png       baru, 5 berkas
```

> ### 🔴 Jangan lewatkan `drawable-v21`
>
> Proyek ini punya **dua** berkas `launch_background.xml`: satu di `drawable/`
> dan satu lagi di `drawable-v21/`. Android memilih `drawable-v21` lebih dulu
> pada setiap perangkat Android 5.0 ke atas — yaitu praktis semua perangkat
> yang beredar.
>
> Kalau hanya `drawable/launch_background.xml` yang diganti, berkas lama di
> `drawable-v21` tetap yang dipakai dan **layar putihnya tidak berubah sedikit
> pun.** Perbaikannya akan terlihat seperti gagal padahal berkasnya sudah
> benar. Isi kedua berkas itu sengaja dibuat sama persis.

Ada satu perubahan lagi di `values/styles.xml` dan `values-night/styles.xml`
yang mudah terlewat karena tampak sepele:

```xml
<!-- sebelum -->
<item name="android:windowBackground">?android:colorBackground</item>
<!-- sesudah -->
<item name="android:windowBackground">@color/splash_background</item>
```

`NormalTheme` inilah yang menentukan warna jendela pada celah antara layar
peluncur menghilang dan bingkai pertama Flutter tergambar. Selama nilainya
masih `?android:colorBackground`, akan tetap ada kilatan putih singkat di
celah itu meskipun layar peluncurnya sendiri sudah benar.

---

## 2. iOS

Salin isi `ios/LaunchImage.imageset/` ke
`ios/Runner/Assets.xcassets/LaunchImage.imageset/`, menimpa ketiga berkas PNG
yang ada. `Contents.json` tidak perlu diubah — namanya sudah cocok.

Lalu ubah warna latar pada `ios/Runner/Base.lproj/LaunchScreen.storyboard`.
Saat ini masih putih:

```xml
<color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
```

Ganti menjadi `#F2F5F9`:

```xml
<color key="backgroundColor" red="0.94901961" green="0.96078431" blue="0.97647059" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
```

> ### ⚠️ Keterbatasan yang jujur: iOS tidak ikut mode gelap
>
> Storyboard memakai satu warna tetap, jadi layar peluncur iOS akan tetap
> terang meskipun HP-nya sedang mode gelap. Akibatnya ada kilatan terang
> sesaat sebelum aplikasi gelapnya muncul.
>
> Memperbaikinya berarti membuat *color set* di Assets.xcassets yang punya
> varian gelap, lalu menunjuk storyboard ke color set itu — dan itu paling
> mudah dikerjakan lewat Xcode, bukan lewat penyuntingan berkas. Bukan
> penghalang rilis, tetapi jangan dikira terlupa.

---

## 3. Web

Buka `desain/splash/web/potongan-index.html`. Isinya dua blok:

1. Blok `<style>` — sisipkan ke dalam `<head>` pada `web/index.html`.
2. Blok kedua — **ganti** seluruh isi `<body>` dengan ini. Baris
   `<script src="flutter_bootstrap.js" async></script>` sudah termasuk di
   dalamnya, jadi jangan ditulis dua kali.

🔴 **Jangan sentuh baris `<base href="$FLUTTER_BASE_HREF">`.** Berkas itu
sudah memuat peringatannya sendiri: menuliskannya sebagai `/app/` akan
membuat `flutter run -d chrome` berakhir layar putih — masalah yang persis
sedang kita perbaiki.

Tiga hal yang perlu diketahui tentang potongan itu:

- **Logonya ditanam sebagai data-URI, bukan berkas terpisah.** Berkas
  terpisah berarti satu permintaan jaringan lagi, dan di sinyal buruk
  permintaan itu sendiri bisa gagal — sehingga layar peluncurnya ikut kosong,
  persis masalah yang sedang diperbaiki. Ukurannya 9 KB.

- **Tidak memerlukan perubahan apa pun di `lib/`.** Penghilangan layar
  peluncur memakai `MutationObserver` yang menunggu Flutter menggambar
  bingkai pertamanya, bukan panggilan dari sisi Dart. Jadi potongan ini tidak
  bersinggungan dengan pekerjaan worktree sebelah.

- **Setelah 8 detik kalimatnya berubah** menjadi *"Koneksi sedang lambat,
  mohon tunggu…"*. Diam belasan detik membuat orang mengira halamannya rusak.

- **Ada jaring pengaman 20 detik.** Bila nama elemen Flutter berubah di versi
  berikutnya, `MutationObserver` tidak akan pernah cocok — dan tanpa jaring
  itu layar peluncur akan menutupi aplikasi selamanya. Cacat yang jauh lebih
  parah daripada layar putih. Jangan dihapus.

---

## Cara memeriksa hasilnya

| Yang diuji | Caranya | Yang benar |
|---|---|---|
| Android terang | Buka aplikasi dari keadaan mati total | Logo di latar abu sangat muda, tanpa kilatan putih |
| Android gelap | Nyalakan mode gelap HP, ulangi | Logo di latar gelap `#0F141A` |
| Android — jebakan v21 | Kalau masih putih | `drawable-v21` belum ikut diganti |
| iOS | Buka dari keadaan mati total | Logo di latar abu sangat muda |
| Web cepat | Buka `/app/` | Logo muncul seketika, lalu hilang melembut |
| Web lambat | DevTools → Network → throttling **Slow 3G** | Logo + bilah bergerak; setelah 8 detik kalimatnya berubah |
| Web — jaring pengaman | Biarkan gagal memuat | Layar peluncur tetap hilang setelah 20 detik |

⚠️ Sesudah menerbitkan web, tekan **Ctrl + Shift + R**. Chrome menyajikan
versi lama dari simpanannya, dan jebakan ini sudah pernah memakan satu ronde
penuh di proyek ini.

---

## Ukuran yang ditambahkan

| | Besarnya |
|---|---|
| Android, 10 berkas PNG | 106 KB |
| iOS, 3 berkas PNG | 27 KB |
| Web, tertanam di dalam HTML | 9 KB |

Aslinya 678 KB sebelum dipadatkan; gambarnya tidak berubah.
