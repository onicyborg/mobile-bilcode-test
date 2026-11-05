import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import 'theme.dart';

class Brand extends StatelessWidget {
  final bool inverse;
  const Brand({super.key, this.inverse = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: lime,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.route_outlined, color: forest, size: 23),
      ),
      const SizedBox(width: 10),
      Text(
        'Siklus.',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: inverse
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ],
  );
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionTitle(this.title, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    ),
  );
}

class ErrorPanel extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const ErrorPanel({super.key, required this.error, required this.retry});
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(friendlyError(error), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Coba lagi'),
        ),
      ],
    ),
  );
}

class Notice extends StatelessWidget {
  final String text;
  final bool error;
  const Notice(this.text, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? c.errorContainer : c.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: error ? c.onErrorContainer : c.onSecondaryContainer,
        ),
      ),
    );
  }
}

class BusyButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  const BusyButton({
    super.key,
    required this.busy,
    required this.onPressed,
    required this.label,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy) ...[
            const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
          ] else if (icon != null) ...[
            Icon(icon),
            const SizedBox(width: 10),
          ],
          Flexible(child: Text(busy ? 'Memproses…' : label)),
        ],
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (status) {
      'COMPLETED' => dark ? const Color(0xFFB5E4AD) : const Color(0xFF2C603A),
      'IN_PROGRESS' => dark ? const Color(0xFFBCD9FA) : const Color(0xFF285B89),
      'REJECTED' => dark ? const Color(0xFFFFB4AB) : const Color(0xFF922F2F),
      _ => dark ? const Color(0xFFF2D391) : const Color(0xFF805410),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusNames[status] ?? status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class ReportPhoto extends StatefulWidget {
  final String id;
  final BoxFit fit;
  const ReportPhoto(this.id, {super.key, this.fit = BoxFit.cover});
  @override
  State<ReportPhoto> createState() => _ReportPhotoState();
}

class _ReportPhotoState extends State<ReportPhoto> {
  late Future<Uint8List> future;
  @override
  void initState() {
    super.initState();
    future = context.read<AppState>().api.photo(widget.id);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return Image.memory(
          snapshot.data!,
          fit: widget.fit,
          semanticLabel: 'Foto sampah pada laporan',
          cacheWidth: 1000,
        );
      }
      if (snapshot.hasError) {
        return Center(
          child: IconButton(
            tooltip: 'Muat ulang foto',
            onPressed: () => setState(
              () => future = context.read<AppState>().api.photo(widget.id),
            ),
            icon: const Icon(Icons.refresh),
          ),
        );
      }
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.photo_outlined)),
      );
    },
  );
}

class ReportTile extends StatelessWidget {
  final WasteReport report;
  const ReportTile(this.report, {super.key});
  @override
  Widget build(BuildContext context) => Surface(
    padding: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/reports/${report.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80,
                height: 92,
                child: ReportPhoto(report.id),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    dateLabel(report.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 9),
                  StatusBadge(report.status),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.chevron_right, size: 20),
            ),
          ],
        ),
      ),
    ),
  );
}

class EmptyReports extends StatelessWidget {
  final bool filtered;
  const EmptyReports({super.key, this.filtered = false});
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      children: [
        const Icon(Icons.inventory_2_outlined, size: 38),
        const SizedBox(height: 16),
        Text(
          filtered ? 'Tidak ada laporan yang cocok' : 'Belum ada laporan',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          filtered
              ? 'Coba ubah pencarian atau filter.'
              : 'Foto sampah di sekitarmu dan kirim laporan pertama.',
          textAlign: TextAlign.center,
        ),
        if (!filtered) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.push('/reports/new'),
            icon: const Icon(Icons.add),
            label: const Text('Buat laporan'),
          ),
        ],
      ],
    ),
  );
}

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
