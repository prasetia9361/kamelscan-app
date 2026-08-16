import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart' show CameraImage;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/domain/recording_machine.dart';
import '../../../core/domain/scan_gate.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/barcode_frame_reader.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/services/trigger_strategy.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/validators.dart';

part 'recording_camera_view_model.g.dart';

// ---------------------------------------------------------------------------
// Pesan sekilas
// ---------------------------------------------------------------------------

/// Jenis pesan sekilas yang perlu ditampilkan layar.
///
/// ViewModel **tidak** menyusun kalimatnya. Bab 9.11 poin 5: teks diterjemahkan
/// di lapisan UI, sehingga pesan otomatis ikut bahasa aktif.
enum RecordingNoticeKind {
  /// Resi **berbeda** dipindai selagi merekam.
  ///
  /// 🔴 Wajib tampil. Bila diabaikan diam-diam, packer mengira ia sedang
  /// merekam paket yang baru dipindai, padahal masih merekam paket sebelumnya —
  /// dan videonya akan ber-watermark resi yang salah.
  otherResi,

  /// Resi yang sama dipindai sebelum 5 detik berlalu.
  stopTooEarly,

  /// Isi kode bukan nomor resi (mis. URL pelacakan).
  notAResi,

  /// Batas durasi tier tercapai.
  limitReached,

  /// Tombol Tempel ditekan tetapi papan klip kosong.
  emptyClipboard,

  /// Resi yang dialognya sudah ditutup sekali dipindai lagi.
  alreadyRecorded,
}

/// Satu pesan sekilas. [id] naik tiap pesan baru agar layar tahu kapan harus
/// menampilkan ulang pesan yang isinya kebetulan sama.
class RecordingNotice {
  const RecordingNotice(this.id, this.kind, {this.resi, this.seconds});

  final int id;
  final RecordingNoticeKind kind;
  final String? resi;
  final int? seconds;
}

/// Resi yang sudah pernah direkam (Bab 7.7).
class DuplicateResi {
  const DuplicateResi(this.resiCode);

  final String resiCode;
}

/// Hasil satu sesi rekam yang sudah selesai.
///
/// ⚠️ [path] masih berkas **mentah** dari kamera. Watermark (Bab 8.5) dan
/// antrian upload (Bab 8.6) belum dikerjakan; lihat catatan pada
/// [RecordingCameraViewModel._finish].
class FinishedRecording {
  const FinishedRecording({
    required this.resiCode,
    required this.path,
    required this.sizeBytes,
    required this.duration,
    required this.reason,
  });

  final String resiCode;
  final String path;
  final int sizeBytes;
  final Duration duration;
  final StopReason reason;
}

/// Kalimat voice-over (Bab 8.4) yang sudah diterjemahkan layar.
///
/// [TtsService] sengaja menerima teks jadi dan tidak menyusun kalimat sendiri;
/// pola yang sama diteruskan ke sini agar ViewModel tidak perlu menyentuh
/// l10n sama sekali.
class VoiceLines {
  const VoiceLines({
    required this.start,
    required this.fiveSeconds,
    required this.finished,
  });

  final String Function(String resi) start;
  final String fiveSeconds;
  final String finished;
}

// ---------------------------------------------------------------------------
// Keadaan layar
// ---------------------------------------------------------------------------

/// Keadaan kolom isian pada mode Input Manual (Bab 8.3.4).
class ManualEntry {
  const ManualEntry({
    this.text = '',
    this.errorKey,
    this.checking = false,
    this.duplicate = false,
    this.recent = const [],
  });

  final String text;

  /// Kunci l10n dari [Validators.resiCode]; `null` bila formatnya sah.
  final String? errorKey;

  /// Pengecekan resi ganda sedang berjalan (Bab 7.7, debounce 500 ms).
  final bool checking;
  final bool duplicate;

  /// 5 resi terakhir sebagai saran.
  final List<String> recent;

  /// Bab 8.3.4 — tombol Mulai Rekam aktif hanya bila format sah **dan** resi
  /// belum pernah dipakai.
  bool get canStart =>
      text.isNotEmpty && errorKey == null && !checking && !duplicate;

  ManualEntry copyWith({
    String? text,
    String? errorKey,
    bool clearError = false,
    bool? checking,
    bool? duplicate,
    List<String>? recent,
  }) =>
      ManualEntry(
        text: text ?? this.text,
        errorKey: clearError ? null : (errorKey ?? this.errorKey),
        checking: checking ?? this.checking,
        duplicate: duplicate ?? this.duplicate,
        recent: recent ?? this.recent,
      );
}

class RecordingScreenState {
  const RecordingScreenState({
    required this.mode,
    this.machine = const RecordingState(),
    this.preparing = true,
    this.cameraReady = false,
    this.fatalKey,
    this.warningKeys = const [],
    this.pendingResi,
    this.torchOn = false,
    this.previewGeometry = PreviewGeometry.unknown,
    this.previewSettling = false,
    this.secondsUntilScanStop = 0,
    this.notice,
    this.checkingResi = false,
    this.duplicate,
    this.finished,
    this.manual = const ManualEntry(),
  });

  final TriggerMode mode;
  final RecordingState machine;

  /// Izin & kamera masih disiapkan.
  final bool preparing;
  final bool cameraReady;

  /// Kegagalan yang menghentikan layar sama sekali (kunci l10n).
  final String? fatalKey;

  /// Peringatan yang tidak menghalangi (mikrofon/lokasi ditolak, Bab 8.9).
  final List<String> warningKeys;

  /// Mode barcode 1D: pembacaan pertama, menunggu konfirmasi kedua.
  /// Belum boleh berbunyi (Bab 8.3.5).
  final String? pendingResi;

  final bool torchOn;

  /// Bentuk dan koreksi putaran pratinjau yang sedang berjalan. Diisi
  /// [CameraService.readPreviewGeometry]; alasan lengkapnya ada di sana.
  final PreviewGeometry previewGeometry;

  /// Bingkai kamera sedang berganti bentuk — pratinjau ditutup sementara.
  ///
  /// 🔴 Bukan hiasan. CameraX melaporkan bingkai barunya lewat metadata
  /// **lebih dulu**, baru beberapa frame kemudian benar-benar mengirim piksel
  /// yang sudah diputar. Di sela itu hitungan layar dan isi gambar tidak
  /// sinkron, dan pratinjau berkedip berputar — ke satu arah saat mulai
  /// merekam, ke arah sebaliknya saat berhenti (diamati Product Owner
  /// 15 Agustus 2026 dengan gunting sebagai objek acuan).
  ///
  /// Balapan ini **tidak bisa dimenangkan dengan mengatur waktu**: Flutter
  /// tidak punya cara mengetahui frame mana yang pertama sudah berputar.
  /// Satu-satunya jalan adalah tidak menampilkan apa pun selama peralihan.
  final bool previewSettling;

  /// Sisa detik sebelum pemindaian boleh menghentikan perekaman.
  final int secondsUntilScanStop;

  final RecordingNotice? notice;

  /// Pengecekan resi ganda berjalan sebelum kamera merekam (Bab 8.3.1).
  final bool checkingResi;
  final DuplicateResi? duplicate;

  final FinishedRecording? finished;
  final ManualEntry manual;

  bool get isRecording => machine.phase == RecordingPhase.recording;

  /// Bab 8.3.1 — tombol Berhenti wajib tersedia di semua mode. Ia hanya
  /// disembunyikan saat memang tidak ada yang bisa dihentikan.
  bool get showStopButton => isRecording;

  RecordingScreenState copyWith({
    RecordingState? machine,
    bool? preparing,
    bool? cameraReady,
    String? fatalKey,
    List<String>? warningKeys,
    String? pendingResi,
    bool clearPending = false,
    bool? torchOn,
    PreviewGeometry? previewGeometry,
    bool? previewSettling,
    int? secondsUntilScanStop,
    RecordingNotice? notice,
    bool clearNotice = false,
    bool? checkingResi,
    DuplicateResi? duplicate,
    bool clearDuplicate = false,
    FinishedRecording? finished,
    bool clearFinished = false,
    ManualEntry? manual,
  }) =>
      RecordingScreenState(
        mode: mode,
        machine: machine ?? this.machine,
        preparing: preparing ?? this.preparing,
        cameraReady: cameraReady ?? this.cameraReady,
        fatalKey: fatalKey ?? this.fatalKey,
        warningKeys: warningKeys ?? this.warningKeys,
        pendingResi: clearPending ? null : (pendingResi ?? this.pendingResi),
        torchOn: torchOn ?? this.torchOn,
        previewGeometry: previewGeometry ?? this.previewGeometry,
        previewSettling: previewSettling ?? this.previewSettling,
        secondsUntilScanStop: secondsUntilScanStop ?? this.secondsUntilScanStop,
        notice: clearNotice ? null : (notice ?? this.notice),
        checkingResi: checkingResi ?? this.checkingResi,
        duplicate: clearDuplicate ? null : (duplicate ?? this.duplicate),
        finished: clearFinished ? null : (finished ?? this.finished),
        manual: manual ?? this.manual,
      );
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

/// Penyambung layar rekam (Bab 8.1 & 8.3).
///
/// 🔴 **Tidak ada satu pun aturan baru di berkas ini.** Seluruh keputusan
/// pemindaian ada di [ScanGate], seluruh transisi status ada di
/// [RecordingMachine], dan keduanya sudah teruji tanpa perangkat. Yang
/// dikerjakan di sini hanya menyambungkan kamera, ML Kit, dan pencatat waktu
/// ke keduanya.
///
/// Menyalin ulang aturannya ke sini pernah terjadi sekali di `ScannerService`
/// dan langsung menyimpang begitu aturan berhenti diubah. Jangan diulang.
@riverpod
class RecordingCameraViewModel extends _$RecordingCameraViewModel {
  static const AppLogger _log = AppLogger('RecordingCamera');

  late TriggerStrategy _strategy;
  late ScanGate _gate;

  /// 🔴 Kamera dan pemindai **wajib di-`watch`, bukan `read`.**
  ///
  /// Keduanya provider *auto-dispose*: Riverpod membuangnya begitu tidak ada
  /// yang berlangganan. `ref.read` tidak membuat langganan, sehingga di sela
  /// `await` panjang (membuka lensa memakan ratusan milidetik) provider-nya
  /// dibuang, dan `ref.read` berikutnya membuat **objek baru yang kosong**.
  ///
  /// Gejalanya di perangkat sangat menyesatkan — terjadi 14 Agustus 2026:
  /// lampu kamera menyala (objek pertama berhasil membuka lensa dan menjadi
  /// yatim), sementara layar melaporkan *"Izin kamera diperlukan"* (objek kedua
  /// controller-nya null) padahal izin sudah diberikan. Lensa yang terbuka itu
  /// juga tidak pernah ditutup.
  late CameraService _camera;
  late BarcodeFrameReader _reader;

  /// Resi yang dialog "sudah pernah direkam"-nya sudah ditutup sekali.
  ///
  /// Label yang sama masih ada di depan kamera setelah dialog ditutup, dan
  /// tanpa catatan ini dialognya muncul lagi seketika — berulang tanpa henti.
  /// Ini bukan aturan pemindaian (yang itu milik [ScanGate]), melainkan
  /// pencegah pengulangan dialog.
  final Set<String> _dialogShownFor = <String>{};

  /// Resi yang **sudah selesai direkam** selama layar ini terbuka.
  ///
  /// 🔴 Pengaman untuk perekaman beruntun tanpa tombol. Aturan berhenti membuat
  /// packer memindai label yang sama untuk mengakhiri rekaman — dan label itu
  /// masih persis di depan kamera sesudahnya. Tanpa catatan ini, pemindaian
  /// yang langsung hidup lagi akan menerima resi yang sama dan merekamnya
  /// ulang seketika, berulang kali, memakan token dan kuota.
  ///
  /// Pengecekan resi ganda ke server tidak menolong di sini: videonya belum
  /// terunggah, jadi server menjawab "belum ada".
  ///
  /// Sengaja hanya seumur layar (diputuskan Product Owner 15 Agustus 2026).
  /// Merekam ulang resi yang sama adalah kejadian langka dan sudah punya
  /// jalannya lewat Riwayat; rekaman ganda tak disengaja akan terjadi tiap hari.
  final Set<String> _recordedInSession = <String>{};

  Timer? _ticker;
  Timer? _manualDebounce;
  DateTime? _startedAt;
  bool _disposed = false;

  /// Penjaga agar frame berikutnya tidak ikut diproses selagi ML Kit masih
  /// mengerjakan yang sebelumnya. Tanpa ini antrean menumpuk lebih cepat
  /// daripada ML Kit menyelesaikannya dan perangkat kehabisan memori.
  bool _analyzing = false;

  /// Kapan frame terakhir diserahkan ke ML Kit — untuk penjarangan.
  DateTime? _lastAnalyzedAt;

  /// Sedang berpindah jalur kamera atau memeriksa resi — frame diabaikan agar
  /// pembacaan beruntun tidak memulai perekaman kedua.
  bool _busy = false;

  int _noticeId = 0;
  DateTime? _lastRejectNotice;
  DateTime? _lastAlreadyNotice;
  bool _saidFinalCountdown = false;
  VoiceLines? _voice;

  @override
  RecordingScreenState build(
    String cameraName,
    String triggerWire,
    String shopId,
  ) {
    _strategy = TriggerStrategy.of(TriggerMode.fromWire(triggerWire));
    _gate = ScanGate(strategy: _strategy);
    _camera = ref.watch(cameraServiceProvider);
    _reader = ref.watch(barcodeFrameReaderProvider);

    ref.onDispose(() {
      _disposed = true;
      _ticker?.cancel();
      _manualDebounce?.cancel();
    });

    unawaited(_bootstrap());

    return RecordingScreenState(mode: _strategy.mode);
  }

  // ---------- Penyiapan ----------

  Future<void> _bootstrap() async {
    // Bab 8.9 — izin diminta tepat saat dibutuhkan, bukan seluruhnya di awal
    // aplikasi, dan tiap izin punya akibat berbeda bila ditolak.
    final permissions =
        await ref.read(permissionServiceProvider).requestForRecording();
    if (_disposed) return;

    if (!permissions.canRecord) {
      _log.e('Izin kamera ditolak — perekaman diblokir (Bab 8.9)');
      _set(state.copyWith(
        preparing: false,
        fatalKey: 'permissionCameraDenied',
      ));
      return;
    }
    _log.i('Izin OK · audio=${permissions.withAudio} '
        'lokasi=${permissions.withLocation}');

    final init = await _camera.init(
      cameraName: cameraName,
      enableAudio: permissions.withAudio,
    );
    if (_disposed) return;

    if (init.isErr) {
      _log.e('Kamera gagal disiapkan', init.failureOrNull);
      _set(state.copyWith(
        preparing: false,
        fatalKey: init.failureOrNull?.messageKey ?? 'errorUnknown',
      ));
      return;
    }
    _log.i('Kamera siap · lensa=$cameraName '
        'orientasi=${_camera.sensorOrientation}');

    await _reader.start(_strategy.mode);
    if (_disposed) return;

    final maxDuration = _camera.effectiveMaxDuration(
      ref.read(sessionProvider).value?.tier.maxRecordingDuration ??
          AppConstants.hardMaxRecordingDuration,
    );

    final recent = await _loadRecentResi();
    if (_disposed) return;

    _set(state.copyWith(
      preparing: false,
      cameraReady: true,
      warningKeys: permissions.warningKeys,
      machine: RecordingMachine.ready(maxDuration: maxDuration),
      previewGeometry: await _camera.readPreviewGeometry(),
      manual: state.manual.copyWith(recent: recent),
    ));

    await _startScanning();
  }

  /// Voice-over (Bab 8.4). Dipanggil layar sekali setelah l10n tersedia;
  /// tanpa ini ViewModel tidak berbicara sama sekali.
  Future<void> attachVoice(VoiceLines lines) async {
    if (_voice != null) return;
    _voice = lines;

    final prefs = ref.read(appPreferencesProvider).value;
    final tts = ref.read(ttsServiceProvider);
    tts.enabled = prefs?.voiceOverEnabled ?? true;
    if (!tts.isEnabled) return;
    await tts.init(locale: prefs?.languageCode == 'en' ? 'en-US' : 'id-ID');
  }

  /// Mulai memindai. Mode manual tidak memindai apa pun (Bab 8.3.4).
  Future<void> _startScanning() async {
    if (_strategy.mode == TriggerMode.manual) return;
    final result = await _camera.startImageStream(_onFrame);
    if (_disposed) return;
    if (result.isOk) {
      _log.i('Pemindaian pra-rekam berjalan (${_strategy.mode.wire})');
      return;
    }
    _log.e('Pemindaian pra-rekam gagal', result.failureOrNull);
    _set(state.copyWith(
      fatalKey: result.failureOrNull?.messageKey ?? 'errorUnknown',
    ));
  }

  // ---------- Frame ----------

  void _onFrame(CameraImage image) {
    if (_disposed || _analyzing || _busy) return;

    // Penjarangan: kamera mengirim ± 30 frame per detik, ML Kit hanya perlu
    // ± 8. Alasan lengkapnya di [AppConstants.scanFrameInterval].
    final now = DateTime.now();
    final last = _lastAnalyzedAt;
    if (last != null && now.difference(last) < AppConstants.scanFrameInterval) {
      return;
    }
    _lastAnalyzedAt = now;
    // Dialog resi ganda sedang terbuka — memindai di belakangnya hanya akan
    // menumpuk dialog kedua di atasnya.
    if (state.duplicate != null) return;

    final phase = state.machine.phase;
    if (phase != RecordingPhase.ready && phase != RecordingPhase.recording) {
      return;
    }

    _analyzing = true;
    unawaited(_analyzeFrame(image));
  }

  Future<void> _analyzeFrame(CameraImage image) async {
    try {
      final raw = await _reader.read(image, _camera.sensorOrientation);
      if (raw != null && !_disposed) _handleRead(raw);
    } on Object catch (e) {
      // Satu frame gagal bukan alasan menghentikan perekaman; frame berikutnya
      // datang ± 55 ms lagi.
      _log.w('Pembacaan frame gagal', e);
    } finally {
      _analyzing = false;
    }
  }

  /// Satu pembacaan mentah → keputusan [ScanGate] → tindakan.
  ///
  /// Perhatikan: **tidak ada `if` tentang aturan** di sini, hanya penerusan
  /// keputusan yang sudah dibuat gerbang yang teruji.
  void _handleRead(String raw) {
    final result = _gate.read(raw);

    switch (result.decision) {
      case ScanDecision.rejected:
        _noticeRejected();

      case ScanDecision.pendingConfirmation:
        // Bab 8.3.5 — belum berbunyi. Bunyi baru pada konfirmasi kedua.
        _set(state.copyWith(
          pendingResi: Validators.normalizeResi(raw),
        ));

      case ScanDecision.accepted:
        _set(state.copyWith(clearPending: true));
        unawaited(_onAccepted(result.resiCode!));

      case ScanDecision.stopRequested:
        unawaited(_stop(StopReason.secondScan));

      case ScanDecision.stopTooEarly:
        _notice(
          RecordingNoticeKind.stopTooEarly,
          seconds: _gate.secondsUntilScanStop,
        );
        unawaited(ref.read(scanFeedbackProvider).rejected());

      case ScanDecision.otherResiIgnored:
        _notice(RecordingNoticeKind.otherResi, resi: result.resiCode);
        unawaited(ref.read(scanFeedbackProvider).rejected());
    }
  }

  /// Kode terbaca tetapi jelas bukan nomor resi (Bab 8.3.1).
  ///
  /// Dibatasi sekali per 3 detik: pemindai membaca ± 18 frame per detik, dan
  /// label yang sama akan ditolak berulang kali selama kamera masih
  /// menghadapnya.
  void _noticeRejected() {
    final now = DateTime.now();
    final last = _lastRejectNotice;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _lastRejectNotice = now;
    _notice(RecordingNoticeKind.notAResi);
  }

  /// Sama seperti [_noticeRejected]: label yang sudah direkam akan terbaca
  /// belasan kali per detik selama kamera masih menghadapnya, jadi pesannya
  /// dibatasi sekali per 3 detik.
  void _noticeAlreadyRecorded(String resi) {
    final now = DateTime.now();
    final last = _lastAlreadyNotice;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _lastAlreadyNotice = now;
    _notice(RecordingNoticeKind.alreadyRecorded, resi: resi);
    unawaited(ref.read(scanFeedbackProvider).rejected());
  }

  // ---------- Mulai merekam ----------

  Future<void> _onAccepted(String resi) async {
    if (_busy) return;

    // Label yang barusan dipakai menghentikan rekaman masih ada di depan
    // kamera. Tanpa penolakan ini, perekamannya langsung dimulai ulang.
    if (_recordedInSession.contains(resi)) {
      _gate.reset();
      _noticeAlreadyRecorded(resi);
      return;
    }

    _busy = true;
    try {
      await ref.read(scanFeedbackProvider).accepted();

      // Bab 8.3.3 — tampilkan nomornya besar 1,5 detik sebelum perekaman
      // dimulai, agar packer sempat menyadari kalau salah baca.
      if (_strategy.requiresDoubleRead) {
        _set(state.copyWith(pendingResi: resi));
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (_disposed) return;
        _set(state.copyWith(clearPending: true));
      }

      // Bab 8.3.1 — pengecekan resi ganda dijalankan SEBELUM kamera merekam,
      // berlaku untuk ketiga mode. Jangan biarkan packer merekam 30 detik lalu
      // baru ditolak.
      if (await _isDuplicate(resi)) {
        _gate.reset();
        if (_dialogShownFor.add(resi)) {
          _set(state.copyWith(duplicate: DuplicateResi(resi)));
        } else {
          _notice(RecordingNoticeKind.alreadyRecorded, resi: resi);
        }
        return;
      }

      await _beginRecording(resi);
    } finally {
      _busy = false;
    }
  }

  /// `true` hanya bila server memastikan resi sudah ada.
  ///
  /// ⚠️ Kegagalan jaringan **tidak** memblokir perekaman. Aplikasi ini
  /// offline-first: packer di gudang tanpa sinyal harus tetap bisa merekam.
  /// Resi ganda yang lolos akan tertangkap server saat sinkronisasi lewat
  /// `23505` dan ditandai `duplicate` di antrian (Bab 7.7).
  Future<bool> _isDuplicate(String resi) async {
    _set(state.copyWith(checkingResi: true));
    final result = await ref.read(videoRepositoryProvider).resiExists(
          resiCode: resi,
          type: VideoType.packing,
        );
    if (_disposed) return false;
    _set(state.copyWith(checkingResi: false));

    return result.fold(
      onOk: (exists) => exists,
      onErr: (failure) {
        _log.w('Pengecekan resi ganda gagal — perekaman dilanjutkan', failure);
        return false;
      },
    );
  }

  Future<void> _beginRecording(String resi) async {
    final next = RecordingMachine.start(state.machine, resi);
    // Transisi tidak sah ditolak mesin status — mis. pembacaan beruntun yang
    // mencoba memulai perekaman kedua di atas yang pertama.
    if (next == null) return;

    // 🔴 CameraX membalik bingkai pratinjau **di tengah** `startVideoRecording`,
    // ± 620 ms sebelum panggilan itu kembali (diukur di Redmi Note 9,
    // 15 Agustus 2026). Bila koreksinya baru dibaca sesudahnya, pratinjau
    // tampak berputar selama 620 ms setiap kali perekaman dimulai. Karena itu
    // bingkainya dipantau **berbarengan**, bukan sesudahnya.
    _set(state.copyWith(previewSettling: true));

    final starting = _camera.startRecording(onFrame: _onFrame);
    unawaited(_followPreviewGeometry(starting));

    final result = await starting;
    if (_disposed) return;

    if (result.isErr) {
      _gate.reset();
      // Penutup wajib dibuka juga di jalur gagal — kalau tidak, pratinjau
      // tinggal hitam selamanya dan layarnya tampak mati.
      _set(state.copyWith(
        machine: RecordingMachine.fail(
          state.machine,
          result.failureOrNull?.messageKey ?? 'errorUnknown',
        ),
        previewSettling: false,
      ));
      return;
    }

    _startedAt = DateTime.now();
    _saidFinalCountdown = false;

    // 🔴 Memasang perekam menambah pemakai kamera yang ketiga, dan CameraX
    // dapat menjawabnya dengan mengganti bentuk bingkai pratinjau — yang
    // membuat pratinjau miring seperempat putaran bila dibiarkan. Ditanyakan di
    // sini, bukan ditebak; alasan lengkapnya di
    // `CameraService.readPreviewRotationCorrection`.
    final geometry = await _camera.readPreviewGeometry();
    if (_disposed) return;

    _set(state.copyWith(
      machine: next,
      clearFinished: true,
      previewGeometry: geometry,
    ));
    unawaited(_uncoverPreview());

    unawaited(_speak(_voice?.start(resi)));
    _ticker = Timer.periodic(const Duration(milliseconds: 200), _onTick);
  }

  /// Mengejar perubahan bingkai pratinjau selagi [until] masih berjalan.
  ///
  /// Berhenti pada perubahan pertama — begitu koreksinya berbeda, tidak ada
  /// lagi yang perlu dikejar. Batas 25 kali × 60 ms menjaga agar pemantauan
  /// tidak menggantung bila bingkainya memang tidak pernah berubah (perangkat
  /// `LEVEL_3` tidak menyalakan StreamSharing sama sekali).
  Future<void> _followPreviewGeometry(Future<void> until) async {
    var finished = false;
    unawaited(until.whenComplete(() => finished = true));

    for (var i = 0; i < 25; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (_disposed || finished) return;

      final geometry = await _camera.readPreviewGeometry();
      if (_disposed) return;
      if (geometry.quarterTurnCorrection !=
          state.previewGeometry.quarterTurnCorrection) {
        _set(state.copyWith(previewGeometry: geometry));
        return;
      }
    }
  }

  /// Membuka kembali pratinjau setelah bingkainya benar-benar tenang.
  ///
  /// 🔴 **Angka ini aman kelebihan, tidak aman kekurangan.** Metadata bingkai
  /// berubah lebih dulu; piksel yang sudah diputar baru menyusul entah berapa
  /// frame kemudian, dan Flutter tidak punya cara mengetahui kapan. Kelebihan
  /// jeda hanya membuat layar hitam sedikit lebih lama; kekurangan jeda
  /// membuat kedipan putarannya terlihat lagi.
  ///
  /// 400 ms diuji Product Owner 15 Agustus 2026 dan **masih kebobolan** pada
  /// kedua peralihan. Dinaikkan ke 1 detik. Bila suatu saat terasa terlalu
  /// lama, turunkan sedikit demi sedikit sambil diuji ulang di perangkat —
  /// jangan dipangkas berdasarkan dugaan.
  static const Duration _previewSettleGrace = Duration(seconds: 1);

  Future<void> _uncoverPreview() async {
    await Future<void>.delayed(_previewSettleGrace);
    if (_disposed) return;
    _set(state.copyWith(previewSettling: false));
  }

  // ---------- Pencatat waktu ----------

  void _onTick(Timer _) {
    final startedAt = _startedAt;
    if (_disposed || startedAt == null) return;

    final elapsed = DateTime.now().difference(startedAt);
    final machine = RecordingMachine.tick(state.machine, elapsed);

    _set(state.copyWith(
      machine: machine,
      secondsUntilScanStop: _gate.secondsUntilScanStop,
    ));

    // Bab 8.4 — "Lima detik lagi" diucapkan tepat sekali.
    if (machine.isFinalCountdown && !_saidFinalCountdown) {
      _saidFinalCountdown = true;
      unawaited(_speak(_voice?.fiveSeconds));
    }

    // Bab 8.3.1 — perekaman selalu berhenti otomatis pada batas durasi tier,
    // apa pun modenya.
    if (machine.hasReachedLimit) {
      _notice(RecordingNoticeKind.limitReached);
      unawaited(_stop(StopReason.durationLimit));
    }
  }

  // ---------- Berhenti ----------

  /// Tombol Berhenti (Bab 8.3.1 — satu-satunya cara yang pasti berfungsi).
  Future<void> stopManually() => _stop(StopReason.manual);

  Future<void> _stop(StopReason reason) async {
    // Mesin status menolak berhenti dua kali; tanpa penjagaan itu berkasnya
    // ditutup dua kali dan hasilnya rusak.
    final stopping = RecordingMachine.stop(state.machine, reason);
    if (stopping == null) return;

    _ticker?.cancel();
    _ticker = null;
    _busy = true;

    final resi = stopping.resiCode ?? '';
    final elapsed = stopping.elapsed;
    _set(state.copyWith(machine: stopping));

    _set(state.copyWith(previewSettling: true));

    final result = await _camera.stopRecording();
    if (_disposed) return;

    // Perekam dilepas — bingkai pratinjau kembali ke bentuk semula, jadi
    // koreksinya ikut ditarik kembali.
    final geometry = await _camera.readPreviewGeometry();
    if (_disposed) return;
    _set(state.copyWith(previewGeometry: geometry));
    unawaited(_uncoverPreview());

    await ref.read(scanFeedbackProvider).stopped();
    unawaited(_speak(_voice?.finished));

    await result.fold(
      onOk: (path) => _finish(path, resi, elapsed, reason),
      onErr: (failure) async {
        _log.e('Menghentikan perekaman gagal', failure);
        _set(state.copyWith(
          machine: RecordingMachine.fail(state.machine, failure.messageKey),
        ));
      },
    );

    _busy = false;
  }

  /// Berkas mentah sudah tertutup.
  ///
  /// 🔴 **Di sinilah Bab 8.5 (watermark FFmpeg) dan Bab 8.6 (antrian upload)
  /// akan disambungkan.** Keduanya belum dikerjakan, jadi untuk sekarang
  /// berkasnya hanya dilaporkan ke layar apa adanya.
  ///
  /// ⚠️ Konsekuensi yang sudah diketahui dan **belum tertangani**: rekaman
  /// mentah ± 370–500 KB per detik. Selama tahap ini belum ada, berkas mentah
  /// menumpuk di penyimpanan sementara aplikasi dan tidak pernah dihapus.
  /// Antrian upload nanti wajib menyimpan berkas **hasil proses**, bukan
  /// mentah, dan menghapus yang mentah begitu FFmpeg selesai.
  Future<void> _finish(
    String path,
    String resi,
    Duration elapsed,
    StopReason reason,
  ) async {
    var size = 0;
    try {
      size = await File(path).length();
    } on Object catch (e) {
      _log.w('Ukuran berkas tidak terbaca', e);
    }
    if (_disposed) return;

    await _rememberResi(resi);
    if (_disposed) return;

    _recordedInSession.add(resi);

    _set(state.copyWith(
      finished: FinishedRecording(
        resiCode: resi,
        path: path,
        sizeBytes: size,
        duration: elapsed,
        reason: reason,
      ),
    ));

    await _armForNextPackage();
  }

  /// Berapa lama ringkasan rekaman terakhir tetap terlihat.
  ///
  /// Cukup untuk dibaca sambil menggeser paket, tidak cukup lama untuk
  /// menghalangi paket berikutnya.
  static const Duration _finishedNoticeDuration = Duration(seconds: 4);

  /// Siap untuk resi berikutnya — **berjalan sendiri**, tanpa tombol.
  ///
  /// 🔴 Diputuskan Product Owner 15 Agustus 2026. Sebelumnya packer harus
  /// menekan "Rekam paket berikutnya" tiap kali; pada 100 paket itu berarti
  /// 100 ketukan yang tidak menghasilkan apa pun.
  ///
  /// Ringkasan rekaman tetap tampil sebentar, tetapi **tidak menghalangi** —
  /// pemindaian sudah hidup lagi di belakangnya. Konfirmasi bahwa rekaman
  /// berhasil tetap sampai lewat bunyi, getar, dan suara "selesai" (Bab 8.4),
  /// jadi packer tidak dibuat buta oleh hilangnya panel.
  Future<void> _armForNextPackage() async {
    _gate.reset();
    _startedAt = null;

    _set(state.copyWith(
      machine: RecordingMachine.next(state.machine),
      manual: const ManualEntry().copyWith(recent: state.manual.recent),
    ));

    await _startScanning();
    if (_disposed) return;

    unawaited(_hideFinishedNotice());
  }

  Future<void> _hideFinishedNotice() async {
    await Future<void>.delayed(_finishedNoticeDuration);
    if (_disposed) return;
    _set(state.copyWith(clearFinished: true));
  }

  // ---------- Mode Input Manual (Bab 8.3.4) ----------

  void setManualText(String raw) {
    _manualDebounce?.cancel();

    final text = Validators.normalizeResi(raw);
    final errorKey = text.isEmpty ? null : Validators.resiCode(text);

    _set(state.copyWith(
      manual: state.manual.copyWith(
        text: text,
        errorKey: errorKey,
        clearError: errorKey == null,
        duplicate: false,
        checking: errorKey == null && text.isNotEmpty,
      ),
    ));

    if (errorKey != null || text.isEmpty) return;

    // Bab 7.7 — pengecekan dijalankan saat pengguna berhenti mengetik, agar
    // peringatan muncul sebelum tombol Mulai Rekam ditekan.
    _manualDebounce = Timer(AppConstants.manualResiCheckDebounce, () async {
      final exists = await _isDuplicateQuiet(text);
      if (_disposed || state.manual.text != text) return;
      _set(state.copyWith(
        manual: state.manual.copyWith(checking: false, duplicate: exists),
      ));
    });
  }

  Future<bool> _isDuplicateQuiet(String resi) async {
    final result = await ref.read(videoRepositoryProvider).resiExists(
          resiCode: resi,
          type: VideoType.packing,
        );
    return result.getOrElse((_) => false);
  }

  void clearManual() => setManualText('');

  /// Papan klip kosong — layar yang membaca papan klip, ViewModel yang
  /// memutuskan apa yang terjadi.
  void reportEmptyClipboard() => _notice(RecordingNoticeKind.emptyClipboard);

  Future<void> startManualRecording() async {
    if (!state.manual.canStart || _busy) return;
    final resi = _gate.acceptManual(state.manual.text);
    if (resi == null) return;

    _busy = true;
    try {
      await ref.read(scanFeedbackProvider).accepted();
      await _beginRecording(resi);
    } finally {
      _busy = false;
    }
  }

  // ---------- Kendali lain ----------

  Future<void> toggleTorch() async {
    final next = !state.torchOn;
    final result = await _camera.setTorch(next);
    if (_disposed || result.isErr) return;
    _set(state.copyWith(torchOn: next));
  }

  void dismissNotice() => _set(state.copyWith(clearNotice: true));

  void dismissDuplicate() => _set(state.copyWith(clearDuplicate: true));

  // ---------- Pembantu ----------

  void _set(RecordingScreenState next) {
    if (_disposed) return;
    state = next;
  }

  void _notice(RecordingNoticeKind kind, {String? resi, int? seconds}) {
    _set(state.copyWith(
      notice: RecordingNotice(++_noticeId, kind, resi: resi, seconds: seconds),
    ));
  }

  Future<void> _speak(String? text) async {
    if (text == null) return;
    await ref.read(ttsServiceProvider).speak(text);
  }

  Future<List<String>> _loadRecentResi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(AppConstants.prefRecentResi) ?? const [];
  }

  Future<void> _rememberResi(String resi) async {
    if (resi.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = <String>[
      resi,
      ...(prefs.getStringList(AppConstants.prefRecentResi) ?? const [])
          .where((r) => r != resi),
    ].take(AppConstants.recentResiCount).toList();
    await prefs.setStringList(AppConstants.prefRecentResi, list);
    if (_disposed) return;
    _set(state.copyWith(manual: state.manual.copyWith(recent: list)));
  }
}
