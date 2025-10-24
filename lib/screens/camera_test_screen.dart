import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Screen to test different camera preview rendering options
/// Displays multiple camera feeds with different aspect ratio handling
class CameraTestScreen extends StatefulWidget {
  const CameraTestScreen({Key? key}) : super(key: key);

  @override
  State<CameraTestScreen> createState() => _CameraTestScreenState();
}

class _CameraTestScreenState extends State<CameraTestScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  String _errorMessage = '';
  int _selectedOption = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No cameras available');
        return;
      }

      // Use front camera if available
      CameraDescription camera;
      try {
        camera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
      } catch (e) {
        camera = cameras.first;
      }

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Preview Test'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
          : !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Tabs for different options
                    Container(
                      color: Colors.black87,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTab(0, 'AspectRatio'),
                            _buildTab(1, 'FittedBox Cover'),
                            _buildTab(2, 'FittedBox Contain'),
                            _buildTab(3, 'Transform Scale'),
                            _buildTab(4, 'ClipRect + Overflow'),
                          ],
                        ),
                      ),
                    ),
                    
                    // Camera preview with debug info
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildSelectedPreview(),
                          
                          // Debug info overlay
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildDebugInfo(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedOption == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedOption = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.deepPurple : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedPreview() {
    switch (_selectedOption) {
      case 0:
        return _buildAspectRatioPreview();
      case 1:
        return _buildFittedBoxCoverPreview();
      case 2:
        return _buildFittedBoxContainPreview();
      case 3:
        return _buildTransformScalePreview();
      case 4:
        return _buildClipRectOverflowPreview();
      default:
        return _buildAspectRatioPreview();
    }
  }

  /// Option 1: AspectRatio (maintains aspect ratio with black bars)
  Widget _buildAspectRatioPreview() {
    final aspectRatio = _cameraController!.value.aspectRatio;
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  /// Option 2: FittedBox with BoxFit.cover (fills screen, may crop)
  Widget _buildFittedBoxCoverPreview() {
    final size = MediaQuery.of(context).size;
    final aspectRatio = _cameraController!.value.aspectRatio;
    
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: size.width / aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }

  /// Option 3: FittedBox with BoxFit.contain (shows full camera, may have bars)
  Widget _buildFittedBoxContainPreview() {
    return Container(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _cameraController!.value.previewSize!.height,
            height: _cameraController!.value.previewSize!.width,
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }

  /// Option 4: Transform with scale (fills screen by scaling)
  Widget _buildTransformScalePreview() {
    final size = MediaQuery.of(context).size;
    final previewSize = _cameraController!.value.previewSize!;
    final aspectRatio = _cameraController!.value.aspectRatio;
    
    // Calculate scale to fill screen
    final screenAspect = size.width / size.height;
    final scale = screenAspect > aspectRatio
        ? size.width / (previewSize.height)
        : size.height / (previewSize.width);
    
    return Container(
      color: Colors.black,
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }

  /// Option 5: ClipRect with OverflowBox (alternative full-screen approach)
  Widget _buildClipRectOverflowPreview() {
    final size = MediaQuery.of(context).size;
    final previewSize = _cameraController!.value.previewSize!;
    
    // Calculate scale to cover screen
    final scaleX = size.width / previewSize.height;
    final scaleY = size.height / previewSize.width;
    final scale = scaleX > scaleY ? scaleX : scaleY;
    
    return Container(
      color: Colors.black,
      child: ClipRect(
        child: Transform.scale(
          scale: scale,
          child: Center(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebugInfo() {
    final size = MediaQuery.of(context).size;
    final previewSize = _cameraController!.value.previewSize!;
    final aspectRatio = _cameraController!.value.aspectRatio;
    final screenAspect = size.width / size.height;

    final methods = [
      'AspectRatio (with bars)',
      'FittedBox Cover (crop edges)',
      'FittedBox Contain (show all)',
      'Transform Scale (calculated)',
      'ClipRect + Overflow',
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎥 Method: ${methods[_selectedOption]}',
            style: const TextStyle(
              color: Colors.yellow,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '📱 Screen: ${size.width.toInt()}×${size.height.toInt()} (${screenAspect.toStringAsFixed(2)}:1)',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            '📷 Camera: ${previewSize.width.toInt()}×${previewSize.height.toInt()} (${aspectRatio.toStringAsFixed(2)}:1)',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            '🔄 Rotation: ${_cameraController!.description.lensDirection == CameraLensDirection.front ? "Front" : "Back"} Camera',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            _getMethodDescription(_selectedOption),
            style: const TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  String _getMethodDescription(int option) {
    switch (option) {
      case 0:
        return 'Maintains aspect ratio. May have black bars on sides/top.';
      case 1:
        return 'Fills entire screen by cropping edges. No distortion.';
      case 2:
        return 'Shows entire camera feed. May have black bars.';
      case 3:
        return 'Scales uniformly to fill screen. May crop slightly.';
      case 4:
        return 'Alternative full-screen method with clipping.';
      default:
        return '';
    }
  }
}

