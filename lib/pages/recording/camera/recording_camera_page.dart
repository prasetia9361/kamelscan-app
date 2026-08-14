import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/enums.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'recording_camera_view_model.dart';
import 'widgets/scan_frame_overlay.dart';

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
  });

  final String cameraName;
  final String triggerWire;
  final String shopId;

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
      );

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
          child: state.fatalKey != null
            ? _FatalView(messageKey: state.fatalKey!)
            : Stack(
                fit: StackFit.expand,
                children: [
                  _Preview(ready: state.cameraReady),
                  if (state.cameraReady && state.mode != TriggerMode.manual)
                    ScanFrameOverlay(
                      wide: state.mode == TriggerMode.barcode1d,
                      color: _frameColor(context, state),
                    ),
                  SafeArea(
                    child: Column(
                      children: [
                        _TopBar(state: state),
                        const Spacer(),
                        if (state.finished != null)
                          _FinishedPanel(
                            finished: state.finished!,
                            onNext: () {
                              _manualController.clear();
                              _vm.next();
                            },
                          )
                        else ...[
                          if (state.mode == TriggerMode.manual &&
                              !state.isRecording)
                            _ManualPanel(
                              controller: _manualController,
                              state: state,
                            ),
                          _BottomBar(state: state),
                        ],
                      ],
                    ),
                  ),
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

class _Preview extends ConsumerWidget {
  const _Preview({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // Pratinjau 480p diregangkan menutupi layar. Memotong sisi lebih baik
    // daripada menyisakan pita hitam: bagian yang dipindai selalu ada di
    // tengah, di dalam bingkai bantu.
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 480,
        height: controller.value.previewSize?.width ?? 640,
        child: CameraPreview(controller),
      ),
    );
  }
}

/// Nomor resi besar, penghitung durasi, dan peringatan izin.
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
              if (state.isRecording)
                _Countdown(state: state, warning: colors.warning),
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
    final colors = Theme.of(context).extension<AppColors>()!;
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
          if (state.showStopButton)
            SizedBox(
              height: AppSizes.touchComfort + 8,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                ),
                onPressed: () => _onStop(context, vm),
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(t.recordStopButton),
              ),
            ),
          const Spacer(),
          const SizedBox(width: AppSizes.touchComfort),
        ],
      ),
    );
  }

  /// 🔴 Tombol Berhenti **tidak pernah dimatikan** (Bab 8.3.1). Video di bawah
  /// 5 detik hanya memunculkan konfirmasi — mematikan tombolnya akan menjebak
  /// packer yang baru menyadari kamera menghadap arah keliru.
  Future<void> _onStop(BuildContext context, RecordingCameraViewModel vm) async {
    final t = context.l10n;

    if (state.machine.needsShortVideoConfirm) {
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

/// Ringkasan setelah perekaman berhenti.
///
/// ⚠️ Berkas yang dilaporkan masih **mentah**. Watermark (Bab 8.5) dan antrian
/// upload (Bab 8.6) belum tersambung; panel ini adalah titik serah terimanya.
class _FinishedPanel extends StatelessWidget {
  const _FinishedPanel({required this.finished, required this.onNext});

  final FinishedRecording finished;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = Theme.of(context).extension<AppColors>()!;

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
          Row(
            children: [
              Icon(Icons.check_circle, color: colors.success),
              const SizedBox(width: AppSizes.spaceSm),
              Expanded(
                child: Text(
                  t.recordFinishedTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceSm),
          Text(
            finished.resiCode,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSizes.spaceXs),
          Text(
            '${Formatters.duration(finished.duration)} · '
            '${Formatters.fileSize(finished.sizeBytes)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSizes.spaceMd),
          SizedBox(
            height: AppSizes.touchComfort,
            child: FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.videocam),
              label: Text(t.recordNextPackage),
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
    required super.child,
  });

  final String cameraName;
  final String triggerWire;
  final String shopId;

  static _RecordingScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RecordingScope>()!;

  RecordingCameraViewModel notifier(WidgetRef ref) => ref.read(
        recordingCameraViewModelProvider(cameraName, triggerWire, shopId)
            .notifier,
      );

  @override
  bool updateShouldNotify(_RecordingScope old) =>
      old.cameraName != cameraName ||
      old.triggerWire != triggerWire ||
      old.shopId != shopId;
}
