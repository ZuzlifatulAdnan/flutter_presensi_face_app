import 'package:flutter_absensi_app/core/ml/face_engine.dart';

// TFLite memakai `dart:ffi` dan ML Kit memakai `dart:io`, keduanya tidak ada
// di web — jadi implementasi native hanya di-import saat `dart:io` tersedia.
import 'package:flutter_absensi_app/core/ml/face_engine_unsupported.dart'
    if (dart.library.io) 'package:flutter_absensi_app/core/ml/face_engine_native.dart'
    as impl;

/// Titik akses tunggal ke [FaceEngine] yang sesuai platform.
///
/// Panggil [FaceEngineProvider.instance] di mana pun alur wajah dibutuhkan;
/// periksa `isSupported` sebelum menawarkan presensi wajah, dan jatuh ke alur
/// foto selfie bila bernilai false.
class FaceEngineProvider {
  FaceEngineProvider._();

  static FaceEngine? _instance;

  static FaceEngine get instance => _instance ??= impl.createFaceEngine();

  static bool get isSupported => instance.isSupported;

  static Future<void> warmUp() => instance.initialize();

  static void release() {
    _instance?.dispose();
    _instance = null;
  }
}
