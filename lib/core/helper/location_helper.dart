import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Posisi pengguna beserta konteks yang dibutuhkan server saat presensi.
class UserLocation {
  final double latitude;
  final double longitude;

  /// Akurasi horizontal dalam meter.
  final double accuracy;

  /// Hasil deteksi fake GPS. Dikirim sebagai `is_mock_location`; server
  /// menolak presensi bila admin mengaktifkan `block_mock_location`.
  final bool isMocked;

  /// Hasil reverse geocoding, diisi belakangan lewat [copyWithAddress].
  final String? address;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy = 0,
    this.isMocked = false,
    this.address,
  });

  UserLocation copyWithAddress(String? address) => UserLocation(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        isMocked: isMocked,
        address: address ?? this.address,
      );

  /// Akurasi masih dalam toleransi yang ditetapkan admin.
  bool isAccurateEnough(double toleranceMeters) =>
      accuracy <= 0 || accuracy <= toleranceMeters;

  String get accuracyLabel =>
      accuracy <= 0 ? 'tidak diketahui' : '±${accuracy.round()} m';
}

/// Kegagalan pengambilan lokasi yang perlu ditindaklanjuti pengguna.
class LocationFailure implements Exception {
  final String message;

  /// Izin ditolak permanen — pengguna harus membukanya dari pengaturan.
  final bool openSettings;

  const LocationFailure(this.message, {this.openSettings = false});

  @override
  String toString() => message;
}

/// Satu pintu untuk semua kebutuhan lokasi.
///
/// Memakai `geolocator` yang berjalan di Android, iOS, dan web sehingga tidak
/// perlu paket lokasi kedua.
class LocationHelper {
  LocationHelper._();

  /// Minta izin dan ambil posisi terkini.
  ///
  /// Melempar [LocationFailure] dengan pesan berbahasa Indonesia yang siap
  /// ditampilkan bila layanan mati atau izin ditolak.
  static Future<UserLocation> current({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationFailure(
        'Layanan lokasi perangkat sedang nonaktif. '
        'Aktifkan GPS lalu coba lagi.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Izin lokasi diblokir permanen. Buka pengaturan aplikasi dan '
        'izinkan akses lokasi untuk melakukan presensi.',
        openSettings: true,
      );
    }

    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        'Izin lokasi ditolak. Presensi membutuhkan akses lokasi.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: timeout,
      ),
    );

    return UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      isMocked: position.isMocked,
    );
  }

  /// Versi yang mengembalikan null alih-alih melempar — untuk layar yang
  /// hanya menampilkan lokasi sebagai informasi tambahan.
  static Future<UserLocation?> tryCurrent({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      return await current(accuracy: accuracy);
    } catch (e) {
      debugPrint('[Location] gagal mengambil posisi: $e');
      return null;
    }
  }

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static Future<bool> openLocationSettings() =>
      Geolocator.openLocationSettings();

  /// Jarak dua titik dalam meter.
  static double distanceBetween(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) =>
      Geolocator.distanceBetween(startLat, startLon, endLat, endLon);

  /// Reverse geocoding lewat Nominatim (OpenStreetMap).
  ///
  /// Dikirim ke server sebagai `address`. Kegagalan tidak menghentikan alur
  /// presensi — server hanya menganggapnya field opsional.
  static Future<String?> addressOf(double latitude, double longitude) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'json',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'addressdetails': '1',
        'accept-language': 'id',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'FlutterAbsensiApp/1.4 (presensi)'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final address = decoded['address'];
      if (address is! Map) return decoded['display_name']?.toString();

      String? pick(List<String> keys) {
        for (final key in keys) {
          final value = address[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString();
          }
        }
        return null;
      }

      final parts = <String>[
        for (final value in [
          pick(['road', 'pedestrian', 'neighbourhood']),
          pick(['suburb', 'village', 'hamlet']),
          pick(['city', 'town', 'city_district', 'county']),
          pick(['state']),
        ])
          if (value != null) value,
      ];

      if (parts.isEmpty) return decoded['display_name']?.toString();
      return parts.join(', ');
    } catch (e) {
      debugPrint('[Location] reverse geocoding gagal: $e');
      return null;
    }
  }
}
