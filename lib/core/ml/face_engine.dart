import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

/// Satu wajah yang terdeteksi pada sebuah frame kamera.
class DetectedFace {
  /// Kotak wajah dalam koordinat gambar sumber (bukan koordinat layar).
  final Rect boundingBox;

  /// Peluang mata terbuka, 0..1. Null bila klasifikasi tidak diaktifkan.
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;

  /// Sudut kepala menoleh (yaw) dan miring (roll), dalam derajat.
  final double? headEulerAngleY;
  final double? headEulerAngleZ;

  const DetectedFace({
    required this.boundingBox,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.headEulerAngleY,
    this.headEulerAngleZ,
  });

  /// Kedua mata tertutup — dipakai sebagai uji kedipan (liveness sederhana).
  bool get isBlinking {
    final left = leftEyeOpenProbability;
    final right = rightEyeOpenProbability;
    if (left == null || right == null) return false;
    return left < 0.3 && right < 0.3;
  }

  /// Wajah menghadap kamera dengan cukup lurus.
  bool get isFrontal {
    final yaw = headEulerAngleY?.abs() ?? 0;
    final roll = headEulerAngleZ?.abs() ?? 0;
    return yaw < 20 && roll < 20;
  }
}

/// Hasil satu putaran deteksi pada frame kamera.
class FaceScanResult {
  final List<DetectedFace> faces;

  /// Ukuran gambar sumber, dipakai painter untuk memetakan kotak ke layar.
  final Size imageSize;

  /// Rotasi yang diterapkan detektor terhadap frame, dalam derajat.
  final int rotationDegrees;

  const FaceScanResult({
    required this.faces,
    required this.imageSize,
    this.rotationDegrees = 0,
  });

  static const FaceScanResult empty =
      FaceScanResult(faces: [], imageSize: Size.zero);

  bool get hasFace => faces.isNotEmpty;

  bool get hasSingleFace => faces.length == 1;
}

/// Foto bukti presensi beserta embedding wajah bila pengenalan tersedia.
class FaceCapture {
  /// JPEG siap diunggah sebagai `photo`.
  final Uint8List jpegBytes;

  /// Vektor 192 dimensi hasil MobileFaceNet. Null di platform yang tidak
  /// mendukung pengenalan on-device (web, desktop).
  final List<double>? embedding;

  const FaceCapture({required this.jpegBytes, this.embedding});

  bool get hasEmbedding => embedding != null && embedding!.isNotEmpty;
}

/// Hasil pencocokan wajah dengan data terdaftar.
class FaceMatch {
  final bool matched;
  final double distance;
  final String message;

  const FaceMatch({
    required this.matched,
    required this.distance,
    required this.message,
  });

  /// Batas jarak euclidean yang masih dianggap wajah yang sama.
  static const double threshold = 1.0;
}

/// Mesin deteksi & pengenalan wajah.
///
/// Deteksi memakai ML Kit dan pengenalan memakai MobileFaceNet lewat TFLite —
/// keduanya hanya tersedia di Android dan iOS. Di platform lain (web, desktop)
/// [isSupported] bernilai false dan aplikasi memakai alur foto selfie biasa
/// yang diverifikasi di sisi server.
abstract class FaceEngine {
  bool get isSupported;

  /// Alasan yang bisa ditampilkan ke pengguna saat [isSupported] false.
  String get unsupportedReason;

  Future<void> initialize();

  /// Deteksi wajah pada satu frame stream kamera.
  Future<FaceScanResult> scan(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  );

  /// Potong wajah dari [image], hasilkan JPEG bukti presensi, dan — bila
  /// tersedia — embedding untuk dicocokkan.
  Future<FaceCapture?> capture(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation, {
    Rect? faceBox,
  });

  /// Cocokkan [embedding] dengan wajah yang terdaftar pada akun.
  Future<FaceMatch> match(List<double> embedding);

  /// Serialisasi embedding untuk dikirim ke `face_embedding`.
  String encodeEmbedding(List<double> embedding);

  void dispose();
}
