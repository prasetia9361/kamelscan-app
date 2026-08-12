import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/logger.dart';
import 'notification_service.dart';

/// Implementasi Android/iOS.
///
/// Semua judul & isi notifikasi di sini masih berbahasa Indonesia karena
/// notifikasi dipicu dari isolate latar yang tidak punya `BuildContext`.
/// ⚠️ Saat Bab 9.11 dikerjakan, teks ini harus dibaca dari `SharedPreferences`
/// (`AppConstants.prefLanguage`) supaya ikut dwibahasa — catat sebagai utang.
class MobileNotificationService implements NotificationService {
  MobileNotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final AppLogger _log = const AppLogger('NotificationService');

  static const int _progressId = 1001;
  static const int _resultId = 1002;

  static const AndroidNotificationDetails _progressChannel =
      AndroidNotificationDetails(
    'upload_progress',
    'Progres unggah video',
    channelDescription: 'Menampilkan status antrian unggah video packing.',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    onlyAlertOnce: true,
    showProgress: true,
    indeterminate: true,
  );

  static const AndroidNotificationDetails _resultChannel =
      AndroidNotificationDetails(
    'upload_result',
    'Hasil unggah video',
    channelDescription: 'Memberi tahu saat unggahan selesai atau gagal.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  @override
  bool get isSupported => true;

  @override
  Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
  }

  @override
  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true) ?? false;
    } on Object catch (e, s) {
      _log.w('Permintaan izin notifikasi gagal', e);
      _log.e('detail', e, s);
      return false;
    }
  }

  @override
  Future<void> showUploadProgress({
    required int pending,
    required int total,
  }) async {
    if (pending <= 0) {
      await _plugin.cancel(id: _progressId);
      return;
    }
    await _plugin.show(
      id: _progressId,
      title: 'Mengunggah video',
      body: '$pending dari $total video menunggu koneksi',
      notificationDetails: const NotificationDetails(
        android: _progressChannel,
        iOS: DarwinNotificationDetails(presentSound: false),
      ),
    );
  }

  @override
  Future<void> showUploadComplete({required int uploaded}) async {
    await _plugin.cancel(id: _progressId);
    await _plugin.show(
      id: _resultId,
      title: 'Unggahan selesai',
      body: '$uploaded video berhasil tersimpan di cloud.',
      notificationDetails: const NotificationDetails(
        android: _resultChannel,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  @override
  Future<void> showUploadFailed({required String resiCode}) async {
    await _plugin.show(
      id: _resultId,
      title: 'Unggahan gagal',
      body: 'Video resi $resiCode belum terkirim. Akan dicoba lagi otomatis.',
      notificationDetails: const NotificationDetails(
        android: _resultChannel,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

NotificationService createPlatformNotificationService() =>
    MobileNotificationService();
