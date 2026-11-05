import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:siklus/core/api.dart';
import 'package:siklus/core/app_state.dart';
import 'package:siklus/core/models.dart';
import 'package:siklus/features/home.dart';
import 'package:siklus/ui/theme.dart';

import 'api_test.dart' show MemoryStore, Adapter, jsonBody;

void main() {
  testWidgets('dashboard supports large text and real empty-state structure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = Adapter(
      (o) async => jsonBody(
        o.path == '/dashboard/stats'
            ? {
                'total': 0,
                'byStatus': {
                  'PENDING': 0,
                  'IN_PROGRESS': 0,
                  'COMPLETED': 0,
                  'REJECTED': 0,
                },
              }
            : {'items': [], 'total': 0, 'page': 1, 'limit': 3},
      ),
    );
    final app = AppState(ApiClient(store: MemoryStore(), dio: dio))
      ..ready = true
      ..user = AppUser.fromJson({
        'id': 'test',
        'name': 'Pengujian',
        'email': 'test@example.test',
        'role': 'USER',
      });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(
          theme: siklusTheme(Brightness.light),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Total laporan'), 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Belum ada laporan'), 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
}
