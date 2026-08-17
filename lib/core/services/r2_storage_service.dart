import 'dart:io';

// `Headers` ada di dio **dan** di postgrest yang ikut terbawa
// supabase_flutter. Yang dipakai di sini milik dio.
import 'package:dio/dio.dart';
import 'package:dio/dio.dart' as dio_http show Headers;
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;

import '../config/app_constants.dart';
import '../utils/app_failure.dart';
import '../utils/logger.dart';
import '../utils/result.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

/// Unggah video ke Cloudflare R2 lewat presigned URL (Bab 8.7).
///
/// 🔴 **Aplikasi ini tidak pernah memegang kredensial R2.** Access key R2 dapat
/// membaca dan menghapus seluruh video seluruh pelanggan; yang dipegang di sini
/// hanyalah URL berumur 15 menit untuk satu berkas, diterbitkan Edge Function
/// `get-upload-url` setelah ia memastikan videonya memang milik pemanggil.
///
/// ⚠️ Bucket-nya bernama `kamelscan-videos`, **bukan** `scanproof-videos`
/// seperti tertulis di Bab 8.7 — nama itu berasal dari sebelum produk berganti
/// nama dan bucket-nya tidak ada. Namanya ditentukan Edge Function, jadi tidak
/// ada nama bucket di berkas ini sama sekali; catatan ini hanya agar tidak ada
/// yang mencoba "memperbaikinya" kembali ke nama dokumen.
class R2StorageService implements StorageService {
  R2StorageService(this._client, {Dio? dio}) : _dio = dio ?? Dio();

  final SupabaseClient _client;
  final Dio _dio;

  static const AppLogger _log = AppLogger('R2Storage');

  final Map<String, CancelToken> _cancelTokens = <String, CancelToken>{};

  @override
  Future<Result<PresignedUpload>> requestUploadUrl({
    required String videoId,
    required String storageKey,
    required int sizeBytes,
    required String contentType,
  }) async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.fnGetUploadUrl,
        body: {'video_id': videoId, 'content_length': sizeBytes},
      );

      final data = response.data;
      if (data is! Map) {
        return Result.err(
          SupabaseService.mapError('Jawaban get-upload-url tidak dikenali'),
        );
      }

      final error = data['error'];
      if (error != null) {
        // Pesan Edge Function sengaja diteruskan apa adanya ke log: `NOT_FOUND`
        // dan `FORBIDDEN` menunjuk sebab yang sangat berbeda, dan menyamarkan
        // keduanya jadi "gagal unggah" membuat diagnosisnya mustahil.
        _log.e('get-upload-url menolak: $error');
        return Result.err(SupabaseService.mapError('get-upload-url: $error'));
      }

      final url = data['url'] as String?;
      final key = data['key'] as String? ?? storageKey;
      final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 900;
      if (url == null || url.isEmpty) {
        return Result.err(
          SupabaseService.mapError('URL unggah tidak diterima'),
        );
      }

      return Result.ok(
        PresignedUpload(
          url: url,
          storageKey: key,
          expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
          headers: {'Content-Type': contentType},
        ),
      );
    } on Object catch (e, s) {
      return Result.err(SupabaseService.mapError(e, s));
    }
  }

  @override
  Future<Result<void>> uploadFile({
    required String localPath,
    required PresignedUpload target,
    void Function(int sent, int total)? onProgress,
    String? cancelToken,
  }) async {
    final file = File(localPath);
    try {
      // ignore: avoid_slow_async_io
      if (!await file.exists()) {
        return Result.err(
          AppFailure.storage('Berkas tidak ditemukan: $localPath'),
        );
      }
      final length = await file.length();

      final token = CancelToken();
      if (cancelToken != null) _cancelTokens[cancelToken] = token;

      // 🔴 `Content-Type` wajib sama persis dengan yang ikut ditandatangani
      // Edge Function (`video/mp4`). Bila berbeda, R2 menolak dengan
      // `SignatureDoesNotMatch` — pesan yang terdengar seperti masalah
      // kredensial, padahal kredensialnya benar.
      //
      // `Content-Length` juga wajib disebutkan sendiri: berkasnya dikirim
      // sebagai aliran agar video puluhan MB tidak perlu masuk memori
      // sekaligus, dan aliran tidak punya panjang yang dapat ditebak dio.
      await _dio.put<void>(
        target.url,
        data: file.openRead(),
        cancelToken: token,
        options: Options(
          headers: {
            ...target.headers,
            dio_http.Headers.contentLengthHeader: length,
          },
          sendTimeout: AppConstants.uploadChunkTimeout,
          receiveTimeout: AppConstants.uploadChunkTimeout,
        ),
        onSendProgress: onProgress,
      );

      return okVoid;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return Result.err(
          AppFailure.network.copyWith(debugMessage: 'Unggahan dibatalkan'),
        );
      }
      final status = e.response?.statusCode;
      _log.e('PUT ke R2 gagal (HTTP $status)', e.response?.data ?? e.message);
      return Result.err(
        AppFailure.network.copyWith(
          debugMessage: 'PUT ke R2 gagal (HTTP ${status ?? '-'})',
          code: status?.toString(),
        ),
      );
    } on Object catch (e) {
      return Result.err(AppFailure.network.copyWith(debugMessage: '$e'));
    } finally {
      if (cancelToken != null) _cancelTokens.remove(cancelToken);
    }
  }

  @override
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

  @override
  Future<void> cancelUpload(String cancelToken) async {
    _cancelTokens.remove(cancelToken)?.cancel('dibatalkan');
  }
}
