/* ==========================================================================
   KamelScan — landing page
   JavaScript seperlunya saja. Halaman ini harus tetap terbaca seluruhnya
   walaupun berkas ini gagal dimuat — tidak ada satu pun teks yang dirakit
   oleh JS.
   ========================================================================== */
(function () {
  'use strict';

  /* ---------------------------------------------------------------------
     Laci menu untuk layar sempit (< 900 px)
     --------------------------------------------------------------------- */
  var tombol = document.getElementById('laci-tombol');
  var laci = document.getElementById('laci');

  if (tombol && laci) {
    tombol.addEventListener('click', function () {
      var terbuka = laci.classList.toggle('buka');
      tombol.setAttribute('aria-expanded', String(terbuka));
      tombol.setAttribute('aria-label', terbuka ? 'Tutup menu' : 'Buka menu');
    });

    // Tutup laci setelah salah satu tautannya dipilih.
    laci.addEventListener('click', function (e) {
      if (e.target.closest('a')) {
        laci.classList.remove('buka');
        tombol.setAttribute('aria-expanded', 'false');
        tombol.setAttribute('aria-label', 'Buka menu');
      }
    });

    // Esc menutup laci dan mengembalikan fokus ke tombolnya.
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && laci.classList.contains('buka')) {
        laci.classList.remove('buka');
        tombol.setAttribute('aria-expanded', 'false');
        tombol.focus();
      }
    });
  }

  /* ---------------------------------------------------------------------
     Tahun berjalan di footer
     --------------------------------------------------------------------- */
  var tahun = document.getElementById('tahun');
  if (tahun) tahun.textContent = String(new Date().getFullYear());

  /* ---------------------------------------------------------------------
     Pengalih bahasa ID / EN
     ---------------------------------------------------------------------
     Bahasa Indonesia adalah sumber kebenaran dan ditulis langsung di dalam
     index.html — jadi halaman tetap utuh walaupun berkas ini gagal dimuat.
     Kamus di bawah hanya berisi terjemahan bahasa Inggris.

     🔴 BAWAANNYA INDONESIA, bukan bahasa peramban. Halaman /v/{token} pernah
     mengikuti navigator.language dan pada 25 Agustus 2026 terbukti menyajikan
     bahasa Inggris kepada Product Owner sendiri, karena Chrome-nya berbahasa
     Inggris seperti kebanyakan komputer di Indonesia. Kesalahan yang sama
     tidak diulang di sini.

     ⚠️ SETIAP MENAMBAH data-i18n DI index.html, TAMBAH JUGA DI SINI.
     Kunci yang ada di halaman tapi tidak ada di kamus akan tetap berbahasa
     Indonesia saat tombol EN ditekan — halaman jadi setengah-setengah, dan
     tidak ada yang memberi tahu Anda. Cara memeriksanya tanpa membaca satu
     per satu, jalankan dari akar worktree:

         python - <<'EOF'
         import re
         h = set(re.findall(r'data-i18n="([^"]+)"', open("landing/index.html", encoding="utf-8").read()))
         j = set(re.findall(r'^    "([^"]+)":', open("landing/app.js", encoding="utf-8").read(), re.M))
         print("belum diterjemahkan:", sorted(h - j) or "tidak ada")
         print("kamus tak terpakai :", sorted(j - h) or "tidak ada")
         EOF

     Tombolnya muncul sendiri selama kamus ini tidak kosong.

     Angka harga sengaja ikut diterjemahkan: pembaca Inggris membaca
     "Rp 99.000" sebagai sembilan puluh sembilan koma nol, jadi di kamus
     ditulis "Rp 99,000".
     --------------------------------------------------------------------- */
  var EN = {
    "meta.judul": "KamelScan — Video proof of every parcel, recorded the moment the tracking number is scanned",
    "nav.lompat": "Skip to main content",
    "nav.fitur": "Features",
    "nav.harga": "Pricing",
    "nav.tutorial": "Tutorial",
    "nav.kontak": "Contact",
    "nav.masuk": "Sign in",
    "nav.daftar": "Sign Up Free",
    "hero.judul": "Video proof of every parcel, recorded the moment the tracking number is scanned.",
    "hero.sub": "Your packer just scans the tracking number. KamelScan records the packing itself, stamps the tracking number, time, store name and location into the video, then keeps it in the cloud. When a buyer claims the parcel arrived empty, the proof is already there — you just send it.",
    "hero.cta1": "Try 100 Videos Free",
    "hero.cta2": "See How It Works",
    "hero.catatan": "No credit card. No time limit — the limit is the number of videos, not the days.",
    "hero.poin1": "Triggered by QR, barcode, or typed by hand",
    "hero.poin2": "Keeps working when the warehouse signal drops",
    "hero.poin3": "Share by link, downloadable too",
    "masalah.kicker": "Why it matters",
    "masalah.judul": "Four things quietly eating an online store's margin",
    "masalah.sub": "It is not about how carefully you pack. It is about whether you can prove it when asked.",
    "masalah.k1.judul": "“The parcel was empty when I got it”",
    "masalah.k1.isi": "A one-sided claim from the buyer. Without a recording, the marketplace resolution centre only has one version of the story — and it is not yours.",
    "masalah.k1.solusi": "<b>The fix:</b> a packing video watermarked with the tracking number, server time, store name and location coordinates.",
    "masalah.k2.judul": "One recording, a whole afternoon to find it",
    "masalah.k2.isi": "If you have been recording by hand and keeping the files in a phone gallery, finding one parcel's video means scrolling through hundreds of unnamed files.",
    "masalah.k2.solusi": "<b>The fix:</b> type the tracking number, and the video comes straight up.",
    "masalah.k3.judul": "Warehouse signal comes and goes",
    "masalah.k3.isi": "Warehouses are often walled in concrete or steel sheeting. An app that needs a constant connection will fail exactly during the busiest hours.",
    "masalah.k3.solusi": "<b>The fix:</b> the recording is held on the phone first, then uploads itself as soon as the signal returns.",
    "masalah.k4.judul": "Record by hand, fill the phone up fast",
    "masalah.k4.isi": "Recording with the built-in camera produces large files. A few hundred parcels is enough to fill a packer's phone, and when the file finally has to reach the resolution centre it is often too big to attach.",
    "masalah.k4.solusi": "<b>The fix:</b> every video is recorded at a deliberately compact size and kept in the cloud instead of piling up on the phone. All you send is the link — and whoever opens it can still download the file if they ask for it.",
    "cara.kicker": "How it works",
    "cara.judul": "Four steps, and your packer only does the first one",
    "cara.sub": "The rest runs by itself in the background.",
    "cara.l1.judul": "Scan the tracking number",
    "cara.l1.isi": "Point the camera at the QR code or barcode on the shipping label. Not readable? The number can be typed by hand.",
    "cara.l2.judul": "Recording starts on its own",
    "cara.l2.isi": "It stops automatically at the time limit, or when the next tracking number is scanned. No button anyone can forget to press.",
    "cara.l3.judul": "Watermarked and uploaded",
    "cara.l3.isi": "The tracking number, server time, store name and coordinates are burned into the video image, then sent to the cloud once there is signal.",
    "cara.l4.judul": "Share or download",
    "cara.l4.isi": "One link the marketplace resolution centre can open without an account and without installing anything. That page carries a download button, so they can save the video file themselves if it is asked for as an attachment. You can download it from the app at any time as well.",
    "unduh.lencana": "Coming soon",
    "unduh.judul": "The phone app that does the recording",
    "unduh.isi": "Recording can only be done from a phone — the web version does not record. The Android and iOS apps are on their way. In the meantime you can already sign up and set your store up from a browser.",
    "unduh.play": "Google Play — soon",
    "unduh.ios": "App Store — soon",
    "unduh.cta": "Sign up in your browser",
    "harga.kicker": "Pricing",
    "harga.judul": "Pay monthly, stop whenever you like",
    "harga.sub": "One video uploaded successfully uses one token.",
    "harga.trial.judul": "Start with 100 free videos",
    "harga.trial.isi": "Given automatically when you sign up, once per account. No time limit — the limit is the number of videos, not the number of days. Features match the Standard plan.",
    "harga.trial.cta": "Take the free trial",
    "harga.standar.nama": "Standard",
    "harga.standar.harga": "Rp 99,000",
    "harga.perbulan": "/ month",
    "harga.standar.untuk": "For a store run single-handed or by a small team.",
    "harga.standar.f1": "<b>1,000 videos</b> per month",
    "harga.standar.f2": "Up to <b>30 seconds</b> per video",
    "harga.standar.f3": "Videos kept for <b>30 days</b>",
    "harga.standar.f4": "Up to <b>5 packer accounts</b>",
    "harga.standar.f5": "Unlimited stores",
    "harga.standar.f6": "Public link for sharing proof",
    "harga.standar.f7": "Watermark uses your store name as text",
    "harga.standar.cta": "Choose Standard",
    "harga.pro.label": "Most complete",
    "harga.pro.nama": "Pro",
    "harga.pro.harga": "Rp 249,000",
    "harga.pro.untuk": "For warehouses with many packers and high shipping volume.",
    "harga.pro.f1": "<b>5,000 videos</b> per month",
    "harga.pro.f2": "Up to <b>60 seconds</b> per video",
    "harga.pro.f3": "Videos kept for <b>60 days</b>",
    "harga.pro.f4": "<b>Unlimited</b> packer accounts",
    "harga.pro.f5": "Unlimited stores",
    "harga.pro.f6": "Public link for sharing proof",
    "harga.pro.f7": "<b>Your own store logo</b> as watermark",
    "harga.pro.cta": "Choose Pro",
    "harga.retensi": "<b>Videos are deleted automatically once their storage period ends</b> — 30 days on Standard, 60 days on Pro, counted from the moment they were recorded. This is part of how the service works, not a fault. Download anything you want to keep longer before its deadline.",
    "tutorial.kicker": "Tutorial",
    "tutorial.judul": "Learn your way around it in ten minutes",
    "tutorial.sub": "Step-by-step guides for setting up your store, creating packer accounts, and recording your first parcel.",
    "tutorial.cta": "Open the Tutorial page",
    "kontak.kicker": "Contact",
    "kontak.judul": "Something you want to ask first?",
    "kontak.sub": "We reply during working hours.",
    "kontak.wa.judul": "WhatsApp",
    "kontak.wa.isi": "The fastest route, answered during working hours.",
    "kontak.email.judul": "Email",
    "kontak.email.isi": "For longer questions, quotes, or attachments.",
    "kontak.jam.judul": "Working hours",
    "kontak.jam.nilai": "Monday&ndash;Friday, 09.00&ndash;17.00 WIB (GMT+7)",
    "kontak.jam.isi": "Messages arriving outside these hours are answered on the next working day.",
    "penutup.judul": "The next parcel you send could already have its proof",
    "penutup.sub": "Sign up now and get 100 free videos. No credit card, and no deadline for using them.",
    "penutup.cta1": "Sign Up Free",
    "penutup.cta2": "I already have an account",
    "kaki.tagline": "Automatic packing proof for online sellers in Indonesia.",
    "kaki.produk": "Product",
    "kaki.legal": "Legal",
    "kaki.snk": "Terms &amp; Conditions",
    "kaki.privasi": "Privacy Policy",
    "kaki.dibuat": "Built for warehouses where the signal is poor.",
  };

  var alih = document.getElementById('alih-bahasa');
  var elemen = Array.prototype.slice.call(document.querySelectorAll('[data-i18n]'));

  // Simpan teks Indonesia apa adanya supaya bisa dikembalikan tanpa memuat ulang.
  var ID = elemen.map(function (el) { return el.innerHTML; });

  function pakai(bahasa) {
    elemen.forEach(function (el, i) {
      if (bahasa === 'en') {
        var t = EN[el.getAttribute('data-i18n')];
        if (t) el.innerHTML = t;
      } else {
        el.innerHTML = ID[i];
      }
    });
    document.documentElement.lang = bahasa;
    if (alih) alih.textContent = bahasa === 'en' ? 'ID' : 'EN';
  }

  if (alih && Object.keys(EN).length > 0) {
    alih.hidden = false;
    alih.addEventListener('click', function () {
      pakai(document.documentElement.lang === 'en' ? 'id' : 'en');
    });
  }
})();


/* =========================================================================
 * Spanduk landing page dari `platform_settings.banner_landing` (Bab 10.2)
 * =========================================================================
 *
 * 🔴 Ini SATU-SATUNYA panggilan jaringan di seluruh landing page, dan ia
 * sengaja dibuat tidak memblokir apa pun.
 *
 * Sampai 4 September 2026 halaman ini nol panggilan jaringan — keputusan
 * sadar, karena calon pelanggan membukanya dari gudang bersinyal buruk.
 * Keputusan itu TIDAK dibatalkan: ilustrasi SVG tetap tergambar seketika,
 * dan gambar dari server hanya menggantikannya kalau benar-benar sampai.
 *
 * Product Owner memilih bentuk ini 4 September 2026, sesudah menemukan bahwa
 * halaman Admin "Gambar iklan" menyimpan alamat spanduk yang tidak pernah
 * dibaca siapa pun — layar yang menjanjikan sesuatu yang tidak terjadi.
 *
 * ⚠️ Kredensialnya DISUNTIKKAN `deploy_web.ps1`, bukan ditulis di berkas ini:
 * `landing/` masuk git, `env.dev.json` tidak. Kunci anon memang kunci publik
 * (ia sudah ada di dalam `main.dart.js` yang dapat diunduh siapa saja),
 * tetapi tetap tidak dituliskan ke dalam repositori — aturan yang sama sudah
 * dipakai halaman bukti publik `/v/`.
 *
 * Bila penandanya belum tergantikan — misalnya saat berkas ini dibuka
 * langsung dari cakram untuk memeriksa tata letak — fungsinya berhenti diam
 * dan halaman tetap memakai ilustrasinya. Itu jalur normal, bukan galat.
 */
(function spanduk() {
  var URL_SB = '__SUPABASE_URL__';
  var KUNCI = '__SUPABASE_ANON_KEY__';

  // Penanda belum disuntik: dibuka dari cakram, bukan dari situs terbit.
  //
  // 🔴 Diperiksa dari BENTUKNYA — diawali garis bawah — dan bukan dengan
  // menuliskan penandanya kembali di sini.
  //
  // Alasannya terbukti 4 September 2026: versi pertama menyebut penandanya
  // apa adanya, teks itu ikut tertinggal di berkas terbit, dan penjaga di
  // `deploy_web.ps1` menghentikan penerbitan karena mengira penyuntikannya
  // gagal. Penjaga yang menghasilkan alarm palsu akan berhenti dipercaya.
  if (URL_SB.charAt(0) === '_' || KUNCI.charAt(0) === '_') return;

  var wadah = document.getElementById('hero-gambar');
  if (!wadah) return;

  var alamat = URL_SB.replace(/\/+$/, '') +
    '/rest/v1/platform_settings?select=value&key=eq.banner_landing';

  fetch(alamat, {
    headers: { apikey: KUNCI, Authorization: 'Bearer ' + KUNCI },
  })
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (baris) {
      if (!baris || !baris.length) return;
      var nilai = baris[0] && baris[0].value;
      var url = nilai && nilai.image_url;
      if (!url) return;

      // 🔴 Gambarnya dimuat DI LUAR halaman lebih dulu. Menempelkan <img>
      // langsung ke DOM berarti ilustrasinya lenyap saat itu juga, lalu
      // digantikan kotak kosong selama gambarnya masih diunduh — dan pada
      // sinyal buruk kotak kosong itu bisa bertahan lama sekali.
      var img = new Image();
      img.onload = function () {
        img.className = 'hero-foto';
        img.alt = (nilai.headline || '').trim() ||
          'Ilustrasi aplikasi KamelScan';
        wadah.innerHTML = '';
        wadah.appendChild(img);
      };
      // Gagal muat: tidak melakukan apa-apa. Ilustrasinya tetap berdiri.
      img.src = url;
    })
    .catch(function () {
      /* Sengaja diam. Halaman ini harus tetap utuh tanpa jaringan. */
    });
})();
