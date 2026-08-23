import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/enums.dart';
import '../models/history_item.dart';
import '../models/package_video.dart';
import '../models/public_video.dart';
import '../models/upload_task.dart';
import '../services/supabase_service.dart';
import '../utils/result.dart';

/// Filter daftar riwayat (Bab 9 / Bab 10).
class VideoFilter {
  const VideoFilter({
    this.resiQuery,
    this.shopId,
    this.type,
    this.status,
    this.userId,
    this.from,
    this.to,
  });

  final String? resiQuery;
  final String? shopId;
  final VideoType? type;
  final VideoStatus? status;
  final String? userId;
  final DateTime? from;
  final DateTime? to;

  bool get isEmpty =>
      resiQuery == null &&
      shopId == null &&
      type == null &&
      status == null &&
      userId == null &&
      from == null &&
      to == null;
}

/// Hasil `create-public-link` (Bab 8.8).
class PublicLink {
  const PublicLink({required this.url, this.expiresAt, this.reused = false});

  final String url;

  /// Sama dengan `expires_at` videonya — tautan tidak boleh hidup lebih lama
  /// daripada berkas yang ditunjuknya.
  final DateTime? expiresAt;

  /// `true` bila tautan lama yang masih berlaku dipakai ulang.
  final bool reused;
}

class VideoRepository {
  const VideoRepository(this._client);

  final SupabaseClient _client;

  /// Riwayat video. RLS menentukan cakupan yang terlihat: Owner melihat seluruh
  /// tenant, packer hanya rekamannya sendiri kecuali Owner mengaktifkan
  /// `shop_history_visible_to_packer` (Bab 2.2 catatan 3).
  Future<Result<List<PackageVideo>>> fetchVideos({
    VideoFilter filter = const VideoFilter(),
    int page = 0,
    int pageSize = AppConstants.historyPageSize,
  }) async {
    try {
      var query = _client.from(AppConstants.tblPackageVideos).select();

      if (filter.shopId != null) query = query.eq('shop_id', filter.shopId!);
      if (filter.userId != null) query = query.eq('user_id', filter.userId!);
      if (filter.type != null) query = query.eq('type', filter.type!.wire);
      if (filter.status != null) {
        query = query.eq('status', filter.status!.wire);
      } else {
        // Video terhapus tidak pernah muncul di riwayat.
        query = query.neq('status', VideoStatus.deleted.wire);
      }
      if (filter.resiQuery != null && filter.resiQuery!.isNotEmpty) {
        query = query.ilike('resi_code', '%${filter.resiQuery}%');
      }
      if (filter.from != null) {
        query = query.gte('scan_date', filter.from!.toUtc().toIso8601String());
      }
      if (filter.to != null) {
        query = query.lte('scan_date', filter.to!.toUtc().toIso8601String());
      }

      final rows = await query
          .order('scan_date', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return Result.ok(
        rows.map((r) => PackageVideo.fromJson(r)).toList(growable: false),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Riwayat beserta nama toko dan nama perekamnya (Bab 9.4).
  ///
  /// Sama dengan [fetchVideos], hanya menambahkan **embedding** ke `shops` dan
  /// `users` supaya daftar dapat menampilkan "Shopee · Toko Kamel" tanpa 20
  /// permintaan tambahan per halaman.
  ///
  /// ⚠️ Embedding tetap tunduk RLS. `shops_select` dan `users_select_self_or_tenant`
  /// keduanya mengizinkan seluruh anggota tenant membaca barisnya, jadi
  /// namanya terisi untuk packer maupun Owner. Bila policy itu kelak
  /// diperketat, yang muncul bukan error melainkan nama yang kosong — periksa
  /// ke sana lebih dulu sebelum menduga masalahnya di Dart.
  Future<Result<List<HistoryItem>>> fetchHistory({
    VideoFilter filter = const VideoFilter(),
    int page = 0,
    int pageSize = AppConstants.historyPageSize,
  }) async {
    try {
      var query = _client.from(AppConstants.tblPackageVideos).select(
            '*, shops(shop_name, market_name), users(full_name)',
          );

      if (filter.shopId != null) query = query.eq('shop_id', filter.shopId!);
      if (filter.userId != null) query = query.eq('user_id', filter.userId!);
      if (filter.type != null) query = query.eq('type', filter.type!.wire);
      if (filter.status != null) {
        query = query.eq('status', filter.status!.wire);
      } else {
        query = query.neq('status', VideoStatus.deleted.wire);
      }
      if (filter.resiQuery != null && filter.resiQuery!.isNotEmpty) {
        query = query.ilike('resi_code', '%${filter.resiQuery}%');
      }
      if (filter.from != null) {
        query = query.gte('scan_date', filter.from!.toUtc().toIso8601String());
      }
      if (filter.to != null) {
        query = query.lte('scan_date', filter.to!.toUtc().toIso8601String());
      }

      final rows = await query
          .order('scan_date', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return Result.ok(
        rows.map((r) => HistoryItem.fromJson(r)).toList(growable: false),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Satu video beserta konteksnya, untuk halaman detail (Bab 9.4).
  Future<Result<HistoryItem>> fetchHistoryItem(String id) async {
    try {
      final row = await _client
          .from(AppConstants.tblPackageVideos)
          .select('*, shops(shop_name, market_name), users(full_name)')
          .eq('id', id)
          .single();
      return Result.ok(HistoryItem.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  Future<Result<PackageVideo>> fetchVideo(String id) async {
    try {
      final row = await _client
          .from(AppConstants.tblPackageVideos)
          .select()
          .eq('id', id)
          .single();
      return Result.ok(PackageVideo.fromJson(row));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Bab 7.7 — pengecekan resi ganda dijalankan **sebelum** kamera menyala,
  /// lewat RPC ringan `resi_exists`. Jangan biarkan packer merekam 30 detik
  /// lalu baru ditolak.
  Future<Result<bool>> resiExists({
    required String resiCode,
    required VideoType type,
  }) async {
    try {
      final result = await _client.rpc<bool>(
        'resi_exists',
        params: {'p_resi': resiCode, 'p_type': type.wire},
      );
      return Result.ok(result);
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Pastikan baris `package_videos` untuk satu tugas antrian sudah ada
  /// (Bab 8.7 langkah 3 — Edge Function `get-upload-url` menolak video yang
  /// barisnya belum ada).
  ///
  /// 🔴 Barisnya sengaja **baru dibuat saat mengunggah**, bukan saat merekam.
  /// Aplikasi ini offline-first: packer di gudang tanpa sinyal tidak dapat
  /// menyisipkan apa pun ke server, dan menunda perekaman sampai ada sinyal
  /// berarti menghapus alasan produk ini ada.
  ///
  /// Yang **tidak** dikirim dari sini: `tenant_id`, `scan_date`, dan
  /// `expires_at`. Ketiganya diisi trigger `before_video_insert` dengan waktu
  /// server, dan di situlah tempatnya — nilai dari perangkat dapat dipalsukan.
  Future<Result<PackageVideo>> ensureVideoRow(UploadTask task) async {
    try {
      final row = await _client
          .from(AppConstants.tblPackageVideos)
          .insert({
            'id': task.videoId,
            'shop_id': task.shopId,
            'user_id': task.userId,
            'resi_code': task.resiCode,
            'type': task.type.wire,
            'device_started_at': task.deviceStartedAt?.toUtc().toIso8601String(),
            'duration_seconds': task.durationSeconds > 0
                ? task.durationSeconds
                : null,
            'file_size_bytes': task.bytesTotal,
            'location_lat': task.lat,
            'location_lng': task.lng,
            'location_accuracy_m': task.locationAccuracyM,
            'storage_key': task.storageKey.isEmpty ? null : task.storageKey,
            'time_verified': task.timeVerified,
          })
          .select()
          .single();
      return Result.ok(PackageVideo.fromJson(row));
    } on Object catch (e, s) {
      final failure = SupabaseService.mapError(e, s);

      // `23505` bisa berarti dua hal yang sangat berbeda, dan membedakannya
      // menentukan apakah video pelanggan terkirim atau dibuang:
      //
      //  a. barisnya memang sudah kita buat pada percobaan unggah sebelumnya
      //     yang putus di tengah — lanjutkan saja;
      //  b. resi yang sama sudah pernah direkam (Bab 7.7) — ini yang harus
      //     ditandai `duplicate` dan menunggu keputusan pengguna.
      if (failure.code == '23505') {
        final existing = await fetchVideo(task.videoId);
        if (existing.isOk) return existing;
      }
      return Result.err(failure);
    }
  }

  /// Tandai video sudah terunggah — inilah yang memotong 1 token lewat trigger
  /// `after_video_uploaded` (Bab 7.2: token dipotong saat **unggah berhasil**,
  /// bukan saat merekam).
  Future<Result<void>> markUploaded({
    required String videoId,
    required String storageKey,
    required int fileSizeBytes,
    required int durationSeconds,
  }) async {
    try {
      await _client
          .from(AppConstants.tblPackageVideos)
          .update({
            'status': VideoStatus.uploaded.wire,
            'uploaded_at': DateTime.now().toUtc().toIso8601String(),
            'storage_key': storageKey,
            'file_size_bytes': fileSizeBytes,
            if (durationSeconds > 0) 'duration_seconds': durationSeconds,
          })
          .eq('id', videoId);
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Catat kegagalan unggah pada barisnya, agar Riwayat dapat menjelaskan
  /// mengapa sebuah video belum ada isinya (Bab 8.7 langkah 6).
  Future<Result<void>> recordUploadFailure({
    required String videoId,
    required int attempts,
    required String message,
  }) async {
    try {
      await _client
          .from(AppConstants.tblPackageVideos)
          .update({
            'upload_attempts': attempts,
            'last_error': message,
            if (attempts >= AppConstants.maxUploadAttempts)
              'status': VideoStatus.failed.wire,
          })
          .eq('id', videoId);
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// URL pemutaran bertanda tangan.
  ///
  /// ⚠️ Bab 2.2 catatan 5 — Edge Function `get-video-url` menolak pemanggil
  /// dengan `app_role = 'admin'`. Admin platform hanya boleh melihat metadata.
  ///
  /// [forDownload] menentukan bagaimana R2 menyajikan berkasnya. Untuk
  /// **menonton** ia disajikan apa adanya agar pemutar dapat melompat ke tengah
  /// video; untuk **mengunduh** ia diberi nama berkas bernomor resi, supaya
  /// packer yang mengirimkannya ke pusat resolusi marketplace tidak perlu
  /// membuka satu per satu untuk tahu isinya yang mana.
  Future<Result<String>> getPlaybackUrl(
    String videoId, {
    bool forDownload = false,
  }) async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.fnGetVideoUrl,
        body: {'video_id': videoId, 'download': forDownload},
      );
      final url = (response.data as Map?)?['url'] as String?;
      if (url == null) {
        return Result.err(SupabaseService.mapError('URL tidak diterima'));
      }
      return Result.ok(url);
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Buat tautan publik. Hanya Owner (Bab 2.2).
  ///
  /// Masa berlakunya ikut dikembalikan karena Bab 9.4 mewajibkan angka itu
  /// ditampilkan saat tautannya disalin — pusat resolusi marketplace kadang
  /// baru membukanya beberapa hari kemudian, dan Owner perlu tahu sampai kapan
  /// tautannya masih hidup sebelum mengirimkannya.
  ///
  /// Edge Function-nya **idempoten**: tautan yang masih berlaku dipakai ulang,
  /// jadi menekan tombolnya dua kali tidak mematikan tautan yang sudah
  /// terkirim.
  Future<Result<PublicLink>> createPublicLink(String videoId) async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.fnCreatePublicLink,
        body: {'video_id': videoId},
      );
      final data = response.data as Map?;
      final url = data?['public_url'] as String?;
      if (url == null) {
        return Result.err(SupabaseService.mapError('Tautan tidak diterima'));
      }
      return Result.ok(
        PublicLink(
          url: url,
          expiresAt: DateTime.tryParse((data?['expires_at'] ?? '') as String),
          reused: data?['reused'] == true,
        ),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Isi halaman bukti publik `/v/{token}` (Bab 10.6).
  ///
  /// 🔴 Dipanggil **tanpa sesi login** — ini satu-satunya jalur seperti itu di
  /// aplikasi. Yang menjaganya token 160 bit pada tautannya, dan Edge Function
  /// `get-public-video` hanya mengembalikan isi bukti: tidak ada `tenant_id`,
  /// `user_id`, maupun `storage_key`.
  Future<Result<PublicVideo>> fetchPublicVideo(String token) async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.fnGetPublicVideo,
        body: {'token': token},
      );
      final data = response.data as Map?;
      if (data == null || data['url'] == null) {
        return Result.err(SupabaseService.mapError('Tautan tidak berlaku'));
      }
      return Result.ok(PublicVideo.fromJson(Map<String, dynamic>.from(data)));
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  /// Hapus video (soft delete).
  ///
  /// Status `deleted` mengeluarkan baris dari partial unique index
  /// `uq_resi_per_tenant_type`, sehingga resi yang sama boleh direkam ulang
  /// (Bab 7.7).
  Future<Result<void>> deleteVideo(String id) async {
    try {
      await _client
          .from(AppConstants.tblPackageVideos)
          .update({'status': VideoStatus.deleted.wire})
          .eq('id', id);
      return okVoid;
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }
}
