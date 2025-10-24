import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'pose_painter.dart';
import 'exercise_counter.dart';

/// Widget that provides real-time pose detection using device camera
/// 
/// This widget:
/// - Initializes and manages the camera
/// - Processes camera frames through ML Kit pose detection
/// - Visualizes detected poses using PosePainter
/// - Provides callbacks for pose detection events
/// - Handles user visibility warnings
class PoseDetectorView extends StatefulWidget {
  /// Callback invoked when a pose is detected
  final Function(Pose pose)? onPoseDetected;
  
  /// Exercise counter to process detected poses
  final ExerciseCounter? exerciseCounter;
  
  /// Whether to show the camera preview
  final bool showCamera;
  
  /// Debug callback for monitoring detection status
  final Function(String debugInfo)? onDebugInfo;
  
  const PoseDetectorView({
    Key? key,
    this.onPoseDetected,
    this.exerciseCounter,
    this.showCamera = true,
    this.onDebugInfo,
  }) : super(key: key);
  
  @override
  State<PoseDetectorView> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  Pose? _currentPose;
  bool _isUserVisible = true;
  String? _errorMessage;
  int _framesProcessed = 0;
  int _successfulDetections = 0;
  int _errorCount = 0;
  DateTime? _lastDebugUpdate;
  
  @override
  void initState() {
    super.initState();
    _initializePoseDetector();
    _initializeCamera();
  }
  
  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
  
  /// Initialize ML Kit pose detector with stream mode and accurate model
  void _initializePoseDetector() {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    );
    _poseDetector = PoseDetector(options: options);
  }
  
  /// Initialize camera with front camera and medium resolution
  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras available on this device';
        });
        return;
      }
      
      // Find front camera (prefer front camera for exercises)
      CameraDescription? frontCamera;
      try {
        frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
      } catch (e) {
        // If no front camera, use the first available camera
        frontCamera = cameras.first;
      }
      
      // Initialize camera controller with medium resolution
      // Note: Using YUV420 because NV21 conversion has bugs in camera plugin
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // Use YUV420 to avoid NV21 bug
      );
      
      await _cameraController!.initialize();
      
      setState(() {
        _isCameraInitialized = true;
      });
      
      _updateDebugInfo('📷 Camera ready, resolution: ${_cameraController!.value.previewSize}');
      
      // Start image stream for pose detection
      _startImageStream();
      
      _updateDebugInfo('🎬 Streaming started, analyzing frames...');
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: ${e.toString()}';
      });
    }
  }
  
  /// Start processing camera frames for pose detection
  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    _cameraController!.startImageStream((CameraImage image) {
      if (!_isDetecting) {
        _isDetecting = true;
        _processImage(image).then((_) {
          _isDetecting = false;
        });
      }
    });
  }
  
  /// Process a camera frame and detect poses
  Future<void> _processImage(CameraImage image) async {
    if (_poseDetector == null) return;
    
    _framesProcessed++;
    
    try {
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _convertCameraImage(image);
      
      if (inputImage == null) {
        _errorCount++;
        _updateDebugInfo('❌ Conversion failed! Format: ${image.format.raw}, Errors: $_errorCount');
        return;
      }
      
      // Detect poses in the image
      final poses = await _poseDetector!.processImage(inputImage);
      
      _successfulDetections++;
      
      if (poses.isNotEmpty) {
        final pose = poses.first;
        
        // Check if user is properly visible
        final isVisible = _checkUserVisibility(pose);
        
        _updateDebugInfo('✅ Pose detected! Frames: $_framesProcessed, Poses: $_successfulDetections, Errors: $_errorCount');
        
        if (mounted) {
          setState(() {
            _currentPose = pose;
            _isUserVisible = isVisible;
          });
        }
        
        // Only process pose if user is visible
        if (isVisible) {
          // Pass pose to exercise counter if provided
          widget.exerciseCounter?.processPose(pose);
          
          // Invoke callback if provided
          widget.onPoseDetected?.call(pose);
        }
      } else {
        _updateDebugInfo('No pose in frame (Frames: $_framesProcessed)');
        if (mounted) {
          setState(() {
            _currentPose = null;
            _isUserVisible = false;
          });
        }
      }
    } catch (e) {
      // Handle detection errors silently to avoid UI disruption
      // This catches buffer errors from camera plugin
      _errorCount++;
      _updateDebugInfo('❌ Error: $e (Count: $_errorCount)');
      debugPrint('Error processing image: $e');
      // Don't update state on error, just continue
    }
  }
  
  /// Update debug info (throttled to 3 times per second)
  void _updateDebugInfo(String info) {
    final now = DateTime.now();
    // Throttle to 3 updates per second for better real-time feedback
    if (_lastDebugUpdate == null || now.difference(_lastDebugUpdate!).inMilliseconds > 333) {
      _lastDebugUpdate = now;
      widget.onDebugInfo?.call(info);
      debugPrint('DEBUG: $info'); // Also print to console
    }
  }
  
  /// Convert CameraImage to InputImage for ML Kit processing
  /// Converts YUV420 to NV21 format required by ML Kit
  InputImage? _convertCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    
    try {
      final camera = _cameraController!.description;
      
      // Get image rotation based on device orientation and camera sensor
      InputImageRotation rotation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotation = InputImageRotation.rotation270deg;
      } else {
        rotation = InputImageRotation.rotation90deg;
      }
      
      // Check if we have the expected YUV420 format (3 planes)
      if (image.planes.length != 3) {
        debugPrint('Expected 3 planes for YUV420, got ${image.planes.length}');
        return null;
      }
      
      // Convert YUV420 to NV21 format
      final bytes = _convertYUV420ToNV21(image);
      if (bytes == null) {
        debugPrint('Failed to convert YUV420 to NV21');
        return null;
      }
      
      // Create InputImage with NV21 format
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }
  
  /// Convert YUV420 to NV21 format
  /// YUV420 has 3 planes: Y, U, V
  /// NV21 format: Y plane followed by interleaved VU plane
  Uint8List? _convertYUV420ToNV21(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int ySize = width * height;
      final int uvSize = width * height ~/ 2;
      
      final Uint8List nv21 = Uint8List(ySize + uvSize);
      
      // Copy Y plane
      final yPlane = image.planes[0];
      final yBytes = yPlane.bytes;
      
      if (yPlane.bytesPerRow == width) {
        // Direct copy if no padding
        nv21.setRange(0, ySize, yBytes);
      } else {
        // Copy row by row if there's padding
        for (int i = 0; i < height; i++) {
          nv21.setRange(
            i * width,
            i * width + width,
            yBytes,
            i * yPlane.bytesPerRow,
          );
        }
      }
      
      // Interleave U and V planes (V first for NV21)
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];
      final uBytes = uPlane.bytes;
      final vBytes = vPlane.bytes;
      
      int uvIndex = ySize;
      final int uvWidth = width ~/ 2;
      final int uvHeight = height ~/ 2;
      
      for (int i = 0; i < uvHeight; i++) {
        for (int j = 0; j < uvWidth; j++) {
          final int uIndex = i * uPlane.bytesPerRow + j;
          final int vIndex = i * vPlane.bytesPerRow + j;
          
          // NV21 format: YYYYVUVUVU...
          nv21[uvIndex++] = vBytes[vIndex];
          nv21[uvIndex++] = uBytes[uIndex];
        }
      }
      
      return nv21;
    } catch (e) {
      debugPrint('Error in YUV420 to NV21 conversion: $e');
      return null;
    }
  }
  
  /// Check if user is properly visible in frame
  /// Returns true if InFrameLikelihood > 0.3 for key landmarks
  bool _checkUserVisibility(Pose pose) {
    // Check key landmarks for visibility
    final keyLandmarks = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];
    
    int visibleCount = 0;
    for (final landmarkType in keyLandmarks) {
      final landmark = pose.landmarks[landmarkType];
      if (landmark != null && landmark.likelihood > 0.3) {
        visibleCount++;
      }
    }
    
    // User is considered visible if at least 2 out of 5 key landmarks are visible
    // This is more lenient to avoid false warnings, especially for head-only exercises
    return visibleCount >= 2;
  }
  
  /// Clean up camera and detector resources
  Future<void> _cleanup() async {
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    await _poseDetector?.close();
    _cameraController = null;
    _poseDetector = null;
  }
  
  @override
  Widget build(BuildContext context) {
    // Show error message if camera initialization failed
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _initializeCamera();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show loading indicator while camera initializes
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing camera...'),
          ],
        ),
      );
    }
    
    // Get camera preview size
    final size = MediaQuery.of(context).size;
    final cameraAspectRatio = _cameraController!.value.aspectRatio;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview with overlay - FittedBox Contain method
        if (widget.showCamera)
          Container(
            color: Colors.black,
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Camera preview
                      CameraPreview(_cameraController!),
                      
                      // Pose visualization overlay (matches camera preview size)
                      if (_currentPose != null)
                        CustomPaint(
                          painter: PosePainter(
                            pose: _currentPose,
                            imageSize: Size(
                              _cameraController!.value.previewSize!.height,
                              _cameraController!.value.previewSize!.width,
                            ),
                            isInCorrectForm: widget.exerciseCounter?.isInCorrectForm ?? true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        
        // Warning when user not properly visible
        if (!_isUserVisible)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please position yourself fully in frame',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
