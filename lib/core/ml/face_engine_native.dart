import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:flutter_absensi_app/core/ml/face_engine.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';

FaceEngine createFaceEngine() => NativeFaceEngine();

/// Deteksi wajah (ML Kit) + pengenalan wajah (MobileFaceNet/TFLite) untuk
/// Android dan iOS.
///
/// Konversi frame kamera ditangani terpisah per platform: Android mengirim
/// NV21 satu plane, iOS mengirim BGRA8888. Versi sebelumnya menganggap semua
/// frame NV21 sehingga alur wajah tidak pernah bekerja di iOS.
class NativeFaceEngine implements FaceEngine {
  static const int _inputSize = 112;
  static const int _embeddingSize = 192;
  static const String _modelAsset = 'assets/mobile_face_net.tflite';

  /// Kompensasi rotasi layar terhadap sensor kamera.
  static const Map<DeviceOrientation, int> _orientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  FaceDetector? _detector;
  Interpreter? _interpreter;
  bool _initializing = false;

  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  String get unsupportedReason =>
      'Pengenalan wajah hanya tersedia di aplikasi Android dan iOS.';

  @override
  Future<void> initialize() async {
    if (!isSupported || _initializing) return;
    _initializing = true;
    try {
      _detector ??= FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          // Klasifikasi dibutuhkan untuk uji kedipan mata.
          enableClassification: true,
          enableTracking: true,
          minFaceSize: 0.15,
        ),
      );
      _interpreter ??= await Interpreter.fromAsset(
        _modelAsset,
        options: InterpreterOptions()..threads = 2,
      );
    } catch (e) {
      debugPrint('[FaceEngine] gagal inisialisasi: $e');
    } finally {
      _initializing = false;
    }
  }

  @override
  Future<FaceScanResult> scan(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    final detector = _detector;
    if (detector == null) return FaceScanResult.empty;

    final rotation = _rotationFor(camera, deviceOrientation);
    final input = _toInputImage(image, rotation);
    if (input == null) return FaceScanResult.empty;

    try {
      final faces = await detector.processImage(input);
      // Setelah rotasi 90/270 derajat, sisi gambar bertukar.
      final swapped = rotation.rawValue == 90 || rotation.rawValue == 270;
      return FaceScanResult(
        faces: faces.map(_toDetectedFace).toList(),
        imageSize: swapped
            ? Size(image.height.toDouble(), image.width.toDouble())
            : Size(image.width.toDouble(), image.height.toDouble()),
        rotationDegrees: rotation.rawValue,
      );
    } catch (e) {
      debugPrint('[FaceEngine] deteksi gagal: $e');
      return FaceScanResult.empty;
    }
  }

  @override
  Future<FaceCapture?> capture(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation, {
    Rect? faceBox,
  }) async {
    final rotation = _rotationFor(camera, deviceOrientation);

    img.Image? frame;
    try {
      frame = _toImage(image);
    } catch (e) {
      debugPrint('[FaceEngine] konversi frame gagal: $e');
      return null;
    }
    if (frame == null) return null;

    if (rotation.rawValue != 0) {
      frame = img.copyRotate(frame, angle: rotation.rawValue);
    }

    // Foto bukti memakai frame penuh supaya konteks tetap terlihat.
    final jpeg = Uint8List.fromList(img.encodeJpg(frame, quality: 85));

    List<double>? embedding;
    if (faceBox != null && _interpreter != null) {
      final cropped = _cropFace(frame, faceBox);
      if (cropped != null) embedding = _embed(cropped);
    }

    return FaceCapture(jpegBytes: jpeg, embedding: embedding);
  }

  @override
  Future<FaceMatch> match(List<double> embedding) async {
    final authData = await AuthLocalDatasource().getAuthData();
    final stored = authData?.user?.faceEmbedding;
    if (stored == null || stored.toString().trim().isEmpty) {
      return const FaceMatch(
        matched: false,
        distance: double.infinity,
        message: 'Wajah Anda belum terdaftar. Daftarkan wajah terlebih dahulu.',
      );
    }

    final reference = stored
        .toString()
        .split(',')
        .map((e) => double.tryParse(e.trim()))
        .whereType<double>()
        .toList();

    if (reference.length != embedding.length) {
      return const FaceMatch(
        matched: false,
        distance: double.infinity,
        message: 'Data wajah tidak valid. Silakan daftarkan ulang wajah Anda.',
      );
    }

    var sum = 0.0;
    for (var i = 0; i < embedding.length; i++) {
      final diff = embedding[i] - reference[i];
      sum += diff * diff;
    }
    final distance = math.sqrt(sum);
    final matched = distance < FaceMatch.threshold;

    return FaceMatch(
      matched: matched,
      distance: distance,
      message: matched
          ? 'Wajah Anda cocok dengan data yang terdaftar.'
          : 'Wajah tidak cocok dengan data yang terdaftar. '
              'Pastikan pencahayaan cukup dan wajah menghadap kamera.',
    );
  }

  @override
  String encodeEmbedding(List<double> embedding) => embedding.join(',');

  @override
  void dispose() {
    _detector?.close();
    _detector = null;
    _interpreter?.close();
    _interpreter = null;
  }

  // ---------------------------------------------------------------------------
  // Konversi frame kamera
  // ---------------------------------------------------------------------------

  InputImageRotation _rotationFor(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensor = camera.sensorOrientation;

    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensor) ??
          InputImageRotation.rotation0deg;
    }

    final compensation = _orientationDegrees[deviceOrientation] ?? 0;
    final degrees = camera.lensDirection == CameraLensDirection.front
        ? (sensor + compensation) % 360
        : (sensor - compensation + 360) % 360;
    return InputImageRotationValue.fromRawValue(degrees) ??
        InputImageRotation.rotation0deg;
  }

  InputImage? _toInputImage(CameraImage image, InputImageRotation rotation) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.isEmpty) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  img.Image? _toImage(CameraImage image) {
    if (image.planes.isEmpty) return null;
    if (Platform.isIOS) return _bgraToImage(image);
    return _nv21ToImage(image);
  }

  /// iOS mengirim satu plane BGRA8888 yang bisa dibaca langsung.
  img.Image _bgraToImage(CameraImage image) {
    final plane = image.planes.first;
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: plane.bytes.buffer,
      rowStride: plane.bytesPerRow,
      order: img.ChannelOrder.bgra,
    );
  }

  /// Android (dengan `ImageFormatGroup.nv21`) mengirim Y penuh diikuti VU
  /// berselang-seling pada plane yang sama.
  img.Image _nv21ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final bytes = image.planes.first.bytes;
    final output = img.Image(width: width, height: height);
    final frameSize = width * height;

    for (var y = 0; y < height; y++) {
      var uvIndex = frameSize + (y >> 1) * width;
      var u = 0;
      var v = 0;
      for (var x = 0; x < width; x++) {
        var luma = (bytes[y * width + x] & 0xff) - 16;
        if (luma < 0) luma = 0;
        if ((x & 1) == 0 && uvIndex + 1 < bytes.length) {
          v = (bytes[uvIndex++] & 0xff) - 128;
          u = (bytes[uvIndex++] & 0xff) - 128;
        }
        final y1192 = 1192 * luma;
        final r = (y1192 + 1634 * v).clamp(0, 262143) >> 10;
        final g = (y1192 - 833 * v - 400 * u).clamp(0, 262143) >> 10;
        final b = (y1192 + 2066 * u).clamp(0, 262143) >> 10;
        output.setPixelRgb(x, y, r, g, b);
      }
    }
    return output;
  }

  img.Image? _cropFace(img.Image frame, Rect box) {
    // Beri sedikit margin supaya dagu dan dahi ikut terpotong.
    final margin = box.width * 0.1;
    final left = (box.left - margin).round().clamp(0, frame.width - 1);
    final top = (box.top - margin).round().clamp(0, frame.height - 1);
    var width = (box.width + margin * 2).round();
    var height = (box.height + margin * 2).round();

    if (left + width > frame.width) width = frame.width - left;
    if (top + height > frame.height) height = frame.height - top;
    if (width <= 0 || height <= 0) return null;

    return img.copyCrop(
      frame,
      x: left,
      y: top,
      width: width,
      height: height,
    );
  }

  List<double>? _embed(img.Image face) {
    final interpreter = _interpreter;
    if (interpreter == null) return null;

    try {
      final resized =
          img.copyResize(face, width: _inputSize, height: _inputSize);

      // MobileFaceNet menerima NHWC float ternormalisasi ke rentang [-1, 1].
      final input = List.generate(
        1,
        (_) => List.generate(
          _inputSize,
          (y) => List.generate(
            _inputSize,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                (pixel.r - 127.5) / 127.5,
                (pixel.g - 127.5) / 127.5,
                (pixel.b - 127.5) / 127.5,
              ];
            },
          ),
        ),
      );

      final output =
          List.generate(1, (_) => List<double>.filled(_embeddingSize, 0));
      interpreter.run(input, output);
      return output.first;
    } catch (e) {
      debugPrint('[FaceEngine] inferensi gagal: $e');
      return null;
    }
  }

  DetectedFace _toDetectedFace(Face face) => DetectedFace(
        boundingBox: face.boundingBox,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
        headEulerAngleY: face.headEulerAngleY,
        headEulerAngleZ: face.headEulerAngleZ,
      );
}
