import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../ui/common.dart';
import '../ui/location_map.dart';

class ReportFormScreen extends StatefulWidget {
  final String? id;
  const ReportFormScreen({super.key, this.id});
  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final form = GlobalKey<FormState>();
  final description = TextEditingController();
  final picker = ImagePicker();
  XFile? photo;
  LatLng? point;
  bool busy = false, locating = false, loading = false, picking = false;
  String? error;
  Object? loadError;
  bool get edit => widget.id != null;
  @override
  void initState() {
    super.initState();
    if (edit) {
      load();
    } else {
      recoverPhoto();
    }
  }

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final r = await context.read<AppState>().api.report(widget.id!);
      if (!mounted) return;
      description.text = r.description;
      setState(() => point = LatLng(r.latitude, r.longitude));
      if (r.status != 'PENDING') {
        throw const ApiFailure(
          'NOT_PENDING',
          'Laporan ini sudah diproses dan tidak dapat diedit.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => loadError = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> recoverPhoto() async {
    try {
      final lost = await picker.retrieveLostData();
      if (!mounted || lost.isEmpty) return;
      if (lost.files?.isNotEmpty ?? false) {
        await acceptPhoto(lost.files!.first);
      } else if (lost.exception != null) {
        setState(
          () => error = 'Foto belum berhasil dipilih. Silakan coba lagi.',
        );
      }
    } catch (_) {}
  }

  Future<void> acceptPhoto(XFile selected) async {
    if (await selected.length() > 5 * 1024 * 1024) {
      if (mounted) {
        setState(
          () =>
              error = 'Ukuran foto maksimal 5 MB. Pilih foto yang lebih kecil.',
        );
      }
      return;
    }
    if (mounted) {
      setState(() {
        photo = selected;
        error = null;
      });
    }
  }

  Future<void> pick(ImageSource source) async {
    setState(() => picking = true);
    try {
      final selected = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (selected != null) await acceptPhoto(selected);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Tidak dapat mengakses foto atau kamera. Periksa izin aplikasi di pengaturan HP.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> location() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          await settingsDialog(
            'Lokasi HP belum aktif. Aktifkan lokasi untuk mengambil posisi saat ini.',
            Geolocator.openLocationSettings,
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          await settingsDialog(
            'Izin lokasi diblokir. Izinkan lokasi melalui pengaturan aplikasi, atau pilih titik di peta.',
            Geolocator.openAppSettings,
          );
        }
        return;
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(
            () => error = 'Izin lokasi belum diberikan. Kamu tetap bisa memilih titik di peta.',
          );
        }
        return;
      }
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (mounted) setState(() => point = LatLng(fix.latitude, fix.longitude));
    } on TimeoutException {
      if (mounted) {
        setState(
          () => error = 'Lokasi belum ditemukan. Coba di area terbuka atau pilih titik di peta.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Lokasi tidak dapat diambil. Coba lagi atau pilih titik di peta.',
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> settingsDialog(
    String message,
    Future<bool> Function() open,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Akses lokasi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Pilih di peta'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Buka pengaturan'),
          ),
        ],
      ),
    );
    if (yes == true) await open();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (!edit && photo == null) {
      setState(() => error = 'Tambahkan foto sampah sebelum mengirim.');
      return;
    }
    if (point == null) {
      setState(
        () => error = 'Pilih titik di peta atau gunakan lokasi saat ini.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = context.read<AppState>().api;
      final fields = {
        'description': description.text.trim(),
        'latitude': point!.latitude,
        'longitude': point!.longitude,
      };
      final Json result;
      if (edit) {
        result = await api.json(
          '/reports/${widget.id}',
          method: 'PATCH',
          data: fields,
        );
      } else {
        final data = FormData.fromMap({
          ...fields,
          'photo': await MultipartFile.fromFile(
            photo!.path,
            filename: 'report.jpg',
          ),
        });
        result = Map<String, dynamic>.from(
          (await api.request('/reports', method: 'POST', data: data)).data,
        );
      }
      if (mounted) {
        showMessage(
          context,
          edit ? 'Perubahan laporan disimpan.' : 'Laporan berhasil dikirim.',
        );
        context.replace('/reports/${result['id']}');
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(edit ? 'Edit laporan' : 'Buat laporan')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: ErrorPanel(error: loadError!, retry: load),
              )
            : SafeArea(
                top: false,
                child: Form(
                  key: form,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      Text(
                        edit ? 'Perbarui detailnya.' : 'Apa yang kamu temukan?',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        edit ? 'Laporan dapat diedit selama masih menunggu.' : 'Foto dan titik lokasi membantu penanganan laporan.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 26),
                      if (!edit) ...[
                        const SectionTitle('01  Foto sampah'),
                        Surface(
                          child: Column(
                            children: [
                              if (photo != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AspectRatio(
                                    aspectRatio: 4 / 3,
                                    child: Image.file(
                                      File(photo!.path),
                                      fit: BoxFit.cover,
                                      semanticLabel:
                                          'Foto sampah yang akan dikirim',
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  height: 130,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 40,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text('Tunjukkan kondisi sampah'),
                                      const SizedBox(height: 6),
                                      Text(
                                        'JPEG atau PNG, maksimal 5 MB',
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
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: busy || picking
                                          ? null
                                          : () => pick(ImageSource.camera),
                                      icon: const Icon(
                                        Icons.photo_camera_outlined,
                                      ),
                                      label: const Text('Kamera'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: busy || picking
                                          ? null
                                          : () => pick(ImageSource.gallery),
                                      icon: const Icon(
                                        Icons.photo_library_outlined,
                                      ),
                                      label: const Text('Galeri'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                      ],
                      SectionTitle(
                        edit ? 'Lokasi laporan' : '02  Lokasi laporan',
                      ),
                      Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton.icon(
                              onPressed: busy || locating ? null : location,
                              icon: locating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location),
                              label: Text(
                                locating
                                    ? 'Mencari lokasi…'
                                    : 'Gunakan lokasi saat ini',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Ketuk peta untuk memilih atau mengoreksi titik.',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LocationMap(
                              point: point,
                              onSelect: busy
                                  ? null
                                  : (v) => setState(() => point = v),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    key: ValueKey('lat-${point?.latitude}'),
                                    initialValue:
                                        point?.latitude.toStringAsFixed(6) ??
                                        '',
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Lintang',
                                      hintText: 'Belum dipilih',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    key: ValueKey('lng-${point?.longitude}'),
                                    initialValue:
                                        point?.longitude.toStringAsFixed(6) ??
                                        '',
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Bujur',
                                      hintText: 'Belum dipilih',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      SectionTitle(
                        edit ? 'Deskripsi' : '03  Ceritakan kondisinya',
                      ),
                      TextFormField(
                        controller: description,
                        readOnly: busy,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi laporan',
                          hintText:
                              'Jenis sampah, kondisi, atau patokan lokasi…',
                          alignLabelWithHint: true,
                        ),
                        minLines: 4,
                        maxLines: 7,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Tambahkan deskripsi laporan.'
                            : null,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Notice(error!, error: true),
                      ],
                      const SizedBox(height: 18),
                      if (!edit) ...[
                        Text(
                          'Kategori sampah diperkirakan otomatis dari foto setelah laporan terkirim.',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      BusyButton(
                        busy: busy,
                        onPressed: picking || locating ? null : submit,
                        label: edit ? 'Simpan perubahan' : 'Kirim laporan',
                        icon: edit ? Icons.check : Icons.send_outlined,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
