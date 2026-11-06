import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => storage.read(key: 'siklus.session');
  @override
  Future<void> write(String value) =>
      storage.write(key: 'siklus.session', value: value);
  @override
  Future<void> clear() => storage.delete(key: 'siklus.session');
}

class ApiFailure implements Exception {
  final String code, message;
  final int? status;
  const ApiFailure(this.code, this.message, [this.status]);
  @override
  String toString() => message;
}

String friendlyError(Object error) {
  if (error is! ApiFailure) return 'Terjadi kendala. Silakan coba lagi.';
  return switch (error.code) {
    'INVALID_CREDENTIALS' => 'Email atau kata sandi tidak sesuai.',
    'EMAIL_NOT_VERIFIED' => 'Verifikasi email sebelum masuk.',
    'EMAIL_UNVERIFIED' => 'Verifikasi email sebelum masuk.',
    'INVALID_INPUT' => 'Periksa kembali data yang kamu masukkan.',
    'EMAIL_UNAVAILABLE' =>
      'Email sudah digunakan. Coba masuk atau verifikasi email.',
    'RATE_LIMITED' =>
      'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.',
    'PHOTO_TOO_LARGE' => 'Ukuran foto maksimal 5 MB.',
    'INVALID_PHOTO' => 'Gunakan foto JPEG atau PNG yang valid.',
    'SESSION_EXPIRED' => 'Sesi berakhir. Silakan masuk kembali.',
    'NETWORK' =>
      'Tidak dapat terhubung. Periksa internet dan koneksi ke server.',
    _ =>
      error.status == 503
          ? 'Layanan sedang tidak tersedia. Coba lagi sebentar.'
          : error.message,
  };
}

class ApiClient {
  final TokenStore store;
  final Dio http;
  Json? session;
  Future<void>? _refreshing;
  Future<void> _persisting = Future<void>.value();
  void Function()? onExpired;
  ApiClient({required this.store, Dio? dio})
    : http =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'https://api-bilcode-test.geats.web.id/api/v1',
              ),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 35),
              sendTimeout: const Duration(seconds: 35),
            ),
          );
  String? get accessToken => session?['accessToken'] as String?;
  Future<void> restore() async {
    final raw = await store.read();
    if (raw != null) {
      try {
        session = jsonDecode(raw) as Json;
      } catch (_) {
        await clear();
      }
    }
  }

  Future<void> _persist(Future<void> Function() operation) {
    final next = _persisting.then((_) => operation());
    _persisting = next.catchError((Object _) {});
    return next;
  }

  Future<void> save(Json value) async {
    session = value;
    await _persist(() => store.write(jsonEncode(value)));
  }

  Future<void> clear() async {
    session = null;
    await _persist(store.clear);
  }

  ApiFailure _failure(DioException e) {
    final d = e.response?.data;
    if (d is Map) {
      return ApiFailure(
        d['code']?.toString() ?? 'REQUEST_FAILED',
        d['message']?.toString() ?? 'Permintaan gagal.',
        e.response?.statusCode,
      );
    }
    return ApiFailure(
      e.response == null ? 'NETWORK' : 'REQUEST_FAILED',
      e.response == null
          ? 'Tidak dapat terhubung ke server.'
          : 'Permintaan gagal. Coba lagi.',
      e.response?.statusCode,
    );
  }

  Future<void> _rotate() async {
    try {
      final token = session?['refreshToken'];
      if (token == null) {
        throw const ApiFailure('SESSION_EXPIRED', 'Sesi berakhir.', 401);
      }
      final result = await http.post(
        '/auth/refresh',
        data: {'refreshToken': token},
      );
      if (session?['refreshToken'] != token) {
        throw const ApiFailure('SESSION_EXPIRED', 'Sesi sudah berubah.', 401);
      }
      await save(Map<String, dynamic>.from(result.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clear();
        onExpired?.call();
        throw const ApiFailure('SESSION_EXPIRED', 'Sesi berakhir.', 401);
      }
      throw _failure(e);
    }
  }

  Future<Response<dynamic>> request(
    String path, {
    String method = 'GET',
    dynamic data,
    Json? query,
    ResponseType? responseType,
    bool authenticated = true,
  }) async {
    final used = accessToken;
    Future<Response<dynamic>> send() => http.request(
      path,
      data: data is FormData ? data.clone() : data,
      queryParameters: query,
      options: Options(
        method: method,
        responseType: responseType,
        headers: authenticated && accessToken != null
            ? {'Authorization': 'Bearer $accessToken'}
            : null,
      ),
    );
    try {
      return await send();
    } on DioException catch (e) {
      if (authenticated && e.response?.statusCode == 401 && session != null) {
        if (accessToken == used) {
          final pending = _refreshing ??= _rotate();
          try {
            await pending;
          } finally {
            if (identical(_refreshing, pending)) _refreshing = null;
          }
        }
        try {
          return await send();
        } on DioException catch (retry) {
          if (retry.response?.statusCode == 401) {
            await clear();
            onExpired?.call();
          }
          throw _failure(retry);
        }
      }
      throw _failure(e);
    }
  }

  Future<Json> json(
    String path, {
    String method = 'GET',
    dynamic data,
    Json? query,
    bool authenticated = true,
  }) async => Map<String, dynamic>.from(
    (await request(
      path,
      method: method,
      data: data,
      query: query,
      authenticated: authenticated,
    )).data,
  );
  Future<ReportPage> reports({
    String q = '',
    String? status,
    String? category,
    int page = 1,
    int limit = 20,
  }) async => ReportPage.fromJson(
    await json(
      '/reports',
      query: {
        'q': q,
        'page': page,
        'limit': limit,
        'status': ?status,
        'category': ?category,
      },
    ),
  );
  Future<WasteReport> report(String id) async =>
      WasteReport.fromJson(await json('/reports/$id'));
  Future<Uint8List> photo(String id) async => Uint8List.fromList(
    List<int>.from(
      (await request(
        '/reports/$id/photo',
        responseType: ResponseType.bytes,
      )).data,
    ),
  );
}
