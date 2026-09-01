import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import 'package:flutter_absensi_app/core/ml/face_engine.dart';

FaceEngine createFaceEngine() => UnsupportedFaceEngine();

/// Implementasi untuk platform tanpa ML Kit dan TFLite (web dan desktop).
///
/// ML Kit hanya punya implementasi Android/iOS dan TFLite memakai `dart:ffi`
/// yang tidak ada di web, jadi di sini pengenalan wajah dimatikan dan
/// aplikasi memakai alur foto selfie biasa — foto tetap terkirim sebagai
/// bukti presensi dan diverifikasi di sisi server.
class UnsupportedFaceEngine implements FaceEngine {
  @override
  bool get isSupported => false;

  @override
  String get unsupportedReason =>
      'Pengenalan wajah on-device belum tersedia di platform ini. '
      'Presensi tetap bisa dilakukan dengan foto selfie sebagai bukti.';

  @override
  Future<void> initialize() async {}

  @override
  Future<FaceScanResult> scan(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async =>
      FaceScanResult.empty;

  @override
  Future<FaceCapture?> capture(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation, {
    Rect? faceBox,
  }) async =>
      null;

  @override
  Future<FaceMatch> match(List<double> embedding) async => FaceMatch(
        matched: false,
        distance: double.infinity,
        message: unsupportedReason,
      );

  @override
  String encodeEmbedding(List<double> embedding) => embedding.join(',');

  @override
  void dispose() {}
}
