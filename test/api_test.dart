import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siklus/core/api.dart';

class MemoryStore implements TokenStore {
  String? value;
  int writes = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
    writes++;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handler;
  Adapter(this.handler);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object value, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(value),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('concurrent 401s rotate once and retry with the new pair', () async {
    final store = MemoryStore();
    int refreshes = 0, successful = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = Adapter((o) async {
      if (o.path == '/auth/refresh') {
        refreshes++;
        expect(o.data['refreshToken'], 'old-refresh');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return jsonBody({
          'accessToken': 'new-access',
          'refreshToken': 'new-refresh',
          'user': {},
        });
      }
      if (o.headers['Authorization'] == 'Bearer old-access') {
        return jsonBody({'code': 'EXPIRED', 'message': 'Expired'}, 401);
      }
      expect(o.headers['Authorization'], 'Bearer new-access');
      successful++;
      return jsonBody({'ok': true});
    });
    final api = ApiClient(store: store, dio: dio);
    await api.save({
      'accessToken': 'old-access',
      'refreshToken': 'old-refresh',
      'user': {},
    });
    await Future.wait([api.json('/reports'), api.json('/dashboard/stats')]);
    expect(refreshes, 1);
    expect(successful, 2);
    expect(jsonDecode(store.value!)['refreshToken'], 'new-refresh');
    expect(store.writes, 2);
  });
  test('invalid refresh clears the session and requests login', () async {
    final store = MemoryStore();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = Adapter(
      (o) async =>
          jsonBody({'code': 'INVALID_CREDENTIALS', 'message': 'Invalid'}, 401),
    );
    final api = ApiClient(store: store, dio: dio);
    await api.save({
      'accessToken': 'old',
      'refreshToken': 'old-refresh',
      'user': {},
    });
    int expired = 0;
    api.onExpired = () => expired++;
    await expectLater(
      api.json('/reports'),
      throwsA(
        isA<ApiFailure>().having((e) => e.code, 'code', 'SESSION_EXPIRED'),
      ),
    );
    expect(api.session, isNull);
    expect(store.value, isNull);
    expect(expired, 1);
  });
  test(
    'refresh network outage preserves credentials for a later retry',
    () async {
      final store = MemoryStore();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = Adapter((o) async {
        if (o.path == '/auth/refresh') {
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonBody({'code': 'EXPIRED', 'message': 'Expired'}, 401);
      });
      final api = ApiClient(store: store, dio: dio);
      await api.save({
        'accessToken': 'old',
        'refreshToken': 'valid-refresh',
        'user': {},
      });
      await expectLater(
        api.json('/reports'),
        throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'NETWORK')),
      );
      expect(api.session?['refreshToken'], 'valid-refresh');
      expect(store.value, isNotNull);
    },
  );
  test('public auth requests do not send the existing access token', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = Adapter((o) async {
      expect(o.headers.containsKey('Authorization'), false);
      return jsonBody({'message': 'ok'});
    });
    final api = ApiClient(store: MemoryStore(), dio: dio);
    await api.save({
      'accessToken': 'private',
      'refreshToken': 'refresh',
      'user': {},
    });
    await api.json(
      '/auth/register',
      method: 'POST',
      authenticated: false,
      data: {'name': 'Test'},
    );
  });
  test(
    'multipart upload is replayable after an access-token refresh',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      int uploads = 0;
      dio.httpClientAdapter = Adapter((o) async {
        if (o.path == '/auth/refresh') {
          return jsonBody({
            'accessToken': 'new',
            'refreshToken': 'new-refresh',
            'user': {},
          });
        }
        uploads++;
        final form = o.data as FormData;
        expect(form.files.single.key, 'photo');
        expect(form.isFinalized, true);
        if (uploads == 1) {
          return jsonBody({'code': 'EXPIRED', 'message': 'Expired'}, 401);
        }
        return jsonBody({'id': 'report'});
      });
      final api = ApiClient(store: MemoryStore(), dio: dio);
      await api.save({
        'accessToken': 'old',
        'refreshToken': 'refresh',
        'user': {},
      });
      final form = FormData.fromMap({
        'photo': MultipartFile.fromBytes([1, 2, 3], filename: 'report.jpg'),
      });
      final result = await api.json('/reports', method: 'POST', data: form);
      expect(result['id'], 'report');
      expect(uploads, 2);
    },
  );
  test('a delayed refresh cannot revive a logged-out session', () async {
    final store = MemoryStore();
    final pending = Completer<ResponseBody>();
    final started = Completer<void>();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = Adapter((o) async {
      if (o.path == '/auth/refresh') {
        started.complete();
        return pending.future;
      }
      return jsonBody({'code': 'EXPIRED', 'message': 'Expired'}, 401);
    });
    final api = ApiClient(store: store, dio: dio);
    await api.save({
      'accessToken': 'old',
      'refreshToken': 'refresh',
      'user': {},
    });
    final request = api.json('/reports');
    final expectation = expectLater(request, throwsA(isA<ApiFailure>()));
    await started.future;
    await api.clear();
    pending.complete(
      jsonBody({'accessToken': 'new', 'refreshToken': 'rotated', 'user': {}}),
    );
    await expectation;
    expect(api.session, isNull);
    expect(store.value, isNull);
  });
}
