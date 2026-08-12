import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/enums.dart';
import '../models/package_video.dart';
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

  /// URL pemutaran bertanda tangan.
  ///
  /// ⚠️ Bab 2.2 catatan 5 — Edge Function `get-video-url` menolak pemanggil
  /// dengan `app_role = 'admin'`. Admin platform hanya boleh melihat metadata.
  Future<Result<String>> getPlaybackUrl(String videoId) async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.fnGetVideoUrl,
        body: {'video_id': videoId},
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
  Future<Result<String>> createPublicLink(String videoId) async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.fnCreatePublicLink,
        body: {'video_id': videoId},
      );
      final url = (response.data as Map?)?['public_url'] as String?;
      if (url == null) {
        return Result.err(SupabaseService.mapError('Tautan tidak diterima'));
      }
      return Result.ok(url);
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
