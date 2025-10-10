import 'dart:async';
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
  
  const PoseDetectorView({
    Key? key,
    this.onPoseDetected,
    this.exerciseCounter,
    this.showCamera = true,
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
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21, // Required for Android ML Kit
      );
      
      await _cameraController!.initialize();
      
      setState(() {
        _isCameraInitialized = true;
      });
      
      // Start image stream for pose detection
      _startImageStream();
      
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
    
    try {
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _convertCameraImage(image);
      
      if (inputImage == null) return;
      
      // Detect poses in the image
      final poses = await _poseDetector!.processImage(inputImage);
      
      if (poses.isNotEmpty) {
        final pose = poses.first;
        
        // Check if user is properly visible (InFrameLikelihood > 0.5)
        final isVisible = _checkUserVisibility(pose);
        
        setState(() {
          _currentPose = pose;
          _isUserVisible = isVisible;
        });
        
        // Only process pose if user is visible
        if (isVisible) {
          // Pass pose to exercise counter if provided
          widget.exerciseCounter?.processPose(pose);
          
          // Invoke callback if provided
          widget.onPoseDetected?.call(pose);
        }
      } else {
        setState(() {
          _currentPose = null;
          _isUserVisible = false;
        });
      }
    } catch (e) {
      // Handle detection errors silently to avoid UI disruption
      debugPrint('Error processing image: $e');
    }
  }
  
  /// Convert CameraImage to InputImage for ML Kit processing
  InputImage? _convertCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    
    final camera = _cameraController!.description;
    
    // Get image rotation based on device orientation and camera sensor
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    
    if (camera.lensDirection == CameraLensDirection.front) {
      rotation = InputImageRotation.rotation270deg;
    } else {
      rotation = InputImageRotation.rotation90deg;
    }
    
    // Get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    
    // Get plane data
    if (image.planes.isEmpty) return null;
    
    final plane = image.planes.first;
    
    // Create InputImage
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
  
  /// Check if user is properly visible in frame
  /// Returns true if InFrameLikelihood > 0.5 for key landmarks
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
      if (landmark != null && landmark.likelihood > 0.5) {
        visibleCount++;
      }
    }
    
    // User is considered visible if at least 3 out of 5 key landmarks are visible
    return visibleCount >= 3;
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
        // Camera preview
        if (widget.showCamera)
          Center(
            child: AspectRatio(
              aspectRatio: cameraAspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
        
        // Pose visualization overlay
        if (_currentPose != null && widget.showCamera)
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
