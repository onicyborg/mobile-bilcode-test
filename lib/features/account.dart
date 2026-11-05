import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>(),
        theme = Theme.of(context),
        user = app.user;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: lime,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    user.name.isEmpty
                        ? 'S'
                        : user.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: forest,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  user.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.email,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 18),
                    const SizedBox(width: 7),
                    Text(
                      'Email terverifikasi · ${user.role == 'ADMIN' ? 'Admin' : 'Pelapor'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionTitle('Tampilan aplikasi'),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tema',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<ThemeMode>(
                  initialValue: app.themeMode,
                  decoration: const InputDecoration(
                    labelText: 'Pilih tampilan',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Ikuti perangkat'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Terang'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Gelap'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) app.setTheme(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionTitle('Tentang Siklus'),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Brand(),
                const SizedBox(height: 14),
                Text(
                  'Laporan sampah dengan foto, lokasi, dan klasifikasi gambar. Pantau perkembangannya dari satu tempat.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Versi 1.0.0', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Keluar dari akun?'),
                        content: const Text(
                          'Kamu dapat masuk kembali kapan saja.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Keluar'),
                          ),
                        ],
                      ),
                    );
                    if (yes == true && mounted) {
                      setState(() => busy = true);
                      await app.logout();
                    }
                  },
            icon: const Icon(Icons.logout),
            label: Text(busy ? 'Keluar…' : 'Keluar dari akun'),
          ),
        ],
      ),
    );
  }
}
