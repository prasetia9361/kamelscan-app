import 'package:flutter_test/flutter_test.dart';

import 'package:kamelscan/core/models/announcement.dart';
import 'package:kamelscan/core/models/enums.dart';

/// Aturan iklan & pengumuman (migrasi 50), diminta Product Owner 5 September
/// 2026.
///
/// 🔴 Seluruh aturan yang menentukan **siapa melihat apa** dan **apa yang
/// mengunci** hidup di model, bukan di layar, supaya dapat diperiksa tanpa
/// basis data dan tanpa satu piksel pun. Kekeliruan di lapisan ini tidak
/// menimbulkan galat: ia hanya membuat pengumuman tidak sampai kepada siapa
/// pun — atau, ke arah sebaliknya, mengunci orang yang tidak dimaksud.
void main() {
  Announcement buat({
    String id = 'a1',
    AnnouncementKind kind = AnnouncementKind.normal,
    AnnouncementAudience audience = AnnouncementAudience.all,
    String? actionUrl,
    DateTime? createdAt,
  }) =>
      Announcement(
        id: id,
        title: 'Judul',
        kind: kind,
        audience: audience,
        actionUrl: actionUrl,
        createdAt: createdAt,
      );

  group('Sasaran', () {
    test('"semua" mencakup owner dan packer', () {
      final a = buat();
      expect(a.untuk(UserRole.owner), isTrue);
      expect(a.untuk(UserRole.packer), isTrue);
    });

    test('🔴 "semua" TIDAK mencakup admin', () {
      // Yang menulis pengumuman tidak perlu diberi tahu isinya sendiri, dan
      // panel admin berdiri di luar kedua rangka yang menampilkannya. Kalau
      // baris ini gagal, admin akan melihat dialog di layar yang tidak punya
      // tempat untuknya.
      expect(buat().untuk(UserRole.admin), isFalse);
    });

    test('sesi yang belum terbaca tidak melihat apa pun', () {
      expect(buat().untuk(null), isFalse);
    });

    test('"owner" hanya owner', () {
      final a = buat(audience: AnnouncementAudience.owner);
      expect(a.untuk(UserRole.owner), isTrue);
      expect(a.untuk(UserRole.packer), isFalse);
    });

    test('"packer" hanya packer', () {
      final a = buat(audience: AnnouncementAudience.packer);
      expect(a.untuk(UserRole.packer), isTrue);
      expect(a.untuk(UserRole.owner), isFalse);
    });
  });

  group('Nilai yang tidak dikenal jatuh ke arah yang aman', () {
    test('🔴 jenis tak dikenal menjadi "biasa", bukan "penting"', () {
      // Arah jatuhannya menentukan apa yang terjadi pada aplikasi lama saat
      // jenis baru ditambahkan: yang benar membiarkan orang masuk. Jatuhan
      // sebaliknya mengunci seluruh pengguna versi lama dari sesuatu yang
      // bahkan tidak dimaksudkan mengunci mereka — dan mereka tidak dapat
      // memberi tahu kita, karena aplikasinya tidak bisa dibuka.
      expect(AnnouncementKind.fromWire('gawat'), AnnouncementKind.normal);
      expect(AnnouncementKind.fromWire(null), AnnouncementKind.normal);
      expect(
        AnnouncementKind.fromWire('important'),
        AnnouncementKind.important,
      );
    });

    test('sasaran tak dikenal menjadi "semua"', () {
      // Kebalikannya, dan alasannya juga kebalikannya: pengumuman yang salah
      // sasaran hanya mengganggu, sedangkan yang tidak sampai kepada siapa pun
      // sama saja dengan tidak pernah ditulis.
      expect(
        AnnouncementAudience.fromWire('semua'),
        AnnouncementAudience.all,
      );
      expect(
        AnnouncementAudience.fromWire('packer'),
        AnnouncementAudience.packer,
      );
    });
  });

  group('Tautan aksi', () {
    test('kosong berarti tidak ada tombol', () {
      expect(buat(actionUrl: null).punyaAksi, isFalse);
      expect(buat(actionUrl: '   ').punyaAksi, isFalse);
    });

    test('🔴 teks yang bukan alamat ditolak', () {
      // Inilah yang memisahkan "pengumuman wajib update" dari "seluruh
      // pelanggan terkurung": tombol satu-satunya yang alamatnya tidak dapat
      // dibuka. Formulir Admin memakai pemeriksaan yang sama sebelum
      // menyimpan.
      expect(buat(actionUrl: 'play store').punyaAksi, isFalse);
      expect(buat(actionUrl: 'www.google.com').punyaAksi, isFalse);
    });

    test('alamat lengkap diterima', () {
      expect(
        buat(actionUrl: 'https://play.google.com/store/apps/details?id=x')
            .punyaAksi,
        isTrue,
      );
    });
  });

  group('Urutan tampil', () {
    test('🔴 yang mengunci selalu lebih dulu', () {
      // Kalau pengumuman event tampil lebih dulu, pengguna menutupnya, lalu
      // baru bertemu layar "wajib update" — ia sudah menutup sesuatu yang
      // tidak pernah sempat dibacanya, dan penutupannya terlanjur dicatat.
      final penting = buat(
        id: 'penting',
        kind: AnnouncementKind.important,
        createdAt: DateTime(2026, 1, 1),
      );
      final biasa = buat(id: 'biasa', createdAt: DateTime(2026, 9, 1));

      final daftar = [biasa, penting]..sort(Announcement.urutkan);
      expect(daftar.first.id, 'penting');
    });

    test('sesama jenis, yang terbaru lebih dulu', () {
      final lama = buat(id: 'lama', createdAt: DateTime(2026, 1, 1));
      final baru = buat(id: 'baru', createdAt: DateTime(2026, 9, 1));

      final daftar = [lama, baru]..sort(Announcement.urutkan);
      expect(daftar.map((e) => e.id), ['baru', 'lama']);
    });
  });

  group('Membaca baris database', () {
    test('baris lengkap terbaca utuh', () {
      final a = Announcement.fromJson({
        'id': 'x1',
        'title': 'Perawatan server',
        'body': 'Minggu, 07.00–09.00',
        'image_url': 'https://contoh/x.jpg',
        'kind': 'normal',
        'audience': 'owner',
        'action_url': 'https://contoh/info',
        'action_label': 'Selengkapnya',
        'is_active': true,
        'created_at': '2026-09-05T10:00:00Z',
      });

      expect(a.title, 'Perawatan server');
      expect(a.audience, AnnouncementAudience.owner);
      expect(a.punyaGambar, isTrue);
      expect(a.punyaAksi, isTrue);
      expect(a.mengunci, isFalse);
      expect(a.createdAt, isNotNull);
    });

    test('kolom yang hilang tidak menjatuhkan pembacaannya', () {
      // Baris yang disunting tangan lewat Supabase Dashboard bisa saja begini.
      final a = Announcement.fromJson({'id': 'x2', 'title': 'Halo'});

      expect(a.body, '');
      expect(a.punyaGambar, isFalse);
      expect(a.punyaAksi, isFalse);
      expect(a.kind, AnnouncementKind.normal);
      expect(a.audience, AnnouncementAudience.all);
      expect(a.isActive, isTrue);
    });
  });
}
