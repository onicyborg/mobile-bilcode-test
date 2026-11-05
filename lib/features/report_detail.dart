import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../ui/common.dart';
import '../ui/location_map.dart';

class ReportDetailScreen extends StatefulWidget {
  final String id;
  const ReportDetailScreen({super.key, required this.id});
  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Future<WasteReport> future;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    future = context.read<AppState>().api.report(widget.id);
  }

  Future<void> refresh() async {
    setState(load);
    try {
      await future;
    } catch (_) {}
  }

  Future<void> remove() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus laporan ini?'),
        content: const Text(
          'Laporan akan dihapus dari riwayat dan tidak dapat diakses lagi dari aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus laporan'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await context.read<AppState>().api.request(
        '/reports/${widget.id}',
        method: 'DELETE',
      );
      if (mounted) {
        showMessage(context, 'Laporan dihapus.');
        context.go('/reports');
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> updateStatus(WasteReport r) async {
    final reason = TextEditingController();
    String selected = r.status == 'PENDING' ? 'IN_PROGRESS' : 'COMPLETED';
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Perbarui status'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Status baru'),
                  items:
                      [
                            r.status == 'PENDING' ? 'IN_PROGRESS' : 'COMPLETED',
                            'REJECTED',
                          ]
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(statusNames[s]!),
                            ),
                          )
                          .toList(),
                  onChanged: (s) => setLocal(() => selected = s!),
                ),
                if (selected == 'REJECTED') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reason,
                    decoration: const InputDecoration(
                      labelText: 'Alasan penolakan',
                    ),
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    validator: (v) =>
                        selected == 'REJECTED' && (v ?? '').trim().isEmpty
                        ? 'Tuliskan alasan penolakan.'
                        : null,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(c, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (accepted != true || !mounted) return;
    setState(() => busy = true);
    try {
      await context.read<AppState>().api.json(
        '/reports/${widget.id}/status',
        method: 'PATCH',
        data: {'status': selected, if (selected == 'REJECTED') 'reason': text},
      );
      if (mounted) {
        showMessage(context, 'Status laporan diperbarui.');
        refresh();
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail laporan'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang laporan',
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<WasteReport>(
          future: future,
          builder: (context, s) {
            if (s.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ErrorPanel(error: s.error!, retry: () => setState(load)),
                ],
              );
            }
            if (!s.hasData) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            final r = s.data!;
            final p = r.prediction;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Row(
                  children: [
                    StatusBadge(r.status),
                    const Spacer(),
                    Text(
                      '#${r.id.substring(r.id.length - 8)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  r.description,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateLabel(r.createdAt),
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ColoredBox(
                      color: const Color(0xFF23382D),
                      child: ReportPhoto(r.id, fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Perkiraan kategori',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        p == null
                            ? 'Prediksi tidak tersedia'
                            : categoryNames[p['category']] ?? p['category'],
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (p != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Skor model ${((p['confidence'] as num) * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        p == null
                            ? 'Laporan tetap tersimpan dan dapat ditindaklanjuti.'
                            : 'Hasil klasifikasi otomatis dapat keliru, terutama untuk sampah campuran.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const SectionTitle('Lokasi laporan'),
                LocationMap(point: LatLng(r.latitude, r.longitude)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${r.latitude.toStringAsFixed(6)}, ${r.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Buka lokasi di aplikasi peta',
                      onPressed: () async {
                        try {
                          await launchUrl(
                            Uri.parse(
                              'geo:${r.latitude},${r.longitude}?q=${r.latitude},${r.longitude}',
                            ),
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (_) {
                          if (context.mounted) {
                            showMessage(
                              context,
                              'Aplikasi peta tidak dapat dibuka.',
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionTitle('Perjalanan laporan'),
                Surface(
                  child: Column(
                    children: [
                      for (var i = 0; i < r.history.length; i++)
                        _HistoryItem(
                          r.history[i],
                          last: i == r.history.length - 1,
                        ),
                    ],
                  ),
                ),
                if (r.status == 'PENDING') ...[
                  const SizedBox(height: 24),
                  BusyButton(
                    busy: busy,
                    onPressed: () async {
                      await context.push('/reports/${r.id}/edit');
                      if (mounted) refresh();
                    },
                    label: 'Edit laporan',
                    icon: Icons.edit_outlined,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: busy ? null : remove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus laporan'),
                  ),
                ],
                if (context.read<AppState>().user?.role == 'ADMIN' &&
                    ['PENDING', 'IN_PROGRESS'].contains(r.status)) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => updateStatus(r),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Perbarui status'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final Json entry;
  final bool last;
  const _HistoryItem(this.entry, {required this.last});
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusNames[entry['toStatus']] ?? entry['toStatus'],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  dateLabel(entry['createdAt']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (entry['reason'] != null) ...[
                  const SizedBox(height: 8),
                  Text(entry['reason']),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
