# Siklus Mobile

Aplikasi Flutter Android untuk laporan sampah, terhubung ke NestJS melalui `/api/v1`. Python/ML dipanggil oleh backend; tidak ada credential ML, R2 atau database dalam aplikasi.

## Fitur

- Login, register, kode verifikasi email 6 digit, kirim ulang kode, dan logout.
- JWT tersimpan sebagai satu pasangan di secure storage. Refresh satu kali untuk request bersamaan, retry sekali, dan logout lokal tidak dapat dibatalkan oleh refresh yang terlambat.
- Dashboard statistik dan laporan terbaru dari API.
- Daftar laporan dengan pencarian tertunda 400 ms, filter langsung dan paginasi.
- Foto kamera/galeri, pemulihan hasil picker setelah Android menutup proses, batas 5 MiB.
- GPS atas tindakan pengguna, penanganan izin/lokasi nonaktif, dan titik peta yang bisa diketuk. Koordinat readonly; tidak ada titik otomatis yang diam-diam dikirim.
- Detail foto dengan akses autentikasi, hasil klasifikasi dan skor model, lokasi, serta riwayat status.
- Edit dan hapus laporan PENDING. Admin dapat memproses status mengikuti aturan API.
- Tema terang/gelap/sistem, SafeArea, form bergulir, label dan tombol native Material.

## Menjalankan di HP melalui USB

Secara default aplikasi memakai backend online `https://api-bilcode-test.geats.web.id/api/v1`. Setelah APK terpasang, aplikasi hanya memerlukan internet; USB dan server lokal tidak diperlukan. ML diakses melalui backend.

Perintah di bawah khusus pengembangan dengan backend lokal:

```sh
source ~/.config/siklus/mobile-env.sh
cd /home/geats/Project/bilcode/mobile
flutter pub get
adb -s 67ab3673 reverse tcp:3001 tcp:3001
flutter run -d 67ab3673 --dart-define=API_BASE_URL=http://127.0.0.1:3001/api/v1
```

Backend dan ML harus berjalan untuk pengujian prediksi. Pastikan HP mengizinkan USB debugging. Ulangi reverse setelah kabel dilepas/reboot. Untuk emulator, ganti base URL ke `http://10.0.2.2:3001/api/v1`. Untuk perangkat tanpa USB, gunakan endpoint backend yang dapat dijangkau perangkat.

`API_BASE_URL` adalah konfigurasi build melalui `--dart-define`; perubahan memerlukan restart/build, bukan hot reload. HTTP hanya diizinkan pada build debug. Build distribusi memakai endpoint HTTPS dan konfigurasi signing sendiri. APK debug untuk demo bukan rilis Play Store.

```sh
flutter build apk --debug --target-platform android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:3001/api/v1
```

Hasil: `build/app/outputs/flutter-apk/app-debug.apk`.

## APK dengan backend online

```sh
source ~/.config/siklus/mobile-env.sh
cd /home/geats/Project/bilcode/mobile
flutter pub get
flutter build apk --release --dart-define-from-file=config/production.json
```

Hasil: `build/app/outputs/flutter-apk/app-release.apk` (versi 1.0.1+2, APK universal).

Build release memakai keystore khusus melalui `android/key.properties`, mengikuti format signing Flutter: `storeFile`, `storePassword`, `keyAlias`, dan `keyPassword`. Keystore dan file properties bersifat lokal, diabaikan Git, dan harus dicadangkan agar pembaruan APK dapat memakai identitas signing yang sama. Tanpa konfigurasi ini, build release belum dapat ditandatangani. URL dalam `config/production.json` bersifat publik dan tidak berisi credential.

Jika APK debug lama masih terpasang, Android menolak pembaruan langsung karena signing key berbeda. Hapus aplikasi debug terlebih dahulu sebelum memasang APK release; data lokal dan sesi login akan terhapus, sedangkan laporan di server tetap tersimpan.

## Struktur

- `lib/core/`: model API, secure session, jaringan dan state aplikasi.
- `lib/features/`: layar per alur.
- `lib/ui/`: tema dan komponen bersama, termasuk peta.
- `test/`: sesi/jaringan, layout, dan kontrak API nyata yang dinonaktifkan secara default.

Tidak ada akun atau password yang ditanam di source. Akun mengikuti seed/backend. Gunakan akun USER untuk demo alur pelapor; akun ADMIN melihat cakupan laporan sesuai otorisasi backend.

## Pemeriksaan

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Pengujian kontrak nyata memerlukan akun sementara dalam fixture `/tmp/bilcode-mobile-fixture.json` yang disiapkan operator pengujian, serta backend, PostgreSQL, R2 dan ML aktif. Fixture tidak disimpan ke repository:

```sh
flutter test test/backend_contract_test.dart --dart-define=BACKEND_SMOKE=true
```

Kontrak ini mencakup login, me, upload, prediksi, foto terlindungi, filter, edit, statistik, transisi status, penolakan edit laporan yang diproses, soft delete, rotasi refresh, penolakan token refresh lama dan logout. Akun/data sementara dibersihkan setelah pengujian; audit tetap tersimpan.

## Catatan

Peta memakai flutter_map dan tile OpenStreetMap dengan atribusi. Perlu internet untuk tile peta. Prediksi menampilkan satu kategori dan skor tidak terkalibrasi; ini bukan jaminan akurasi foto lapangan. Jika ML gagal, laporan tetap tersimpan dan aplikasi menampilkan kondisi tersebut.

Kamera dan GPS memerlukan izin pada HP. Tidak ada akses lokasi latar belakang. Foto hanya dikirim ketika pengguna menekan Kirim laporan. Tidak ada token, foto, koordinat atau credential yang dicatat oleh aplikasi.

Identitas mengikuti website Siklus yang telah disetujui. Arah visual dan alasan komponennya ada di `DESIGN.md`; aturan implementasi ada di `AGENTS.md`. Ikon launcher mengadaptasi Lucide Route yang sudah dipakai website; lisensinya dicantumkan di `THIRD_PARTY_NOTICES.txt`.
