import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/api.dart';
import 'core/app_state.dart';
import 'features/auth.dart';
import 'features/home.dart';
import 'features/reports.dart';
import 'features/report_form.dart';
import 'features/report_detail.dart';
import 'features/account.dart';
import 'ui/theme.dart';
import 'ui/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final state = AppState(ApiClient(store: SecureTokenStore()));
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: SiklusApp(state: state),
    ),
  );
  unawaited(state.bootstrap());
}

class SiklusApp extends StatefulWidget {
  final AppState state;
  const SiklusApp({super.key, required this.state});
  @override
  State<SiklusApp> createState() => _SiklusAppState();
}

class _SiklusAppState extends State<SiklusApp> {
  late final GoRouter router;
  @override
  void initState() {
    super.initState();
    router = GoRouter(
      initialLocation: '/',
      refreshListenable: widget.state,
      redirect: (context, state) {
        final app = widget.state;
        final path = state.uri.path;
        final public = ['/login', '/register', '/verify'].contains(path);
        if (!app.ready) return path == '/boot' ? null : '/boot';
        if (app.user == null) return public ? null : '/login';
        if (public || path == '/boot') return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/boot',
          builder: (_, _) => const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Brand(),
                  SizedBox(height: 24),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
        for (final mode in ['login', 'register', 'verify'])
          GoRoute(
            path: '/$mode',
            builder: (_, state) => AuthScreen(
              key: ValueKey('$mode-${state.uri.queryParameters['email']}'),
              mode: mode,
              email: state.uri.queryParameters['email'] ?? '',
            ),
          ),
        ShellRoute(
          builder: (context, state, child) =>
              _AppShell(path: state.uri.path, child: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
            GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
            GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
          ],
        ),
        GoRoute(
          path: '/reports/new',
          builder: (_, _) => const ReportFormScreen(),
        ),
        GoRoute(
          path: '/reports/:id',
          builder: (_, state) =>
              ReportDetailScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/reports/:id/edit',
          builder: (_, state) =>
              ReportFormScreen(id: state.pathParameters['id']!),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Halaman tidak ditemukan')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Kembali ke beranda'),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp.router(
      title: 'Siklus',
      debugShowCheckedModeBanner: false,
      theme: siklusTheme(Brightness.light),
      darkTheme: siklusTheme(Brightness.dark),
      themeMode: app.themeMode,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}

class _AppShell extends StatelessWidget {
  final String path;
  final Widget child;
  const _AppShell({required this.path, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(bottom: false, top: false, child: child),
    bottomNavigationBar: NavigationBar(
      selectedIndex: path == '/reports'
          ? 1
          : path == '/account'
          ? 2
          : 0,
      onDestinationSelected: (i) =>
          context.go(['/', '/reports', '/account'][i]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(Icons.space_dashboard),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'Laporan',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Akun',
        ),
      ],
    ),
  );
}
