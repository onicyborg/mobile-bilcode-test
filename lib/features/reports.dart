import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../ui/common.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final search = TextEditingController();
  Timer? debounce;
  String? status, category;
  List<WasteReport> items = [];
  int total = 0, page = 1, generation = 0;
  bool loading = true, moreBusy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    fetch();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> fetch({bool more = false}) async {
    if (more && moreBusy) return;
    final current = ++generation;
    setState(() {
      error = null;
      if (more) {
        moreBusy = true;
      } else {
        loading = true;
        page = 1;
      }
    });
    try {
      final result = await context.read<AppState>().api.reports(
        q: search.text.trim(),
        status: status,
        category: category,
        page: more ? page + 1 : 1,
      );
      if (!mounted || current != generation) return;
      setState(() {
        items = more ? [...items, ...result.items] : result.items;
        total = result.total;
        if (more) page++;
      });
    } catch (e) {
      if (mounted && current == generation) setState(() => error = e);
    } finally {
      if (mounted && current == generation) {
        setState(() {
          loading = false;
          moreBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Laporan'),
      actions: [
        IconButton(
          tooltip: 'Buat laporan',
          onPressed: () async {
            await context.push('/reports/new');
            if (mounted) fetch();
          },
          icon: const Icon(Icons.add),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Setiap laporan, satu langkah.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Pantau status dan hasil klasifikasi sampah.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: search,
            decoration: InputDecoration(
              labelText: 'Cari laporan',
              hintText: 'Deskripsi atau ID laporan',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        search.clear();
                        debounce?.cancel();
                        fetch();
                      },
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
            onChanged: (_) {
              setState(() {});
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 400), fetch);
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua')),
                    ...statusNames.entries.map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: (v) {
                    debounce?.cancel();
                    status = v;
                    fetch();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua')),
                    ...categoryNames.entries.map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: (v) {
                    debounce?.cancel();
                    category = v;
                    fetch();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            ErrorPanel(error: error!, retry: fetch)
          else ...[
            Text(
              '$total laporan',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              EmptyReports(
                filtered:
                    search.text.isNotEmpty ||
                    status != null ||
                    category != null,
              ),
            ...items.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ReportTile(r),
              ),
            ),
            if (items.length < total)
              OutlinedButton(
                onPressed: moreBusy ? null : () => fetch(more: true),
                child: Text(moreBusy ? 'Memuat…' : 'Muat laporan lainnya'),
              ),
          ],
        ],
      ),
    ),
  );
}
