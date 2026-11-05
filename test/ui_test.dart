import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:siklus/core/api.dart';
import 'package:siklus/core/app_state.dart';
import 'package:siklus/main.dart';

import 'api_test.dart' show MemoryStore;

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('login validates and fits a narrow viewport in $mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppState(ApiClient(store: MemoryStore()))
        ..ready = true
        ..themeMode = mode;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: app,
          child: SiklusApp(state: app),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Siklus.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();
      expect(find.text('Masukkan email yang valid.'), findsOneWidget);
      expect(find.text('Kata sandi minimal 8 karakter.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });
  }
}
