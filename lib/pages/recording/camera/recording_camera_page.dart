import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/enums.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/upload_queue_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'recording_camera_view_model.dart';
import 'widgets/scan_frame_overlay.dart';
import 'widgets/watermark_preview_overlay.dart';

/// Layar kamera perekaman (Bab 8.1 & 8.3).
///
/// Seluruh aturannya ada di `core/domain/`; layar ini hanya menampilkan dan
/// meneruskan ketukan. Yang ditegakkan di sini murni soal tampilan:
///
/// - Nomor resi tampil **besar** (Bab 8.3.5).
/// - Bingkai bantu kotak untuk QR, **mendatar** untuk barcode 1D (Bab 8.3.3).
/// - Tombol **Berhenti selalu hidup** selama merekam (Bab 8.3.1) — bila ditekan
///   sebelum 5 detik, yang muncul hanya konfirmasi, bukan penolakan.
class RecordingCameraPage extends ConsumerStatefulWidget {
  const RecordingCameraPage({
    super.key,
    required this.cameraName,
    required this.triggerWire,
    required this.shopId,
    this.shopName = '',
  });

  final String cameraName;
  final String triggerWire;
  final String shopId;

  /// Nama toko untuk watermark (Bab 8.5). Dibawa dari layar setup karena
  /// gudang sering tanpa sinyal.
  final String shopName;

  @override
  ConsumerState<RecordingCameraPage> createState() =>
      _RecordingCameraPageState();
}

class _RecordingCameraPageState extends ConsumerState<RecordingCameraPage> {
  final TextEditingController _manualController = TextEditingController();
  int _lastNoticeId = 0;
  bool _voiceAttached = false;

  RecordingCameraViewModel get _vm => ref.read(_provider.notifier);

  RecordingCameraViewModelProvider get _provider =>
      recordingCameraViewModelProvider(
        widget.cameraName,
        widget.triggerWire,
        widget.shopId,
        widget.shopName,
      );

  /// 🔴 Dibuat **sekali** dan dipakai ulang — jangan diubah jadi konstruksi
  /// di dalam `build`.
  ///
  /// Selama merekam, pencatat waktu berdetak tiap 200 ms dan mengubah state,
  /// sehingga `build` halaman ini berjalan 5 kali per detik. Bila widget
  /// pratinjau ikut dibuat ulang tiap kali, seluruh subtree terberat di layar
  /// (Texture kamera + putarannya) ikut dibangun ulang padahal isinya tidak
  /// berubah sama sekali — dan pratinjaunya patah-patah.
  ///
  /// Dengan instance yang sama, Flutter melihat widget identik dan melewati
  /// subtree itu. Keduanya berlangganan sendiri ke bagian state yang benar-
  /// benar mereka butuhkan lewat `select`, jadi tetap ikut berubah saat perlu.
  late final Widget _preview = _Preview(provider: _provider);
  late final Widget _transitionCover = _TransitionCover(provider: _provider);
  late final Widget _watermarkPreview =
      WatermarkPreviewOverlay(provider: _provider);
  late final Widget _stopButton = _StopButtonOverlay(provider: _provider);

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final state = ref.watch(_provider);

    // Bab 8.4 — kalimat voice-over disusun di lapisan UI agar ikut bahasa
    // aktif; ViewModel hanya memilih kapan diucapkan.
    if (!_voiceAttached) {
      _voiceAttached = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _vm.attachVoice(
          VoiceLines(
            start: t.recordVoiceStart,
            fiveSeconds: t.recordVoiceFiveSeconds,
            finished: t.recordVoiceFinished,
          ),
        );
      });
    }

    _reactToNotice(state, t);
    _reactToDuplicate(state, t);

    return PopScope(
      // Perekaman berjalan tidak boleh ditinggalkan tanpa sadar — berkasnya
      // akan tertutup separuh jalan.
      canPop: !state.isRecording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit(t);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _RecordingScope(
          cameraName: widget.cameraName,
          triggerWire: widget.triggerWire,
          shopId: widget.shopId,
          shopName: widget.shopName,
          child: state.fatalKey != null
            ? _FatalView(messageKey: state.fatalKey!)
            : Stack(
                fit: StackFit.expand,
                children: [
                  _preview,
                  _transitionCover,
                  if (state.cameraReady && state.mode != TriggerMode.manual)
                    ScanFrameOverlay(
                      wide: state.mode == TriggerMode.barcode1d,
                      color: _frameColor(context, state),
                    ),
                  // Di bawah palang atas dan tombol Berhenti, di atas bingkai
                  // bantu: yang ditiru adalah tulisan pada video, dan pada
                  // video ia memang berada paling depan.
                  _watermarkPreview,
                  SafeArea(
                    child: Column(
                      children: [
                        _TopBar(state: state),
                        const Spacer(),
                        // Ringkasan rekaman terakhir. Tidak menghalangi apa
                        // pun: pemindaian sudah hidup lagi di belakangnya, dan
                        // ini menghilang sendiri.
                        if (state.finished != null)
                          _FinishedNotice(finished: state.finished!),
                        if (state.mode == TriggerMode.manual &&
                            !state.isRecording &&
                            state.finished == null)
                          _ManualPanel(
                            controller: _manualController,
                            state: state,
                          ),
                        _BottomBar(state: state),
                      ],
                    ),
                  ),
                  // Paling akhir di Stack: tombol Berhenti wajib berada di atas
                  // segalanya **dan** dapat ditekan. Lapisan yang menutupinya
                  // sekalipun sepersekian detik berarti packer menekan dan
                  // tidak terjadi apa-apa.
                  _stopButton,
                ],
              ),
        ),
      ),
    );
  }

  Color _frameColor(BuildContext context, RecordingScreenState state) {
    final colors = Theme.of(context).extension<AppColors>()!;
    if (state.isRecording) return colors.recording;
    if (state.pendingResi != null) return colors.warning;
    return Colors.white;
  }

  // ---------- Reaksi terhadap pesan ----------

  void _reactToNotice(RecordingScreenState state, AppL10n t) {
    final notice = state.notice;
    if (notice == null || notice.id == _lastNoticeId) return;
    _lastNoticeId = notice.id;

    final message = switch (notice.kind) {
      RecordingNoticeKind.otherResi =>
        t.recordingStillRecording(notice.resi ?? ''),
      RecordingNoticeKind.stopTooEarly =>
        t.recordingStopTooEarly(notice.seconds ?? 0),
      RecordingNoticeKind.notAResi => t.recordNotAResi,
      RecordingNoticeKind.limitReached => t.recordLimitReached,
      RecordingNoticeKind.emptyClipboard => t.recordManualEmptyClipboard,
      RecordingNoticeKind.alreadyRecorded =>
        t.recordAlreadyRecordedShort(notice.resi ?? ''),
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
        );
      _vm.dismissNotice();
    });
  }

  /// Bab 7.7 — dialog dua tombol: **Lihat Video Lama** dan **Batal**.
  void _reactToDuplicate(RecordingScreenState state, AppL10n t) {
    final duplicate = state.duplicate;
    if (duplicate == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final goHistory = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(t.recordDuplicateTitle),
          content: Text(t.recordDuplicateBody(duplicate.resiCode)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.recordDuplicateViewOld),
            ),
          ],
        ),
      );
      if (!mounted) return;
      _vm.dismissDuplicate();
      if (goHistory ?? false) {
        // Riwayat dapat disaring per resi; dari sana packer bisa membuka video
        // lamanya lalu meminta Owner menghapusnya (Bab 7.7).
        context.go('/history');
      }
    });
  }

  Future<void> _confirmExit(AppL10n t) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.recordExitTitle),
        content: Text(t.recordExitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.recordStopButton),
          ),
        ],
      ),
    );
    if (!mounted || !(leave ?? false)) return;
    await _vm.stopManually();
    if (!mounted) return;
    context.pop();
  }
}

// ---------------------------------------------------------------------------

/// Penutup peralihan — berlangganan **hanya** pada `previewSettling`.
///
/// Dipisah dari halaman agar detak pencatat waktu tidak ikut membangunnya
/// ulang; lihat catatan pada `_transitionCover`.
class _TransitionCover extends ConsumerWidget {
  const _TransitionCover({required this.provider});

  final RecordingCameraViewModelProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Muncul seketika agar kedipan putaran tidak sempat terlihat, lalu memudar
    // supaya terbaca sebagai "sedang menyiapkan", bukan sebagai layar rusak.
    final settling =
        ref.watch(provider.select((s) => s.previewSettling));

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: settling ? 1 : 0,
        duration:
            settling ? Duration.zero : const Duration(milliseconds: 220),
        child: const ColoredBox(color: Colors.black),
      ),
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.provider});

  final RecordingCameraViewModelProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hanya dua kepingan state ini yang mempengaruhi pratinjau. Berlangganan
    // seluruh state akan membuatnya dibangun ulang tiap detak pencatat waktu.
    final ready = ref.watch(provider.select((s) => s.cameraReady));
    final geometry = ref.watch(provider.select((s) => s.previewGeometry));

    if (!ready) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: AppSizes.spaceMd),
            Text(
              context.l10n.recordPreparing,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    // `watch`, bukan `read`: provider kamera bersifat auto-dispose, dan
    // pembacaan tanpa langganan dapat mengembalikan objek baru yang
    // controller-nya masih kosong — lihat catatan pada `_camera` di ViewModel.
    final controller = ref.watch(cameraServiceProvider).controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    // 🔴 `CameraPreview` sengaja TIDAK dipakai. Widget itu mengunci bentuk
    // kotaknya pada `AspectRatio(1/previewSize)`, dan `previewSize` hanya diisi
    // sekali saat kamera dibuka. Selama merekam CameraX mengganti bingkainya
    // (720x480 → 480x720), sehingga `Texture` diberi kotak yang bentuknya salah
    // dan gambarnya melar 2,25 kali. Bentuk itu tidak dapat ditimpa dari luar,
    // jadi kotaknya dihitung sendiri di sini dari ukuran yang sedang berjalan.
    final value = controller.value;
    final correction = geometry.quarterTurnCorrection;

    // Putaran yang biasanya disumbang `CameraPreview`. Wajib direplikasi:
    // delegasi plugin menguranginya lagi dari putarannya sendiri, jadi kalau
    // dihilangkan pratinjau ikut miring saat perangkat dimiringkan.
    final turns = _preAppliedQuarterTurns(value) + correction;

    // Berapa kali kotak terbalik sebelum sampai ke `Texture`: putaran plugin
    // dan putaran kita sama-sama menukar lebar dengan tinggi.
    final base = (controller.description.sensorOrientation ~/ 90) % 4;
    final swapped = (base + correction).isOdd;

    final buffer =
        geometry.liveSize ?? value.previewSize ?? const Size(720, 480);
    final box = swapped ? Size(buffer.height, buffer.width) : buffer;

    // Pratinjau 480p diregangkan menutupi layar. Memotong sisi lebih baik
    // daripada menyisakan pita hitam: bagian yang dipindai selalu ada di
    // tengah, di dalam bingkai bantu.
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: box.width,
        height: box.height,
        child: RotatedBox(
          quarterTurns: turns,
          child: controller.buildPreview(),
        ),
      ),
    );
  }

  /// Salinan setia `CameraPreview._getQuarterTurns` (paket `camera` 0.12.0).
  static int _preAppliedQuarterTurns(CameraValue value) {
    final orientation = value.isRecordingVideo
        ? (value.recordingOrientation ?? value.deviceOrientation)
        : (value.previewPauseOrientation ??
            value.lockedCaptureOrientation ??
            value.deviceOrientation);
    return switch (orientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeRight => 1,
      DeviceOrientation.portraitDown => 2,
      DeviceOrientation.landscapeLeft => 3,
    };
  }
}

/// Nomor resi besar, penghitung durasi, dan peringatan izin.
/// Berapa video yang masih menunggu watermark atau unggahan.
///
/// Bab 8.5 meminta indikator *"Memproses video…"* selama FFmpeg berjalan agar
/// layar tidak membeku tanpa penjelasan. Di sini layarnya memang tidak pernah
/// membeku — watermark dikerjakan di sela antar-paket — sehingga yang
/// dibutuhkan bukan panel penghalang, melainkan angka kecil yang menjawab
/// pertanyaan yang benar-benar dimiliki packer: *"video saya sudah terkirim
/// belum?"*
///
/// Hilang dengan sendirinya begitu antreannya habis.
class _QueueBadge extends ConsumerWidget {
  const _QueueBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingUploadCountProvider).value ?? 0;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceSm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_upload_outlined,
              size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            context.l10n.recordQueueBadge(count),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state});

  final RecordingScreenState state;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;

    final (String headline, String caption) = switch (state) {
      _ when state.isRecording => (
          state.machine.resiCode ?? '',
          Formatters.duration(state.machine.elapsed),
        ),
      _ when state.pendingResi != null => (
          state.pendingResi!,
          t.recordConfirmingRead,
        ),
      _ when state.checkingResi => ('', t.recordCheckingResi),
      _ => (
          '',
          switch (state.mode) {
            TriggerMode.qrCode => t.recordAimQr,
            TriggerMode.barcode1d => t.recordAimBarcode,
            TriggerMode.manual => t.recordAimManual,
          },
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spaceMd,
        AppSizes.spaceSm,
        AppSizes.spaceMd,
        AppSizes.spaceMd,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BackButton(color: Colors.white, onPressed: () => context.pop()),
              if (state.isRecording) ...[
                _RecordingDot(color: colors.recording),
                const SizedBox(width: AppSizes.spaceSm),
              ],
              const Spacer(),
              const _QueueBadge(),
              if (state.isRecording) ...[
                const SizedBox(width: AppSizes.spaceSm),
                _Countdown(state: state, warning: colors.warning),
              ],
            ],
          ),
          if (headline.isNotEmpty)
            // Bab 8.3.5 — nomor resi tampil besar. Ini bukan estetika: packer
            // harus sempat menyadari salah baca sebelum videonya jadi.
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.spaceSm),
              child: Text(
                headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'JetBrainsMono',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.spaceXs),
              child: Text(
                caption,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          // Bab 8.9 — mikrofon/lokasi ditolak tidak menghalangi perekaman,
          // tetapi packer tetap berhak tahu videonya bisu atau tanpa koordinat.
          for (final key in state.warningKeys)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.spaceXs),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.messageForKey(key),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordingDot extends StatelessWidget {
  const _RecordingDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.state, required this.warning});

  final RecordingScreenState state;
  final Color warning;

  @override
  Widget build(BuildContext context) {
    final remaining = state.machine.remaining;
    final isFinal = state.machine.isFinalCountdown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isFinal ? warning : const Color(0x66000000),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        context.l10n.recordRemainingLabel(remaining.inSeconds),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Tombol Berhenti dan senter.
class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.state});

  final RecordingScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final vm = _RecordingScope.of(context).notifier(ref);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spaceMd,
        AppSizes.spaceMd,
        AppSizes.spaceMd,
        AppSizes.spaceLg,
      ),
      child: Row(
        children: [
          // Senter hanya pada mode barcode (Bab 8.3.3).
          if (state.mode == TriggerMode.barcode1d)
            _RoundButton(
              icon: state.torchOn ? Icons.flashlight_on : Icons.flashlight_off,
              tooltip: state.torchOn ? t.recordTorchOff : t.recordTorchOn,
              active: state.torchOn,
              onPressed: vm.toggleTorch,
            )
          else
            const SizedBox(width: AppSizes.touchComfort),
          const Spacer(),
          // 🔴 Tombol Berhenti **tidak lagi di sini** — lihat
          // `_StopButtonOverlay`. Jangan mengembalikannya ke baris ini.
        ],
      ),
    );
  }
}

/// Tombol **Berhenti** (Bab 8.3.1, keputusan Product Owner nomor 1).
///
/// 🔴 Dipisahkan menjadi lapisan sendiri pada 17 Agustus 2026 setelah Product
/// Owner melaporkan tombolnya **tidak tergambar sama sekali** saat merekam di
/// Redmi Note 9 — padahal titik merah, penghitung durasi, dan hitung mundur
/// yang dihidupkan oleh syarat yang **sama persis** (`isRecording`) semuanya
/// tampil, dan tombol senter di baris yang sama juga tampil.
///
/// Sebabnya tidak dapat dijelaskan dari membaca kode. Karena itu tombolnya
/// dikeluarkan dari `Row` berisi dua `Spacer` di `_BottomBar` dan ditempatkan
/// langsung di `Stack` dengan posisi yang dihitung sendiri: apa pun yang
/// dulu terjadi di dalam baris itu tidak lagi dapat mempengaruhinya.
///
/// Aturan yang tidak boleh hilang bersama pemindahan ini:
///
/// - Tombolnya **tidak pernah dimatikan**. Video di bawah 5 detik hanya
///   memunculkan konfirmasi. Mematikannya menjebak packer yang baru menyadari
///   kameranya menghadap arah keliru.
/// - Berlangganan **hanya** pada `showStopButton`, bukan seluruh keadaan layar
///   (jebakan 14).
class _StopButtonOverlay extends ConsumerWidget {
  const _StopButtonOverlay({required this.provider});

  final RecordingCameraViewModelProvider provider;

  /// Nilai terakhir yang sempat tercetak. Diagnosis sekali per perubahan,
  /// bukan lima kali per detik.
  static bool? _lastLogged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;
    final visible = ref.watch(provider.select((s) => s.showStopButton));

    // 🔴 Jejak diagnosis, bukan sisa lupa dibersihkan. Bila tombolnya kelak
    // hilang lagi, baris ini yang membedakan "layar tidak menganggap dirinya
    // sedang merekam" dari "sedang merekam tetapi tombolnya tidak tergambar" —
    // dua sebab yang sangat berbeda dan tidak dapat dibedakan dengan mata.
    if (_lastLogged != visible) {
      _lastLogged = visible;
      debugPrint('KAMELSCAN_UI tombol Berhenti tampil=$visible');
    }

    if (!visible) return const SizedBox.shrink();

    // Bulat seperti tombol rana kamera — diminta Product Owner 17 Agustus 2026.
    // Bentuk melebar dengan tulisan "Berhenti" memakan hampir seluruh lebar
    // layar dan menutupi pandangan ke meja packing, padahal yang dibutuhkan
    // hanya satu sasaran yang mudah dikenali dan mudah ditekan.
    //
    // §0 palet — warna tidak boleh menjadi satu-satunya pembeda makna. Karena
    // tulisannya dilepas, bentuk kotak berhenti di dalam lingkaran dan cincin
    // putih di tepinya yang membawa artinya, bukan sekadar warna merahnya.
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.spaceLg),
          child: Tooltip(
            message: t.recordStopButton,
            child: Semantics(
              button: true,
              label: t.recordStopButton,
              child: Material(
                color: colors.danger,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.white, width: 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _onStop(context, ref),
                  child: const SizedBox(
                    // 76 dp, jauh di atas ambang Bab 9.10: layar ini dipakai
                    // sambil memegang paket, kadang dengan sarung tangan.
                    width: _diameter,
                    height: _diameter,
                    child: Icon(Icons.stop_rounded, color: Colors.white, size: 34),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _diameter = 76;

  Future<void> _onStop(BuildContext context, WidgetRef ref) async {
    final t = context.l10n;
    final vm = ref.read(provider.notifier);

    if (ref.read(provider).machine.needsShortVideoConfirm) {
      final stop = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t.recordingShortConfirmTitle),
          content: Text(t.recordingShortConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.recordStopButton),
            ),
          ],
        ),
      );
      if (!(stop ?? false)) return;
    }
    await vm.stopManually();
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: active ? Colors.white : const Color(0x66000000),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: AppSizes.touchComfort,
              height: AppSizes.touchComfort,
              child: Icon(
                icon,
                color: active ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      );
}

/// Panel Input Manual (Bab 8.3.4).
class _ManualPanel extends ConsumerWidget {
  const _ManualPanel({required this.controller, required this.state});

  final TextEditingController controller;
  final RecordingScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final vm = _RecordingScope.of(context).notifier(ref);
    final manual = state.manual;

    return Container(
      margin: const EdgeInsets.all(AppSizes.spaceMd),
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            // Papan ketik alfanumerik: resi marketplace mencampur huruf dan
            // angka, sehingga papan angka saja tidak cukup (Bab 8.3.4).
            keyboardType: TextInputType.visiblePassword,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 20,
              letterSpacing: 1.2,
            ),
            decoration: InputDecoration(
              labelText: t.recordManualHint,
              errorText: manual.errorKey == null
                  ? (manual.duplicate ? t.errorResiDuplicate : null)
                  : context.messageForKey(manual.errorKey!),
              suffixIcon: manual.checking
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: vm.setManualText,
          ),
          const SizedBox(height: AppSizes.spaceSm),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  final text = data?.text?.trim() ?? '';
                  if (text.isEmpty) {
                    vm.reportEmptyClipboard();
                    return;
                  }
                  controller.text = text.toUpperCase();
                  vm.setManualText(text);
                },
                icon: const Icon(Icons.content_paste),
                label: Text(t.recordManualPaste),
              ),
              TextButton.icon(
                onPressed: () {
                  controller.clear();
                  vm.clearManual();
                },
                icon: const Icon(Icons.clear),
                label: Text(t.recordManualClear),
              ),
            ],
          ),
          // Bab 8.3.4 — 5 resi terakhir sebagai saran, membantu saat merekam
          // ulang setelah kegagalan.
          if (manual.recent.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: manual.recent.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSizes.spaceSm),
                itemBuilder: (_, i) {
                  final resi = manual.recent[i];
                  return ActionChip(
                    label: Text(resi),
                    onPressed: () {
                      controller.text = resi;
                      vm.setManualText(resi);
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: AppSizes.spaceSm),
          SizedBox(
            height: AppSizes.touchComfort,
            child: FilledButton.icon(
              onPressed: manual.canStart ? vm.startManualRecording : null,
              icon: const Icon(Icons.videocam),
              label: Text(t.recordManualStart),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ringkasan rekaman terakhir — **memberi tahu, bukan menghalangi**.
///
/// 🔴 Sengaja tanpa tombol. Sebelum 15 Agustus 2026 di sini ada panel dengan
/// tombol "Rekam paket berikutnya" yang wajib ditekan sebelum packer boleh
/// merekam lagi. Pada 100 paket itu berarti 100 ketukan yang tidak
/// menghasilkan apa pun. Sekarang pemindaian berlanjut sendiri, dan panel ini
/// hanya lewat sebentar.
///
/// Melihat rincian rekaman lama adalah kebutuhan sesekali — tempatnya di tab
/// Riwayat, bukan di jalan yang dilewati ratusan kali sehari.
///
/// ⚠️ Berkas yang dilaporkan masih **mentah**. Watermark (Bab 8.5) dan antrian
/// upload (Bab 8.6) belum tersambung; ini titik serah terimanya.
class _FinishedNotice extends StatelessWidget {
  const _FinishedNotice({required this.finished});

  final FinishedRecording finished;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceMd,
        vertical: AppSizes.spaceSm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceMd,
        vertical: AppSizes.spaceSm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: colors.success),
          const SizedBox(width: AppSizes.spaceSm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finished.resiCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${t.recordFinishedTitle} · '
                  '${Formatters.duration(finished.duration)} · '
                  '${Formatters.fileSize(finished.sizeBytes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FatalView extends StatelessWidget {
  const _FatalView({required this.messageKey});

  final String messageKey;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined,
                size: 48, color: Colors.white70),
            const SizedBox(height: AppSizes.spaceMd),
            Text(
              context.messageForKey(messageKey),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: AppSizes.spaceLg),
            OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: Text(t.commonBack),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pembawa argumen keluarga ke widget anak.
///
/// Tanpa ini setiap anak harus menerima tiga argumen provider lewat
/// konstruktor, dan satu saja yang tertinggal akan membuat widget itu membaca
/// **instance ViewModel yang berbeda** — bug yang tidak terlihat sampai tombol
/// ternyata tidak melakukan apa pun.
class _RecordingScope extends InheritedWidget {
  const _RecordingScope({
    required this.cameraName,
    required this.triggerWire,
    required this.shopId,
    required this.shopName,
    required super.child,
  });

  final String cameraName;
  final String triggerWire;
  final String shopId;
  final String shopName;

  static _RecordingScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RecordingScope>()!;

  RecordingCameraViewModel notifier(WidgetRef ref) => ref.read(
        recordingCameraViewModelProvider(
          cameraName,
          triggerWire,
          shopId,
          shopName,
        ).notifier,
      );

  @override
  bool updateShouldNotify(_RecordingScope old) =>
      old.cameraName != cameraName ||
      old.triggerWire != triggerWire ||
      old.shopId != shopId ||
      old.shopName != shopName;
}
