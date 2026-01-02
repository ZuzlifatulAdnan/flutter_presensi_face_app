import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/core.dart';
import '../../../../core/ml/recognition_embedding.dart';
import '../../../../core/ml/recognizer.dart';

class CameraViewAttendancePageBK extends StatefulWidget {
  const CameraViewAttendancePageBK({
    super.key,
    required this.title,
    required this.customPaint,
    required this.onImage,
    this.onCameraFeedReady,
    this.onCameraLensDirectionChanged,
    this.initialCameraLensDirection = CameraLensDirection.back,
    required this.onTakePicture,
    this.requireHeadTurn = true,
  });

  final String title;
  final CustomPaint? customPaint;
  final Function(InputImage inputImage, CameraImage cameraImage) onImage;
  final VoidCallback? onCameraFeedReady;
  //stop live feed

  final Function(CameraLensDirection direction)? onCameraLensDirectionChanged;
  final CameraLensDirection initialCameraLensDirection;
  final Function(CameraImage cameraImage) onTakePicture;
  final bool requireHeadTurn;

  @override
  State<CameraViewAttendancePageBK> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraViewAttendancePageBK>
    with TickerProviderStateMixin {
  static List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = -1;
  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  bool _changingCameraLens = false;

  late List<RecognitionEmbedding> recognitions = [];
  CameraImage? frame;
  CameraLensDirection camDirec = CameraLensDirection.front;
  late Recognizer recognizer;
  late FaceDetector detector;
  bool isFaceRegistered = false;
  String faceStatusMessage = 'Belum Terdaftar';

  // Head turn detection variables
  bool _isHeadTurnedRight = false;
  bool _canTakePicture = false;
  String _instructionMessage = 'Position your face in the center';
  bool _showingInstruction = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Auto-capture variables
  DateTime? _faceDetectedTime;
  int _countdown = 0;
  bool _isAutoCapturing = false;

  @override
  void initState() {
    super.initState();
    recognizer = Recognizer();
    detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast, // Back to fast for better responsiveness
        enableClassification: false,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: true,
      ),
    );
    developer.log('🔍 FaceDetector initialized (fast mode) for overlay');

    // Initialize pulse animation for instruction overlay
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);

    _initialize();
  }

  void _initialize() async {
    try {
      developer.log('🎥 Initializing camera...');

      // Cache cameras list if not already cached
      if (_cameras.isEmpty) {
        developer.log('📷 Fetching available cameras...');
        _cameras = await availableCameras().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            developer.log('⚠️ Get cameras timeout');
            throw Exception('Failed to get available cameras');
          },
        );
        developer.log('✅ Found ${_cameras.length} cameras');
      } else {
        developer.log('✅ Using cached cameras (${_cameras.length} available)');
      }

      // Find camera index
      for (var i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == widget.initialCameraLensDirection) {
          _cameraIndex = i;
          developer.log('📹 Selected camera: ${_cameras[i].name}');
          break;
        }
      }

      if (_cameraIndex != -1) {
        await _startLiveFeed();
      } else {
        developer.log('❌ No suitable camera found');
      }
    } catch (e) {
      developer.log('❌ Camera initialization error: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopLiveFeed();
    detector.close(); // Close detector to free resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            widget.title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: _liveFeedBody(),
    );
  }

  Widget _liveFeedBody() {
    if (_cameras.isEmpty) return _buildLoadingScreen('No cameras available');
    if (_controller == null)
      return _buildLoadingScreen('Initializing camera...');
    if (_controller?.value.isInitialized == false)
      return _buildLoadingScreen('Starting camera...');

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Camera Preview
        Center(
          child: _changingCameraLens
              ? _buildLoadingScreen('Switching camera...')
              : ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: CameraPreview(_controller!, child: widget.customPaint),
                ),
        ),

        // Dark overlay with face detection guide
        _buildFaceDetectionOverlay(),

        // Countdown overlay (centered)
        if (_countdown > 0)
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_countdown',
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4CAF50),
                        height: 1,
                      ),
                    ),
                    const SpaceHeight(4),
                    Text(
                      'Hold Still',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Capturing overlay
        if (_countdown == 0 && _isAutoCapturing)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SpaceWidth(12),
                  Text(
                    'Capturing...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Instructions overlay
        // _buildInstructionsOverlay(),

        // Bottom controls
        _buildBottomControls(),
      ],
    );
  }

  Widget _buildLoadingScreen(String message) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1e3c72),
            Color(0xFF2a5298),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            const SpaceHeight(20),
            Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceDetectionOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
      ),
      child: CustomPaint(
        painter: FaceOverlayPainter(
          screenSize: MediaQuery.of(context).size,
          isHeadTurnedRight: _isHeadTurnedRight,
          canTakePicture: _canTakePicture,
        ),
        child: Container(),
      ),
    );
  }

  Widget _buildInstructionsOverlay() {
    return Positioned(
      top: 40,
      left: 24,
      right: 24,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _showingInstruction ? _pulseAnimation.value : 1.0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1e3c72).withOpacity(0.9),
                    const Color(0xFF2a5298).withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _canTakePicture
                              ? Icons.check_circle
                              : Icons.face_rounded,
                          color: _canTakePicture ? Colors.green : Colors.white,
                          size: 24,
                        ),
                      ),
                      const SpaceWidth(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _canTakePicture ? 'Perfect!' : 'Face Detection',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _instructionMessage,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_canTakePicture) ...[
                    const SpaceHeight(16),
                    Row(
                      children: [
                        _buildStepIndicator(
                          step: 1,
                          title: 'Center Face',
                          isCompleted: true,
                          isActive: !_isHeadTurnedRight,
                        ),
                        const SpaceWidth(8),
                        Expanded(
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: _isHeadTurnedRight
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                        const SpaceWidth(8),
                        _buildStepIndicator(
                          step: 2,
                          title: 'Turn Right',
                          isCompleted: _isHeadTurnedRight && _canTakePicture,
                          isActive: _isHeadTurnedRight,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepIndicator({
    required int step,
    required String title,
    required bool isCompleted,
    required bool isActive,
  }) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green
                : isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    step.toString(),
                    style: GoogleFonts.poppins(
                      color: isActive ? const Color(0xFF1e3c72) : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SpaceHeight(4),
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            // Zoom control
            SizedBox(
              width: 250,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Slider(
                      value: _currentZoomLevel,
                      min: _minAvailableZoom,
                      max: _maxAvailableZoom,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white30,
                      onChanged: (value) async {
                        setState(() {
                          _currentZoomLevel = value;
                        });
                        await _controller?.setZoomLevel(value);
                      },
                    ),
                  ),
                  Container(
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                        child: Text(
                          '${_currentZoomLevel.toStringAsFixed(1)}x',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SpaceHeight(20),

            // Take picture button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTakePictureButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTakePictureButton() {
    return GestureDetector(
      onTap: _canTakePicture
          ? () {
              developer.log(
                  '🎯 Take picture button tapped, _canTakePicture=$_canTakePicture, frame=${frame != null ? "available" : "null"}');
              if (frame != null) {
                developer.log('📸 Calling onTakePicture callback');
                widget.onTakePicture(frame!);
              } else {
                developer.log('❌ Frame is null, cannot take picture');
              }
            }
          : () {
              developer.log('⚠️  Button tapped but _canTakePicture is false');
            },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _canTakePicture
              ? const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                )
              : LinearGradient(
                  colors: [
                    Colors.grey.withOpacity(0.5),
                    Colors.grey.withOpacity(0.3),
                  ],
                ),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: _canTakePicture
                  ? const Color(0xFF4CAF50).withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          _canTakePicture ? Icons.camera_alt_rounded : Icons.face_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Future _startLiveFeed() async {
    try {
      final camera = _cameras[_cameraIndex];

      // Use medium resolution for faster initialization
      _controller = CameraController(
        camera,
        ResolutionPreset.medium, // Changed from high to medium for faster init
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      // Initialize with timeout to prevent hanging
      await _controller?.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          developer.log('⚠️ Camera initialization timeout');
          throw Exception('Camera initialization timeout');
        },
      );

      if (!mounted) {
        return;
      }

      // Get zoom levels in parallel
      final futures = await Future.wait([
        _controller?.getMinZoomLevel() ?? Future.value(1.0),
        _controller?.getMaxZoomLevel() ?? Future.value(1.0),
      ]);

      _minAvailableZoom = futures[0];
      _currentZoomLevel = futures[0];
      _maxAvailableZoom = futures[1];

      // Start image stream
      await _controller?.startImageStream(_processCameraImage);

      if (mounted) {
        if (widget.onCameraFeedReady != null) {
          widget.onCameraFeedReady!();
        }
        if (widget.onCameraLensDirectionChanged != null) {
          widget.onCameraLensDirectionChanged!(camera.lensDirection);
        }
        setState(() {});
      }

      developer.log('✅ Camera started successfully');
    } catch (e) {
      developer.log('❌ Error starting camera: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future _stopLiveFeed() async {
    try {
      developer.log('🛑 Stopping camera...');

      // Stop image stream first
      if (_controller?.value.isStreamingImages ?? false) {
        await _controller?.stopImageStream().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            developer.log('⚠️ Stop image stream timeout');
          },
        );
      }

      // Dispose controller
      await _controller?.dispose().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          developer.log('⚠️ Dispose camera timeout');
        },
      );

      _controller = null;
      developer.log('✅ Camera stopped successfully');
    } catch (e) {
      developer.log('❌ Error stopping camera: $e');
      _controller = null;
    }
  }

  bool _isProcessing = false;
  DateTime? _lastFrameTime;
  int _frameCount = 0;

  void _processCameraImage(CameraImage image) async {
    _frameCount++;

    // Skip if already processing (throttle)
    if (_isProcessing) return;

    // Throttle to ~20 FPS for maximum responsiveness
    final now = DateTime.now();
    if (_lastFrameTime != null &&
        now.difference(_lastFrameTime!).inMilliseconds < 50) {
      return;
    }
    _lastFrameTime = now;

    _isProcessing = true;

    try {
      frame = image;
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      widget.onImage(inputImage, image);

      // Process face detection for overlay
      final faces = await detector.processImage(inputImage);

      if (_frameCount % 30 == 0) {
        developer.log('👤 Detected ${faces.length} face(s)');
      }

      _processFaceDetection(faces);
    } catch (e) {
      developer.log('❌ Error processing camera image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _processFaceDetection(List<Face> faces) {
    // If head turn is not required (e.g., for attendance), allow capture when face is detected
    if (!widget.requireHeadTurn) {
      if (faces.isNotEmpty) {
        final now = DateTime.now();

        // First time detecting face
        if (_faceDetectedTime == null) {
          _faceDetectedTime = now;
          developer.log('✅ Face detected! Starting auto-capture countdown...');
        }

        // Calculate countdown
        final elapsed = now.difference(_faceDetectedTime!).inSeconds;
        final remaining = 2 - elapsed; // 2 second countdown

        if (mounted) {
          setState(() {
            _canTakePicture = true;
            _countdown = remaining > 0 ? remaining : 0;
            _instructionMessage = remaining > 0
                ? 'Hold still... $_countdown'
                : 'Capturing...';
            _showingInstruction = false;
          });
        }

        // Auto-capture after 2 seconds
        if (elapsed >= 2 && !_isAutoCapturing && frame != null) {
          _isAutoCapturing = true;
          developer.log('📸 Auto-capturing now! Triggering face recognition...');

          // Stop further processing to prevent multiple captures
          _stopLiveFeed();

          // Trigger capture immediately
          if (mounted && frame != null) {
            widget.onTakePicture(frame!);
          }
        }
      } else {
        // Reset when face is lost
        if (_faceDetectedTime != null) {
          developer.log('⚠️ Face lost! Resetting countdown');
          _faceDetectedTime = null;
          _isAutoCapturing = false;
        }

        if (mounted) {
          setState(() {
            _canTakePicture = false;
            _countdown = 0;
            _instructionMessage =
                'No face detected. Position your face in the center';
            _showingInstruction = true;
          });
        }
      }
      return;
    }

    // Original head turn detection logic for attendance
    if (faces.isEmpty) {
      setState(() {
        _instructionMessage =
            'No face detected. Position your face in the center';
        _isHeadTurnedRight = false;
        _canTakePicture = false;
        _showingInstruction = true;
      });
      return;
    }

    final face = faces.first;
    final headYaw = face.headEulerAngleY ?? 0.0;

    if (headYaw > 15 && headYaw < 45) {
      // Head turned right appropriately
      setState(() {
        _isHeadTurnedRight = true;
        _canTakePicture = true;
        _instructionMessage = 'Perfect! Tap the button to take picture';
        _showingInstruction = false;
      });
    } else if (headYaw > -15 && headYaw < 15) {
      // Face centered, need to turn right
      setState(() {
        _isHeadTurnedRight = false;
        _canTakePicture = false;
        _instructionMessage = 'Now turn your head to the right';
        _showingInstruction = true;
      });
    } else {
      // Head turned too much or wrong direction
      setState(() {
        _isHeadTurnedRight = false;
        _canTakePicture = false;
        _instructionMessage = 'Turn your head slightly to the right';
        _showingInstruction = true;
      });
    }
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    // 1) Hitung rotasi seperti biasa
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    var rotationCompensation =
        _orientations[_controller!.value.deviceOrientation]!;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }
    final rotation = InputImageRotationValue.fromRawValue(
      rotationCompensation,
    )!;

    // 2) Konversi tiga plane ke NV21
    final bytes = _yuv420ToNv21(image);

    // 3) Buat metadata pakai NV21
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      // *** Paksa jadi NV21 ***
      format: InputImageFormat.nv21,
      // bytesPerRow untuk NV21 = width
      bytesPerRow: image.width,
    );

    // 4) Kembalikan InputImage
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    // NV21 = YYYYY... + interleaved VU
    final nv21 = Uint8List(width * height + (width * height ~/ 2));
    nv21.setRange(0, width * height, yPlane);

    int offset = width * height;
    final chromaRowStride = image.planes[1].bytesPerRow;
    final chromaPixelStride = image.planes[1].bytesPerPixel!;

    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final idx = row * chromaRowStride + col * chromaPixelStride;
        nv21[offset++] = vPlane[idx];
        nv21[offset++] = uPlane[idx];
      }
    }
    return nv21;
  }

  double calculateSymmetry(
    Point<int>? leftPosition,
    Point<int>? rightPosition,
  ) {
    if (leftPosition != null && rightPosition != null) {
      final double dx = (rightPosition.x - leftPosition.x).abs().toDouble();
      final double dy = (rightPosition.y - leftPosition.y).abs().toDouble();
      final distance = Offset(dx, dy).distance;

      return distance;
    }

    return 0.0;
  }
}

// Custom painter for face detection overlay
class FaceOverlayPainter extends CustomPainter {
  final Size screenSize;
  final bool isHeadTurnedRight;
  final bool canTakePicture;

  FaceOverlayPainter({
    required this.screenSize,
    required this.isHeadTurnedRight,
    required this.canTakePicture,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Create face detection oval
    final center = Offset(size.width / 2, size.height / 2 - 50);
    final ovalRect = Rect.fromCenter(
      center: center,
      width: 280,
      height: 350,
    );

    // Draw the overlay with cut-out for face
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final facePath = Path()..addOval(ovalRect);

    final finalPath = Path.combine(
      PathOperation.difference,
      overlayPath,
      facePath,
    );

    // Fill the overlay
    paint.color = Colors.black.withOpacity(0.7);
    canvas.drawPath(finalPath, paint);

    // Draw face outline
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    paint.color = canTakePicture
        ? Colors.green
        : isHeadTurnedRight
            ? Colors.orange
            : Colors.white;

    // Add glow effect
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(ovalRect, paint);

    // Draw solid outline
    paint.maskFilter = null;
    paint.strokeWidth = 2;
    canvas.drawOval(ovalRect, paint);

    // Draw corner guides
    _drawCornerGuides(canvas, ovalRect, paint);

    // Draw directional arrow if head needs to turn
    // if (!canTakePicture && !isHeadTurnedRight) {
    //   _drawDirectionalArrow(canvas, center, paint);
    // }
  }

  void _drawCornerGuides(Canvas canvas, Rect rect, Paint paint) {
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    paint.color = canTakePicture ? Colors.green : Colors.white;

    const cornerLength = 20.0;

    // Top-left corner
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerLength),
      Offset(rect.left, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.bottom),
      Offset(rect.right, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      paint,
    );
  }

  void _drawDirectionalArrow(Canvas canvas, Offset center, Paint paint) {
    paint.style = PaintingStyle.fill;
    paint.color = Colors.orange;

    final arrowCenter = Offset(center.dx + 120, center.dy);
    final arrowPath = Path();

    // Arrow pointing right
    arrowPath.moveTo(arrowCenter.dx - 15, arrowCenter.dy - 10);
    arrowPath.lineTo(arrowCenter.dx + 15, arrowCenter.dy);
    arrowPath.lineTo(arrowCenter.dx - 15, arrowCenter.dy + 10);
    arrowPath.close();

    canvas.drawPath(arrowPath, paint);

    // Draw arrow tail
    final tailRect = Rect.fromCenter(
      center: Offset(arrowCenter.dx - 25, arrowCenter.dy),
      width: 20,
      height: 4,
    );
    canvas.drawRRect(
        RRect.fromRectAndRadius(tailRect, const Radius.circular(2)), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
