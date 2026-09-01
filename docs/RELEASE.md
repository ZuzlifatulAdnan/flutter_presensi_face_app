# Panduan Rilis — Play Store, App Store, dan Web

Dokumen ini merangkum apa yang sudah disiapkan di repositori dan langkah yang
masih harus Anda kerjakan sendiri (karena butuh akun atau berkas rahasia).

---

## 1. Android — Google Play Store

### 1.1 Yang sudah disiapkan

| Item | Status |
| --- | --- |
| `applicationId` | `com.jagoflutter.hris` |
| `compileSdk` / `targetSdk` | 36 (memenuhi syarat Play per Agustus 2025) |
| `minSdk` | 24 |
| Android Gradle Plugin | 8.9.1 (disyaratkan `androidx.camera` 1.6.x) |
| Java / Kotlin target | 17 |
| R8 (`minifyEnabled` + `shrinkResources`) | Aktif di build rilis |
| Aturan ProGuard untuk ML Kit, TFLite, Flutter, notifikasi | Ada di `android/app/proguard-rules.pro` |
| Split ABI/density/bahasa pada App Bundle | Aktif |
| Konfigurasi penandatanganan rilis | Membaca `android/key.properties` |
| `versionName+versionCode` | `1.4.0+5` di `pubspec.yaml` |
| Izin | Sudah dirapikan; `WRITE_EXTERNAL_STORAGE` dihapus, `READ_EXTERNAL_STORAGE` dibatasi ke API ≤ 32 |
| Cleartext HTTP | Dimatikan di rilis, diizinkan hanya di build debug |

### 1.2 Membuat keystore (sekali saja)

> **Simpan berkas ini baik-baik.** Kehilangannya membuat Anda tidak bisa lagi
> memperbarui aplikasi dengan `applicationId` yang sama di Play Store.

```bash
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Lalu salin `android/key.properties.example` menjadi `android/key.properties`
dan isi nilainya:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=C:/path/ke/upload-keystore.jks
```

`android/key.properties` dan semua berkas `*.jks` / `*.keystore` sudah masuk
`.gitignore`, jadi tidak akan ikut ter-commit.

### 1.3 Membangun berkas rilis

```bash
flutter clean
flutter pub get
dart run build_runner build

# App Bundle — format yang diunggah ke Play Console
flutter build appbundle --release
# hasil: build/app/outputs/bundle/release/app-release.aab

# APK (opsional, untuk uji manual di perangkat)
flutter build apk --release --split-per-abi
```

Tanpa `android/key.properties`, build rilis tetap berhasil tetapi ditandatangani
kunci debug dan **akan ditolak Play Console**.

### 1.4 Menaikkan versi

Ubah `version:` di `pubspec.yaml`, mis. `1.4.1+6`. Angka setelah `+`
(versionCode) **harus selalu naik** pada setiap unggahan.

Nilai ini juga dibandingkan dengan `version.android_minimum` dan
`version.force_update` dari `GET /api/app-settings`; bila versi terpasang di
bawah minimum dan `force_update` menyala, aplikasi menampilkan layar
"Perbarui Aplikasi" dan memblokir akses.

### 1.5 Yang perlu Anda siapkan di Play Console

- Kebijakan privasi (URL publik) — **wajib**, karena aplikasi memakai kamera,
  lokasi, dan mengunggah foto.
- Deklarasi **Data safety**: lokasi presisi, foto, alamat email, nama, dan ID
  perangkat dikumpulkan dan dikirim ke server perusahaan.
- Deklarasi izin **Alarm & reminder** (`USE_EXACT_ALARM`) — dipakai untuk
  notifikasi pengingat absen sesuai shift.
- Materi toko: ikon 512×512, feature graphic 1024×500, minimal 2 tangkapan
  layar ponsel.
- Kategori disarankan: *Business* atau *Productivity*.

---

## 2. iOS — App Store

Berkas `ios/Runner/Info.plist` sudah dilengkapi string izin yang wajib; tanpa
ini iOS menutup paksa aplikasi saat kamera/lokasi diakses dan App Store menolak
binari-nya:

- `NSCameraUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- `NSFaceIDUsageDescription`
- `ITSAppUsesNonExemptEncryption = false`

Orientasi dikunci ke potret agar tata letak kamera dan peta konsisten.

Langkah rilis:

```bash
flutter build ipa --release
```

Selanjutnya buka `build/ios/archive/Runner.xcarchive` di Xcode, atur Team &
Bundle Identifier, lalu unggah lewat Organizer atau `xcrun altool`.

---

## 3. Web

```bash
flutter build web --release
# hasil: build/web  (unggah isinya ke hosting statis / Nginx / Firebase Hosting)
```

Catatan penting untuk web:

- **Verifikasi wajah on-device tidak tersedia.** ML Kit hanya punya
  implementasi Android/iOS dan TensorFlow Lite memakai `dart:ffi` yang tidak
  ada di web. Aplikasi mendeteksi ini otomatis dan mengganti alur wajah dengan
  pengambilan **foto selfie biasa** yang tetap dikirim sebagai bukti presensi
  dan diverifikasi di sisi server.
- Kamera dan lokasi di browser **hanya berjalan lewat HTTPS** (atau
  `localhost`).
- Backend harus mengizinkan CORS dari domain tempat aplikasi web di-host.

---

## 4. Mengganti alamat server

Alamat backend ada di satu tempat:

```dart
// lib/core/constants/variables.dart
static const String baseUrl = 'https://presensi-dev.pringsewukab.go.id';
```

Nama aplikasi, logo, warna, tile peta, aturan foto/catatan, versi minimum, dan
mode pemeliharaan **tidak** perlu diubah di kode — semuanya dibaca dari
`GET /api/app-settings` dan dapat diatur admin lewat panel.

---

## 5. Daftar periksa sebelum unggah

- [ ] `flutter analyze` bersih tanpa error dan warning
- [ ] `flutter test` lulus
- [ ] `android/key.properties` terisi dan keystore tersimpan aman
- [ ] `version:` di `pubspec.yaml` sudah dinaikkan
- [ ] `Variables.baseUrl` mengarah ke server produksi
- [ ] Uji manual: login, presensi masuk & pulang (WFO dan WFH), unggah izin
      berlampiran, ubah password, dan notifikasi pengingat shift
- [ ] Uji penolakan: di luar radius, fake GPS aktif, dan presensi ganda
