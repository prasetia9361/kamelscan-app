import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kamelscan/core/models/announcement.dart';
import 'package:kamelscan/pages/admin/settings/admin_settings_view_model.dart';

/// `UnmountedRefException` saat menyimpan pengumuman — dilaporkan Sentry
/// 5 September 2026, level **fatal**, di HP Product Owner (Redmi Note 9).
///
/// ```
/// admin_announcements_page.dart:51   _sunting   -> Simpan ditekan
/// admin_settings_view_model.dart:586 simpan     -> tersimpan, lalu
/// admin_settings_view_model.dart:533 refresh    -> muat ulang daftarnya
/// ref.dart:343 invalidateSelf                   -> providernya sudah mati
/// ```
///
/// 🔴 Sebabnya bukan penyimpanannya, melainkan **jarak waktu di dalamnya**.
/// `simpan` menunggu dua sampai tiga perjalanan ke server — menulis baris,
/// mengunggah gambar, menulis alamatnya — dan selama itu providernya dapat
/// dibangun ulang (ia `ref.watch(sessionProvider)`) atau dibuang karena tidak
/// ada lagi yang menyimaknya. Notifier yang sedang menjalankan `simpan` ikut
/// dibuang bersamanya, lalu `refresh()` menyentuh `ref` yang sudah mati.
///
/// ⚠️ Kenapa ini tidak pernah tertangkap sebelumnya: seluruh tes yang ada
/// memanggil `simpan` pada provider yang hidup dari awal sampai akhir, dan
/// dalam keadaan itu kodenya memang benar. Yang salah hanya muncul kalau
/// providernya mati **di tengah jalan** — keadaan yang tidak pernah dibuat
/// satu tes pun, dan yang di perangkat sungguhan terjadi karena unggahan
/// gambar berlangsung berdetik-detik di jaringan gudang.
///
/// Tes ini membuat keadaan itu dengan sengaja: bangun providernya, buang
/// wadahnya, lalu panggil `refresh()` — persis urutan yang dilaporkan Sentry.
void main() {
  test('🔴 refresh() sesudah providernya dibuang tidak melempar', () async {
    final container = ProviderContainer();
    final vm =
        container.read(adminAnnouncementsViewModelProvider.notifier);

    // Inilah yang terjadi di HP: notifiernya sudah dibuang sementara `simpan`
    // masih menunggu jawaban server.
    container.dispose();

    // Sebelum diperbaiki, baris ini melempar `UnmountedRefException` — galat
    // yang sama persis yang dilaporkan Sentry, dari baris yang sama.
    await expectLater(vm.refresh(), completes);
  });

  test('refresh() pada provider yang masih hidup tetap memuat ulang', () async {
    // Penjagaannya tidak boleh mematikan gunanya. Tanpa tes ini, `refresh()`
    // yang selalu langsung keluar akan lulus tes di atas dengan sempurna dan
    // membuat daftar Admin berhenti diperbarui sesudah menyimpan — cacat yang
    // jauh lebih halus daripada yang sedang diperbaiki.
    //
    // 🔴 Yang dihitung adalah berapa kali `build()` benar-benar berjalan.
    // Membandingkan instance notifiernya TIDAK bisa dipakai: Riverpod memakai
    // ulang notifier yang sama antar-pembangunan ulang dan hanya menjalankan
    // `build()` lagi. Dicoba begitu lebih dulu, dan ia lulus untuk kode yang
    // salah maupun yang benar.
    final vm = _VmHitung();
    final container = ProviderContainer(
      overrides: [adminAnnouncementsViewModelProvider.overrideWith(() => vm)],
    );
    addTearDown(container.dispose);

    // ⚠️ Langganan ini wajib ada. Provider `@riverpod` membuang dirinya sendiri
    // begitu tidak ada yang menyimaknya, dan `container.read` saja tidak
    // menyimak apa pun.
    final langganan =
        container.listen(adminAnnouncementsViewModelProvider, (_, _) {});
    addTearDown(langganan.close);

    await container.read(adminAnnouncementsViewModelProvider.future);
    expect(vm.jumlahBuild, 1);

    await vm.refresh();

    expect(vm.jumlahBuild, 2);
  });
}

/// Menghitung pembangunan ulang, dan tidak menyentuh sesi sama sekali.
///
/// `build()` yang asli membaca `sessionProvider`, dan tanpa Supabase panggilan
/// itu tidak pernah terjawab — `refresh()` akan menggantung selamanya, bukan
/// gagal. Yang diuji di sini perilaku `refresh()`, bukan pembacaan sesinya.
class _VmHitung extends AdminAnnouncementsViewModel {
  int jumlahBuild = 0;

  @override
  Future<List<Announcement>> build() async {
    jumlahBuild++;
    return const [];
  }
}
