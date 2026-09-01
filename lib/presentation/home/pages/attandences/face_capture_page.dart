import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_absensi_app/core/ml/face_engine.dart';
import 'package:flutter_absensi_app/core/ml/face_engine_provider.dart';
import 'package:flutter_absensi_app/core/theme/app_theme.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';

/// Hasil pengambilan foto wajah yang dikembalikan ke halaman presensi.
class FaceCaptureResult {
  /// JPEG bukti presensi, siap dikirim sebagai field `photo`.
  final Uint8List bytes;

  /// Nama berkas untuk multipart.
  final String filename;

  /// Wajah sudah dicocokkan dengan data terdaftar di perangkat.
  final bool verified;

  /// Embedding wajah — hanya terisi saat mendaftarkan wajah.
  final List<double>? embedding;

  const FaceCaptureResult({
    required this.bytes,
    this.filename = 'selfie.jpg',
    this.verified = false,
    this.embedding,
  });
}

/// Tujuan halaman: verifikasi wajah untuk presensi, atau pendaftaran wajah.
enum FaceCaptureMode { verify, register, photoOnly }

/// Pengambilan foto wajah lintas platform.
///
/// Di Android dan iOS wajah dideteksi dan dicocokkan langsung di perangkat
/// (ML Kit + MobileFaceNet). Di web dan desktop — tempat kedua pustaka itu
/// tidak tersedia — halaman ini berubah menjadi pengambilan selfie biasa yang
/// tetap terkirim sebagai bukti presensi ke server.
class FaceCapturePage extends StatefulWidget {
  final FaceCaptureMode mode;
  final String title;

  const FaceCapturePage({
    super.key,
    this.mode = FaceCaptureMode.verify,
    this.title = 'Verifikasi Wajah',
  });

  @override
  State<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends State<FaceCapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  bool _initializing = true;
  bool _processing = false;
  bool _streaming = false;
  String? _fatalError;

  /// Deteksi wajah on-device aktif untuk sesi ini.
  bool _liveDetection = false;

  FaceScanResult _scan = FaceScanResult.empty;
  String _hint = 'Menyiapkan kamera...';

  /// Kedipan terdeteksi — dipakai sebagai uji keaslian sederhana supaya foto
  /// statis tidak bisa dipakai untuk presensi.
  bool _blinkSeen = false;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _stopStream();
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  Future<void> _bootstrap() async {
    try {
      // Pendaftaran & verifikasi wajah hanya mungkin bila mesin wajah tersedia
      // dan pengguna memang sudah punya data wajah tersimpan.
      final engineReady = FaceEngineProvider.isSupported;
      if (engineReady) await FaceEngineProvider.warmUp();

      var useLive = engineReady && widget.mode != FaceCaptureMode.photoOnly;
      if (useLive && widget.mode == FaceCaptureMode.verify) {
        final authData = await AuthLocalDatasource().getAuthData();
        final embedding = authData?.user?.faceEmbedding?.toString() ?? '';
        useLive = embedding.trim().isNotEmpty;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _initializing = false;
          _fatalError = 'Tidak ada kamera yang tersedia di perangkat ini.';
        });
        return;
      }

      // Utamakan kamera depan untuk selfie presensi.
      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;

      _liveDetection = useLive;
      await _startCamera();
    } catch (e) {
      debugPrint('[FaceCapture] gagal menyiapkan kamera: $e');
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _fatalError = 'Kamera tidak dapat diakses. Pastikan izin kamera '
            'sudah diberikan lalu coba lagi.';
      });
    }
  }

  Future<void> _startCamera() async {
    final camera = _cameras[_cameraIndex];
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      // ML Kit menerima NV21 di Android dan BGRA8888 di iOS.
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    _controller = controller;
    await controller.initialize();
    if (!mounted) return;

    setState(() {
      _initializing = false;
      _hint = _liveDetection
          ? 'Posisikan wajah di dalam lingkaran'
          : 'Posisikan wajah Anda, lalu tekan tombol ambil foto';
    });

    if (_liveDetection) await _startStream();
  }

  Future<void> _startStream() async {
    final controller = _controller;
    if (controller == null || _streaming) return;
    try {
      await controller.startImageStream(_onFrame);
      _streaming = true;
    } catch (e) {
      // Stream frame tidak tersedia di semua platform (mis. web); turunkan
      // ke mode foto biasa alih-alih menggagalkan presensi.
      debugPrint('[FaceCapture] stream tidak tersedia: $e');
      if (!mounted) return;
      setState(() {
        _liveDetection = false;
        _hint = 'Posisikan wajah Anda, lalu tekan tombol ambil foto';
      });
    }
  }

  Future<void> _stopStream() async {
    final controller = _controller;
    if (controller == null || !_streaming) return;
    _streaming = false;
    try {
      await controller.stopImageStream();
    } catch (_) {
      // Kamera bisa saja sudah dilepas duluan saat halaman ditutup.
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_processing || !mounted) return;

    // Batasi ke ~5 fps: deteksi tidak perlu setiap frame dan menahan CPU
    // membuat pratinjau tersendat.
    final now = DateTime.now();
    if (now.difference(_lastFrame) < const Duration(milliseconds: 200)) return;
    _lastFrame = now;

    _processing = true;
    try {
      final camera = _cameras[_cameraIndex];
      final orientation = _controller?.value.deviceOrientation ??
          DeviceOrientation.portraitUp;
      final scan = await FaceEngineProvider.instance
          .scan(image, camera, orientation);
      if (!mounted) return;

      final face = scan.faces.length == 1 ? scan.faces.first : null;
      if (face != null && face.isBlinking) _blinkSeen = true;

      setState(() {
        _scan = scan;
        _hint = _hintFor(scan);
      });

      if (face != null && face.isFrontal && _blinkSeen) {
        await _captureFromStream(image, camera, orientation, face);
      }
    } finally {
      _processing = false;
    }
  }

  String _hintFor(FaceScanResult scan) {
    if (scan.faces.isEmpty) return 'Wajah belum terdeteksi';
    if (scan.faces.length > 1) {
      return 'Terdeteksi lebih dari satu wajah. Pastikan hanya Anda di frame.';
    }
    if (!scan.faces.first.isFrontal) {
      return 'Hadapkan wajah lurus ke kamera';
    }
    if (!_blinkSeen) return 'Kedipkan mata untuk memastikan Anda hadir';
    return 'Menahan posisi...';
  }

  Future<void> _captureFromStream(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation orientation,
    DetectedFace face,
  ) async {
    await _stopStream();
    if (!mounted) return;
    setState(() => _hint = 'Memproses wajah...');

    final capture = await FaceEngineProvider.instance.capture(
      image,
      camera,
      orientation,
      faceBox: face.boundingBox,
    );

    if (!mounted) return;
    if (capture == null) {
      _resetScan('Gagal memproses wajah. Silakan coba lagi.');
      return;
    }

    if (widget.mode == FaceCaptureMode.register) {
      if (!capture.hasEmbedding) {
        _resetScan('Gagal membaca data wajah. Coba di tempat yang lebih terang.');
        return;
      }
      _finish(FaceCaptureResult(
        bytes: capture.jpegBytes,
        verified: true,
        embedding: capture.embedding,
      ));
      return;
    }

    if (!capture.hasEmbedding) {
      _resetScan('Gagal membaca data wajah. Coba lagi.');
      return;
    }

    final match = await FaceEngineProvider.instance.match(capture.embedding!);
    if (!mounted) return;

    if (!match.matched) {
      _resetScan(match.message);
      return;
    }

    _finish(FaceCaptureResult(bytes: capture.jpegBytes, verified: true));
  }

  /// Kembali memindai setelah kegagalan, tanpa menutup halaman.
  void _resetScan(String message) {
    _blinkSeen = false;
    setState(() {
      _scan = FaceScanResult.empty;
      _hint = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
    );
    _startStream();
  }

  /// Jalur foto biasa — dipakai di web/desktop dan sebagai cadangan bila
  /// stream frame tidak tersedia.
  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_processing) return;

    setState(() => _processing = true);
    try {
      await _stopStream();
      final shot = await controller.takePicture();
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      _finish(FaceCaptureResult(
        bytes: bytes,
        filename: shot.name.isEmpty ? 'selfie.jpg' : shot.name,
      ));
    } catch (e) {
      debugPrint('[FaceCapture] gagal mengambil foto: $e');
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengambil foto. Silakan coba lagi.'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  void _finish(FaceCaptureResult result) {
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    await _stopStream();
    await _controller?.dispose();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    _blinkSeen = false;
    setState(() {
      _scan = FaceScanResult.empty;
      _initializing = true;
    });
    await _startCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch_rounded),
              tooltip: 'Ganti kamera',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_fatalError != null) return _ErrorView(message: _fatalError!);

    final controller = _controller;
    if (_initializing || controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _CameraPreviewFill(controller: controller),
        const _FaceFrameOverlay(),
        if (_liveDetection && _scan.hasFace)
          CustomPaint(
            painter: _FaceBoxPainter(
              scan: _scan,
              mirror: _cameras[_cameraIndex].lensDirection ==
                  CameraLensDirection.front,
              color: _scan.hasSingleFace && _scan.faces.first.isFrontal
                  ? AppTheme.success
                  : AppTheme.warning,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _CaptureBar(
            hint: _hint,
            liveDetection: _liveDetection,
            busy: _processing,
            onCapture: _takePicture,
          ),
        ),
      ],
    );
  }
}

/// Pratinjau kamera yang mengisi layar tanpa mendistorsi rasio aspek.
class _CameraPreviewFill extends StatelessWidget {
  final CameraController controller;

  const _CameraPreviewFill({required this.controller});

  @override
  Widget build(BuildContext context) {
    // Rasio kamera dilaporkan dalam orientasi lanskap sensor, sedangkan layar
    // presensi selalu potret — skala ini menutupi layar tanpa memipihkan
    // gambar, dan kotak wajah tetap sejajar dengan pratinjau.
    final screenAspect = MediaQuery.of(context).size.aspectRatio;
    final scale = 1 / (controller.value.aspectRatio * screenAspect);

    return ClipRect(
      child: Transform.scale(
        scale: scale < 1 ? 1 / scale : scale,
        alignment: Alignment.center,
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }
}

/// Lingkaran panduan posisi wajah.
class _FaceFrameOverlay extends StatelessWidget {
  const _FaceFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.72,
          child: AspectRatio(
            aspectRatio: 0.78,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 2.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureBar extends StatelessWidget {
  final String hint;
  final bool liveDetection;
  final bool busy;
  final VoidCallback onCapture;

  const _CaptureBar({
    required this.hint,
    required this.liveDetection,
    required this.busy,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (liveDetection)
            const SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          else
            _ShutterButton(busy: busy, onTap: onCapture),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;

  const _ShutterButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: busy ? 0.4 : 1),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 4,
          ),
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(Icons.camera_alt_rounded,
                color: Colors.black87, size: 30),
      ),
    );
  }
}

/// Menggambar kotak wajah hasil deteksi di atas pratinjau.
class _FaceBoxPainter extends CustomPainter {
  final FaceScanResult scan;
  final bool mirror;
  final Color color;

  const _FaceBoxPainter({
    required this.scan,
    required this.mirror,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scan.imageSize.isEmpty) return;

    // Pratinjau memakai BoxFit.cover, jadi skala mengikuti sisi terbesar.
    final scale = size.width / scan.imageSize.width >
            size.height / scan.imageSize.height
        ? size.width / scan.imageSize.width
        : size.height / scan.imageSize.height;
    final dx = (size.width - scan.imageSize.width * scale) / 2;
    final dy = (size.height - scan.imageSize.height * scale) / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;

    for (final face in scan.faces) {
      final box = face.boundingBox;
      var left = box.left * scale + dx;
      var right = box.right * scale + dx;
      if (mirror) {
        final mirroredLeft = size.width - right;
        right = size.width - left;
        left = mirroredLeft;
      }
      final rect = Rect.fromLTRB(
        left,
        box.top * scale + dy,
        right,
        box.bottom * scale + dy,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FaceBoxPainter oldDelegate) =>
      oldDelegate.scan != scan || oldDelegate.color != color;
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded,
                color: Colors.white70, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}
