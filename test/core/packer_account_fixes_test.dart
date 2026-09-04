import 'package:flutter_test/flutter_test.dart';
import 'package:kamelscan/core/config/tier_config.dart';
import 'package:kamelscan/core/models/app_user.dart';
import 'package:kamelscan/core/models/enums.dart';
import 'package:kamelscan/core/services/supabase_service.dart';
import 'package:kamelscan/core/utils/app_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tiga cacat akun packer yang dilaporkan 31 Agustus 2026 (Bab 6.7).
///
/// 🔴 Ketiganya punya bentuk yang sama, dan bentuk itulah yang paling mahal di
/// proyek ini: **Owner menekan tombol, layarnya berubah seolah berhasil, dan
/// yang dijanjikan tombol itu tidak pernah terjadi.** Tidak satu pun dari
/// ketiganya pernah memunculkan galat — sama persis dengan cacat
/// `delete-packer` 20 Agustus (P.2).
void main() {
  AppUser packer({required bool aktif}) => AppUser(
    id: 'p${aktif ? 1 : 2}',
    tenantId: 't1',
    email: 'p@contoh.com',
    fullName: 'Packer',
    role: UserRole.packer,
    isActive: aktif,
  );

  group('Batas packer menghitung yang AKTIF saja', () {
    // Aturan servernya sudah benar sejak awal: `create-packer` dan trigger
    // `PACKER_LIMIT_REACHED` keduanya menyaring `is_active`. Yang salah adalah
    // layarnya, yang memakai panjang daftar apa adanya.
    //
    // 🔴 Dipakai konfigurasi MASA UJI COBA, bukan paket Standar. Sejak
    // 31 Agustus 2026 ketiga paket berbayar tak terbatas packer-nya, sehingga
    // masa uji coba adalah satu-satunya tempat batas ini masih menggigit —
    // dan satu-satunya tempat cacat hitungannya masih dapat merugikan orang.
    // Menyusun ulang tesnya di atas paket Standar akan membuatnya lulus
    // selamanya tanpa menguji apa pun.
    const catalog = TierCatalog.fallback;
    final ujiCoba = catalog
        .of(catalog.trial.tier)
        .copyWith(maxPackers: catalog.trial.maxPackers);

    int terpakai(List<AppUser> daftar) =>
        daftar.where((u) => u.isActive).length;

    test('packer nonaktif tidak memakai kursi', () {
      // Keadaan Sarang sarung, 31 Agustus 2026: 3 aktif + 2 nonaktif dari
      // batas 5. Layarnya berkata "5/5" dan mematikan tombol Tambah, padahal
      // server menerima dua lagi tanpa keberatan.
      final daftar = [
        packer(aktif: true),
        packer(aktif: true),
        packer(aktif: true),
        packer(aktif: false),
        packer(aktif: false),
      ];

      expect(terpakai(daftar), 3);
      expect(
        ujiCoba.canAddPacker(terpakai(daftar)),
        isTrue,
        reason: 'masih ada 2 kursi kosong; tombol Tambah tidak boleh mati',
      );

      // Inilah hitungan lamanya, dan inilah yang salah.
      expect(ujiCoba.canAddPacker(daftar.length), isFalse);
    });

    test('batasnya tetap ditegakkan saat semuanya aktif', () {
      final penuh = List.generate(5, (_) => packer(aktif: true));

      expect(terpakai(penuh), 5);
      expect(ujiCoba.canAddPacker(terpakai(penuh)), isFalse);
    });

    test('seluruh paket berbayar tidak terbatas', () {
      for (final plan in TierPlan.values) {
        final tier = TierCatalog.fallback.of(plan);
        expect(
          tier.hasUnlimitedPackers,
          isTrue,
          reason: '$plan seharusnya tak terbatas sejak 31 Agustus 2026',
        );
        expect(tier.canAddPacker(999), isTrue);
      }
    });
  });

  group('Akun yang dinonaktifkan punya kalimatnya sendiri', () {
    // 🔴 `errorAccountDisabled` sudah ada di ARB sejak awal dan tidak pernah
    // sekali pun ditampilkan: tidak ada satu baris pun yang membaca
    // `is_active` di jalur masuk maupun jalur rekam.
    //
    // Penjagaan di aplikasi saja tidak cukup dan tidak boleh dianggap cukup —
    // JWT packer yang baru dinonaktifkan masih sah sampai kedaluwarsa, dan
    // pemegangnya dapat memanggil PostgREST langsung tanpa pernah membuka
    // aplikasinya. Penegakannya ada di `before_video_insert()` (migrasi 38);
    // yang diuji di sini adalah bahwa penolakannya sampai ke layar sebagai
    // kalimat yang benar, bukan "Terjadi kesalahan".
    test('ACCOUNT_DISABLED dari Edge Function', () {
      final failure = SupabaseService.mapError(
        const FunctionsHttpException(
          status: 403,
          details: {'error': 'ACCOUNT_DISABLED'},
        ),
      );

      expect(failure.messageKey, 'errorAccountDisabled');
      expect(failure.messageKey, isNot('errorUnknown'));
      expect(failure.kind, FailureKind.permission);
    });

    test('ACCOUNT_DISABLED dari trigger database', () {
      // Trigger mengangkatnya sebagai exception Postgres, jadi kodenya tiba di
      // dalam PESAN — jalur yang berbeda dari Edge Function, dan yang mudah
      // terlewat karena keduanya harus diperbaiki terpisah.
      final failure = SupabaseService.mapError(
        const PostgrestException(message: 'ACCOUNT_DISABLED', code: 'P0005'),
      );

      expect(failure.messageKey, 'errorAccountDisabled');
      expect(failure.messageKey, isNot('errorUnknown'));
    });

    test('tidak tertukar dengan langganan yang berakhir', () {
      // Keduanya sama-sama mengunci, tetapi jalan keluarnya berlawanan: yang
      // satu harus menghubungi Owner, yang satu harus membayar. Kalimat yang
      // tertukar mengirim orang ke tempat yang salah.
      final nonaktif = SupabaseService.mapError(
        const PostgrestException(message: 'ACCOUNT_DISABLED', code: 'P0005'),
      );
      final langganan = SupabaseService.mapError(
        const PostgrestException(
          message: 'SUBSCRIPTION_INACTIVE',
          code: 'P0003',
        ),
      );

      expect(nonaktif.messageKey, isNot(langganan.messageKey));
    });
  });
}
