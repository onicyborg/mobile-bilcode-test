import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:siklus/core/api.dart';
import 'package:siklus/core/app_state.dart';
import 'package:siklus/main.dart';

import 'api_test.dart' show MemoryStore;

void main() {
  for (final path in ['/login', '/register', '/verify']) {
    testWidgets('$path supports large text on a small screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = AppState(ApiClient(store: MemoryStore()))..ready = true;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: app,
          child: SiklusApp(state: app),
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.text('Siklus.'))).go(path);
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });
  }
}
