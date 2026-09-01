import 'dart:convert';

import 'package:flutter_absensi_app/core/network/api_client.dart';

/// Payload presensi masuk / pulang.
///
/// Dikirim sebagai `multipart/form-data` bila ada [photo]; selain itu tetap
/// dikirim sebagai form biasa agar kompatibel dengan endpoint lama.
class CheckInOutRequestModel {
  final String? latitude;
  final String? longitude;

  /// `wfo` | `wfh` | `wfa`. Tidak dikirim saat absen pulang — server memakai
  /// mode dari data absen masuk.
  final String? workMode;

  /// Foto bukti presensi (JPG/PNG/WEBP, maks 4 MB).
  final UploadFile? photo;

  /// Catatan aktivitas, wajib untuk WFH/WFA bila diminta server.
  final String? notes;

  /// Hasil reverse geocoding di aplikasi, maks 500 karakter.
  final String? address;

  /// Hasil deteksi fake GPS di aplikasi.
  final bool? isMockLocation;

  /// Contoh: `Pixel 8 / Android 15`.
  final String? deviceInfo;

  /// Akurasi GPS dalam meter.
  final double? accuracy;

  const CheckInOutRequestModel({
    this.latitude,
    this.longitude,
    this.workMode,
    this.photo,
    this.notes,
    this.address,
    this.isMockLocation,
    this.deviceInfo,
    this.accuracy,
  });

  factory CheckInOutRequestModel.fromJson(String str) =>
      CheckInOutRequestModel.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory CheckInOutRequestModel.fromMap(Map<String, dynamic> json) =>
      CheckInOutRequestModel(
        latitude: json['latitude']?.toString(),
        longitude: json['longitude']?.toString(),
        workMode: json['work_mode']?.toString(),
        notes: json['notes']?.toString(),
        address: json['address']?.toString(),
        isMockLocation: json['is_mock_location'] as bool?,
        deviceInfo: json['device_info']?.toString(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
      );

  CheckInOutRequestModel copyWith({
    String? latitude,
    String? longitude,
    String? workMode,
    UploadFile? photo,
    String? notes,
    String? address,
    bool? isMockLocation,
    String? deviceInfo,
    double? accuracy,
  }) =>
      CheckInOutRequestModel(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        workMode: workMode ?? this.workMode,
        photo: photo ?? this.photo,
        notes: notes ?? this.notes,
        address: address ?? this.address,
        isMockLocation: isMockLocation ?? this.isMockLocation,
        deviceInfo: deviceInfo ?? this.deviceInfo,
        accuracy: accuracy ?? this.accuracy,
      );

  /// Field form yang dikirim ke server. Nilai kosong dibuang supaya tidak
  /// menimpa data lama dengan string kosong.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'latitude': latitude ?? '0',
      'longitude': longitude ?? '0',
    };
    if (workMode != null && workMode!.isNotEmpty) map['work_mode'] = workMode;
    if (notes != null && notes!.trim().isNotEmpty) map['notes'] = notes!.trim();
    if (address != null && address!.trim().isNotEmpty) {
      map['address'] = address!.trim();
    }
    if (isMockLocation != null) map['is_mock_location'] = isMockLocation;
    if (deviceInfo != null && deviceInfo!.isNotEmpty) {
      map['device_info'] = deviceInfo;
    }
    if (accuracy != null) map['accuracy'] = accuracy;
    return map;
  }

  bool get hasPhoto => photo != null;
}
