# 🏢 Aplikasi Presensi Karyawan

[![Flutter](https://img.shields.io/badge/Flutter-3.27%2B-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.5%2B-blue.svg)](https://dart.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey.svg)](#-dukungan-platform)

Aplikasi presensi karyawan berbasis Flutter: presensi **WFO/WFH/WFA** dengan
validasi lokasi di peta, verifikasi wajah di perangkat, pengajuan izin & cuti
berlampiran, lembur, dan riwayat kehadiran.

Identitas aplikasi (nama, logo, warna), aturan presensi, konfigurasi peta,
versi minimum, dan mode pemeliharaan **diambil dari API** lewat
`GET /api/app-settings` — admin bisa mengubahnya dari panel tanpa rilis baru.

---

## 📚 Dokumentasi Terkait

| Dokumen | Isi |
| --- | --- |
| [`API_DOCUMENTATION.md`](API_DOCUMENTATION.md) | Referensi endpoint lengkap |
| [`api-fitur-baru.md`](api-fitur-baru.md) | Endpoint baru: WFH/WFA, peta pra-presensi, lampiran izin, ubah password, pengaturan aplikasi |
| [`docs/RELEASE.md`](docs/RELEASE.md) | Panduan rilis Play Store, App Store, dan web |

---

## ✨ Fitur

### 🔐 Autentikasi & Sesi

- Login dengan rate limit sisi server (5 percobaan/menit per email+IP).
- Token disimpan lokal; saat server menjawab **401**, sesi otomatis dibersihkan
  dan pengguna diarahkan kembali ke halaman masuk.
- **Keluar dari semua perangkat** (`POST /api/logout-all`).
- Ubah password dengan aturan yang sama persis dengan validasi server:
  minimal 8 karakter, mengandung huruf dan angka, dan berbeda dari password
  lama. Perangkat lain otomatis dikeluarkan.

### 📍 Presensi WFO / WFH / WFA

Beranda punya **dua pintu masuk terpisah**, karena aturannya memang berbeda:

| Menu | Mode | Validasi radius | Foto & catatan |
| --- | --- | :---: | --- |
| **Absen Masuk / Absen Pulang** | WFO | ✅ wajib di dalam radius kantor | sesuai `photo_required` |
| **Absen Masuk WFH/WFA** (kartu tersendiri) | WFH / WFA | ➖ tidak divalidasi | foto & catatan aktivitas umumnya wajib |

Kartu WFH/WFA hanya muncul bila admin memberi akun mode kerja jarak jauh, dan
khusus untuk **memulai** hari kerja. Absen pulang tidak bergantung mode —
server memakai mode dari data absen masuk — jadi jalurnya tetap satu lewat
tombol *Absen Pulang*.

Seluruh alur presensi ditentukan satu request `GET /api/attendance/pre-check`,
jadi aplikasi tidak menebak aturan sendiri dan server tetap memvalidasi ulang:

- **Peta pra-presensi** — posisi pengguna, pin kantor, dan lingkaran radius
  (hijau bila di dalam radius, merah bila di luar) memakai tile yang
  dikonfigurasi admin.
- **Pilihan mode kerja** hanya menampilkan mode yang diizinkan untuk akun ini
  **dan** sesuai pintu masuk yang dipakai. Saat absen pulang, mode terkunci
  mengikuti data absen masuk.
- **Foto bukti** dan **catatan aktivitas** muncul dan diwajibkan sesuai aturan
  dari server (`photo_required`, `remote_photo_required`, `remote_notes_required`).
- **Deteksi fake GPS**, akurasi GPS, alamat hasil reverse geocoding, dan info
  perangkat ikut terkirim bersama presensi.
- **Jam memakai `server_time`**, bukan jam perangkat, sehingga tidak bisa
  dikelabui dengan mengubah waktu ponsel.
- Alasan tombol nonaktif (`blockers[]`) ditampilkan apa adanya — mis. sedang
  cuti yang disetujui, akhir pekan, atau belum ada lokasi kantor aktif.

### 🙂 Verifikasi Wajah

- Deteksi wajah **ML Kit** + pengenalan **MobileFaceNet (TensorFlow Lite)**
  yang berjalan sepenuhnya di perangkat.
- **Uji kedipan mata** sebagai pemeriksaan keaslian sederhana, supaya foto
  statis tidak bisa dipakai untuk presensi.
- Pendaftaran wajah sekali di halaman profil, lalu dipakai untuk pencocokan.
- Di platform tanpa ML Kit/TFLite (web & desktop), alur otomatis turun ke
  **foto selfie biasa** yang tetap terkirim sebagai bukti dan diverifikasi
  server — lihat [Dukungan Platform](#-dukungan-platform).

### 📋 Izin & Cuti

- Pengajuan dengan lampiran **JPG, PNG, WEBP, atau PDF (maks 5 MB)**,
  divalidasi lebih dulu di aplikasi agar tidak menunggu respons 422.
- Ubah pengajuan yang masih `pending`, ganti atau hapus lampiran.
- **Batalkan pengajuan** langsung dari daftar.
- Sisa kuota per jenis izin; `total_days` dihitung server (mengecualikan akhir
  pekan dan hari libur).

### 📊 Riwayat & Rekap

- **Rekap bulanan**: total hadir, tepat waktu, terlambat, total jam kerja, dan
  rincian per mode kerja.
- Filter riwayat **di sisi server** berdasarkan tanggal, status, dan mode kerja.
- Detail presensi menampilkan bukti lengkap: foto masuk/pulang, catatan,
  alamat, jarak dari kantor, durasi kerja, dan penanda fake GPS.

### ⏱️ Lembur & Notifikasi

- Mulai dan selesaikan lembur dengan dokumen pendukung.
- **Notifikasi pengingat absen** terjadwal otomatis sesuai shift: 15 menit
  sebelum jam masuk dan tepat pada jam pulang.

### 🎨 Tampilan

- Material 3 dengan warna utama yang mengikuti `theme.primary_color` dari API.
- Layar **pemeliharaan** dan **wajib perbarui aplikasi** yang muncul sebelum
  layar apa pun yang membutuhkan API.
- Pesan error ditampilkan apa adanya dari server — sudah berbahasa Indonesia
  dan aman untuk pengguna.

---

## 💻 Dukungan Platform

| Platform | Presensi & peta | Verifikasi wajah di perangkat | Catatan |
| --- | :---: | :---: | --- |
| **Android** | ✅ | ✅ | Target utama |
| **iOS** | ✅ | ✅ | Frame kamera BGRA8888 ditangani terpisah dari Android |
| **Web** | ✅ | ➖ | Turun ke foto selfie; butuh HTTPS & CORS |

**Kenapa wajah tidak jalan di web:** ML Kit hanya punya implementasi
Android/iOS, dan TensorFlow Lite memakai `dart:ffi` yang tidak ada di web.
Keduanya diisolasi di balik `FaceEngine` dengan *conditional import*, sehingga
aplikasi tetap bisa dikompilasi untuk web dan alur presensi tetap berfungsi
memakai foto selfie sebagai bukti.

---

## 🚀 Menjalankan Proyek

### Prasyarat

- **Flutter** >= 3.27 (dikembangkan dengan 3.35.6)
- **Dart** >= 3.5 (dikembangkan dengan 3.9.2)
- **JDK 17** untuk build Android
- Perangkat/emulator dengan kamera dan GPS

### Langkah

```bash
flutter pub get

# Kode freezed & flutter_gen dihasilkan otomatis
dart run build_runner build

flutter run
```

### Mengganti alamat server

Alamat backend ada di satu tempat — `lib/core/constants/variables.dart`:

```dart
class Variables {
  static const String appName = 'Absen Devtech KI';
  static const String baseUrl = 'https://presensi-dev.pringsewukab.go.id';
}
```

Nama aplikasi, logo, warna, tile peta, aturan foto/catatan, versi minimum, dan
mode pemeliharaan **tidak perlu diubah di kode** — semuanya dibaca dari
`GET /api/app-settings`.

> Build rilis Android memaksa HTTPS. Untuk backend lokal berbasis `http://`,
> jalankan build **debug** — cleartext hanya diizinkan di sana.

### Izin platform

Sudah dikonfigurasi di repo dan tidak perlu diubah:

- **Android** — `android/app/src/main/AndroidManifest.xml`: kamera, lokasi,
  notifikasi, dan alarm terjadwal.
- **iOS** — `ios/Runner/Info.plist`: `NSCameraUsageDescription`,
  `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription`,
  dan lainnya.

---

## 🏗️ Arsitektur

Clean Architecture dengan **BLoC** untuk state management.

```
lib/
├── core/
│   ├── config/          # AppConfig — pengaturan aplikasi dari API + cache lokal
│   ├── network/         # ApiClient & ApiException (envelope, multipart, error)
│   ├── theme/           # Tema Material 3 yang mengikuti warna dari API
│   ├── ml/              # FaceEngine + implementasi native / unsupported
│   ├── helper/          # Lokasi, info perangkat, notifikasi
│   ├── components/      # Widget yang dipakai bersama
│   ├── constants/       # Variables (baseUrl), warna
│   └── extensions/      # Ekstensi Dart & BuildContext
├── data/
│   ├── datasources/     # Satu datasource per domain, semua lewat ApiClient
│   └── models/          # Model request & response
└── presentation/
    ├── app/             # Layar pemeliharaan / wajib update, logo aplikasi
    ├── auth/            # Splash & login
    ├── home/            # Beranda, presensi, peta, kamera wajah, QR
    ├── history/         # Riwayat, rekap bulanan, detail presensi
    ├── leaves/          # Izin & cuti
    ├── overtimes/       # Lembur
    └── profile/         # Profil, ubah profil, ubah password
```

### Lapisan jaringan

Seluruh request melewati `ApiClient` ([`lib/core/network/api_client.dart`](lib/core/network/api_client.dart)):

- Membaca envelope baru `{success, message, data, meta}` **dan** key lama
  (`attendance`, `user`, `company`, `checkedin`) sehingga kompatibel dengan
  server yang belum diperbarui.
- Endpoint baru punya **fallback otomatis ke alias lama** saat server menjawab
  404 — mis. `/attendance/check-in` → `/checkin`.
- Unggahan memakai **bytes**, bukan path berkas, agar jalur yang sama bekerja
  di Android, iOS, dan web.
- Memetakan kode status ke `ApiException` dengan pesan siap tampil:
  401 sesi berakhir · 403 tidak berhak · 409 konflik keadaan · 422 validasi ·
  429 terlalu banyak permintaan · 503 pemeliharaan.

---

## 🔄 Alur Aplikasi

### Masuk

1. **Splash** — muat `GET /api/app-settings`, terapkan nama/logo/warna.
2. Cek **mode pemeliharaan** dan **versi minimum** → tampilkan layar penghalang
   bila perlu.
3. Cek sesi tersimpan → **Beranda** atau **Login**.

### Presensi

1. Pilih pintu masuk di beranda: **Absen Masuk** (kantor) atau kartu
   **Absen Masuk WFH/WFA** (jarak jauh).
2. Ambil lokasi perangkat, panggil `GET /api/attendance/pre-check`.
3. Peta menampilkan posisi dan lokasi kantor. Untuk presensi kantor, jarak dan
   radius ditonjolkan; untuk WFH/WFA ditampilkan catatan bahwa radius tidak
   divalidasi.
4. Pilih jenis mode kerja bila pintu tersebut menawarkan lebih dari satu
   (mis. WFH dan WFA).
5. Ambil foto — dengan verifikasi wajah bila tersedia — dan isi catatan bila
   diwajibkan.
6. Kirim `check-in` / `check-out`; hasil dan pesan dari server ditampilkan.

### Izin & Cuti

1. Pilih jenis izin dan rentang tanggal, tulis alasan.
2. Lampirkan berkas (opsional) — divalidasi format dan ukurannya lebih dulu.
3. Kirim; pantau status, ubah, atau batalkan selagi masih `pending`.

---

## 🧪 Pengujian

```bash
flutter analyze   # harus bersih, tanpa error maupun warning
flutter test      # unit test untuk model, parsing API, dan aturan validasi
```

Cakupan test saat ini berfokus pada logika yang paling mudah salah dan paling
mahal bila salah: perbandingan versi untuk wajib-update, parsing pre-check dan
riwayat, aturan wajib foto/catatan per mode kerja, penanganan tanggal lintas
timezone, kompatibilitas respons lama dan baru, serta aturan password.

---

## 📦 Rilis

Ringkasnya:

```bash
flutter build appbundle --release   # Play Store
flutter build ipa --release         # App Store
flutter build web --release         # Web
```

Build rilis Android memerlukan `android/key.properties` (salin dari
`android/key.properties.example`). Tanpa berkas itu build tetap berhasil tetapi
ditandatangani kunci debug dan **akan ditolak Play Console**.

Langkah lengkap — pembuatan keystore, daftar periksa sebelum unggah, dan
persyaratan Play Console — ada di [`docs/RELEASE.md`](docs/RELEASE.md).

---

## 🛠️ Teknologi

| Area | Paket |
| --- | --- |
| State management | `flutter_bloc`, `bloc`, `freezed` |
| Jaringan | `http`, `http_parser` |
| Peta & lokasi | `flutter_map`, `latlong2`, `geolocator` |
| Kamera & wajah | `camera`, `google_mlkit_face_detection`, `tflite_flutter`, `image` |
| Berkas | `image_picker`, `file_picker`, `flutter_image_compress` |
| Notifikasi | `flutter_local_notifications`, `timezone` |
| Perangkat | `device_info_plus`, `package_info_plus` |
| Penyimpanan | `shared_preferences`, `path_provider` |
| Lainnya | `mobile_scanner`, `google_fonts`, `flutter_svg`, `intl`, `url_launcher`, `dartz` |

Peta memakai `flutter_map` + OpenStreetMap, bukan Google Maps — berjalan di
Android, iOS, dan web tanpa API key, dan penyedia tile-nya bisa diganti admin
lewat `map.tile_url`.

---

## 👥 Tim

- **Developer**: [Adnan](https://github.com/ZuzlifatulAdnan)

---

**Dibangun dengan ❤️ menggunakan Flutter**
