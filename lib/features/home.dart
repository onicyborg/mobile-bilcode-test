import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(Json, ReportPage)> future;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    final api = context.read<AppState>().api;
    future = Future.wait([api.json('/dashboard/stats'), api.reports(limit: 3)])
        .then((x) => (x[0] as Json, x[1] as ReportPage));
  }

  Future<void> refresh() async {
    setState(load);
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), user = context.watch<AppState>().user;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: const Brand(),
        actions: [
          IconButton(
            tooltip: 'Akun saya',
            onPressed: () => context.go('/account'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Text(
              'Halo, ${user.name.split(' ').first}.',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Ada yang bisa kita benahi hari ini?',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: forest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.near_me_outlined, color: lime, size: 22),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'MULAI DARI SEKITARMU',
                          style: TextStyle(
                            color: lime,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Temukan sampah?\nBantu laporkan.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sertakan foto dan lokasi agar laporanmu lebih mudah ditindaklanjuti.',
                    style: TextStyle(
                      color: Color(0xFFD5E2D8),
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: lime,
                        foregroundColor: forest,
                      ),
                      onPressed: () async {
                        await context.push('/reports/new');
                        if (mounted) refresh();
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Buat laporan'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FutureBuilder<(Json, ReportPage)>(
              future: future,
              builder: (context, s) {
                if (s.hasError) {
                  return ErrorPanel(
                    error: s.error!,
                    retry: () => setState(load),
                  );
                }
                if (!s.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final (stats, reports) = s.data!;
                final byStatus = Map<String, dynamic>.from(stats['byStatus']);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      user.role == 'ADMIN'
                          ? 'Ringkasan laporan'
                          : 'Laporanmu sejauh ini',
                    ),
                    Surface(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Total laporan',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Text(
                                '${stats['total']}',
                                style: theme.textTheme.headlineMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Divider(),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: statusNames.entries
                                .map(
                                  (entry) => SizedBox(
                                    width:
                                        (MediaQuery.sizeOf(context).width
                                                .clamp(320, 600) -
                                            98) /
                                        2,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 3,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: entry.key == 'COMPLETED'
                                                ? const Color(0xFF4E8055)
                                                : theme.colorScheme.outline,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${byStatus[entry.key] ?? 0}',
                                                style:
                                                    theme.textTheme.titleLarge,
                                              ),
                                              Text(
                                                entry.value,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SectionTitle(
                      'Laporan terbaru',
                      action: TextButton(
                        onPressed: () => context.go('/reports'),
                        child: const Text('Lihat semua'),
                      ),
                    ),
                    if (reports.items.isEmpty)
                      const EmptyReports()
                    else
                      ...reports.items.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ReportTile(r),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
