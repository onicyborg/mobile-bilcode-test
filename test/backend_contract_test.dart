import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siklus/core/api.dart';

import 'api_test.dart' show MemoryStore;

void main() {
  test(
    'mobile client integrates auth, upload, prediction, edit, filters and status lifecycle',
    () async {
      HttpOverrides.global = null;
      final fixture = jsonDecode(
        File('/tmp/bilcode-mobile-fixture.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final users = fixture['users'] as List;
      final clients = <ApiClient>[];
      for (final u in users) {
        final api = ApiClient(
          store: MemoryStore(),
          dio: Dio(
            BaseOptions(
              baseUrl: 'http://127.0.0.1:3001/api/v1',
              receiveTimeout: const Duration(seconds: 35),
            ),
          ),
        );
        final session = await api.json(
          '/auth/login',
          method: 'POST',
          authenticated: false,
          data: {'email': u['email'], 'password': u['password']},
        );
        await api.save(session);
        clients.add(api);
        expect((await api.json('/auth/me'))['id'], u['id']);
      }
      final user = clients[0], admin = clients[1];
      final data = FormData.fromMap({
        'description': 'Mobile integration: clothing pile',
        'latitude': 0,
        'longitude': 0,
        'photo': await MultipartFile.fromFile(
          '../temp-image/piles-of-used-clothes.jpg',
          filename: 'report.jpg',
        ),
      });
      final report = await user.json('/reports', method: 'POST', data: data);
      final id = report['id'] as String;
      expect(report['status'], 'PENDING');
      expect(report['prediction']['category'], 'CLOTHES');
      expect((await user.photo(id)).isNotEmpty, true);
      expect((await user.report(id)).history.length, 1);
      expect(
        (await user.reports(
          category: 'CLOTHES',
          q: 'Mobile integration',
        )).items.single.id,
        id,
      );
      expect((await user.json('/dashboard/stats'))['total'], 1);
      await user.json(
        '/reports/$id',
        method: 'PATCH',
        data: {
          'description': 'Mobile integration: updated clothing pile',
          'latitude': 1,
          'longitude': 2,
        },
      );
      expect(
        (await user.report(id)).description,
        'Mobile integration: updated clothing pile',
      );
      final old = user.session!['refreshToken'];
      final rotated = await user.json(
        '/auth/refresh',
        method: 'POST',
        authenticated: false,
        data: {'refreshToken': old},
      );
      await user.save(rotated);
      await expectLater(
        user.json(
          '/auth/refresh',
          method: 'POST',
          authenticated: false,
          data: {'refreshToken': old},
        ),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
      );
      await admin.json(
        '/reports/$id/status',
        method: 'PATCH',
        data: {'status': 'IN_PROGRESS'},
      );
      await expectLater(
        user.json(
          '/reports/$id',
          method: 'PATCH',
          data: {'description': 'Not allowed'},
        ),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 409)),
      );
      await admin.json(
        '/reports/$id/status',
        method: 'PATCH',
        data: {'status': 'COMPLETED'},
      );
      expect((await user.report(id)).history.length, 3);
      expect((await user.reports(status: 'COMPLETED')).items.single.id, id);
      final disposable = await user.json(
        '/reports',
        method: 'POST',
        data: FormData.fromMap({
          'description': 'Mobile integration: delete check',
          'latitude': 0,
          'longitude': 0,
          'photo': await MultipartFile.fromFile(
            '../temp-image/piles-of-used-clothes.jpg',
            filename: 'report.jpg',
          ),
        }),
      );
      await user.request('/reports/${disposable['id']}', method: 'DELETE');
      await expectLater(
        user.report(disposable['id']),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 404)),
      );
      expect((await user.json('/dashboard/stats'))['total'], 1);
      await user.request(
        '/auth/logout',
        method: 'POST',
        authenticated: false,
        data: {'refreshToken': user.session!['refreshToken']},
      );
      await expectLater(
        user.json(
          '/auth/refresh',
          method: 'POST',
          authenticated: false,
          data: {'refreshToken': user.session!['refreshToken']},
        ),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
      );
    },
    skip: !const bool.fromEnvironment('BACKEND_SMOKE'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
