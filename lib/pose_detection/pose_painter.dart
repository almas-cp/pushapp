import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Custom painter for visualizing pose detection landmarks and skeleton
/// 
/// This painter draws:
/// - Pose landmarks as colored circles
/// - Skeleton connections between landmarks
/// - Confidence indicators for each landmark
/// - Visual feedback for correct/incorrect form
class PosePainter extends CustomPainter {
  final Pose? pose;
  final Size imageSize;
  final bool isInCorrectForm;
  
  PosePainter({
    required this.pose,
    required this.imageSize,
    this.isInCorrectForm = true,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (pose == null) return;
    
    final landmarks = pose!.landmarks;
    
    // Draw all skeleton connections first (so they appear behind landmarks)
    _drawSkeleton(canvas, size, landmarks);
    
    // Draw all landmarks on top
    _drawLandmarks(canvas, size, landmarks);
    
    // Draw form feedback indicator
    _drawFormFeedback(canvas, size);
  }
  
  /// Draw all pose landmarks as colored circles
  void _drawLandmarks(Canvas canvas, Size size, Map<PoseLandmarkType, PoseLandmark> landmarks) {
    landmarks.forEach((type, landmark) {
      _drawLandmark(canvas, size, landmark);
    });
  }
  
  /// Draw a single landmark with confidence indicator
  void _drawLandmark(Canvas canvas, Size size, PoseLandmark landmark) {
    // Convert landmark coordinates to canvas coordinates
    final point = _translatePoint(landmark.x, landmark.y, size);
    
    // Determine color based on confidence
    final color = _getConfidenceColor(landmark.likelihood);
    
    // Draw outer circle (confidence indicator)
    final outerPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, 12.0, outerPaint);
    
    // Draw inner circle (landmark point)
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, 6.0, innerPaint);
    
    // Draw border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(point, 6.0, borderPaint);
  }
  
  /// Draw skeleton connections between landmarks
  void _drawSkeleton(Canvas canvas, Size size, Map<PoseLandmarkType, PoseLandmark> landmarks) {
    // Define skeleton connections (pairs of landmarks to connect)
    final connections = _getSkeletonConnections();
    
    for (final connection in connections) {
      final startLandmark = landmarks[connection.start];
      final endLandmark = landmarks[connection.end];
      
      if (startLandmark != null && endLandmark != null) {
        _drawConnection(canvas, size, startLandmark, endLandmark);
      }
    }
  }
  
  /// Draw a connection line between two landmarks
  void _drawConnection(Canvas canvas, Size size, PoseLandmark start, PoseLandmark end) {
    final startPoint = _translatePoint(start.x, start.y, size);
    final endPoint = _translatePoint(end.x, end.y, size);
    
    // Calculate average confidence for the connection
    final avgConfidence = (start.likelihood + end.likelihood) / 2;
    final color = _getConfidenceColor(avgConfidence);
    
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(startPoint, endPoint, paint);
  }
  
  /// Draw visual feedback for correct/incorrect form
  void _drawFormFeedback(Canvas canvas, Size size) {
    // Draw a colored border around the canvas to indicate form status
    final feedbackColor = isInCorrectForm ? Colors.green : Colors.red;
    
    final paint = Paint()
      ..color = feedbackColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
    
    // Draw form status text
    final textPainter = TextPainter(
      text: TextSpan(
        text: isInCorrectForm ? '✓ Good Form' : '✗ Adjust Position',
        style: TextStyle(
          color: feedbackColor,
          fontSize: 24.0,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.7),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        20,
      ),
    );
  }
  
  /// Translate pose coordinates to canvas coordinates
  Offset _translatePoint(double x, double y, Size size) {
    // ML Kit returns coordinates in the original image space
    // We need to scale them to the canvas size
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    
    return Offset(x * scaleX, y * scaleY);
  }
  
  /// Get color based on confidence level
  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) {
      return Colors.green;
    } else if (confidence > 0.5) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }
  
  /// Define skeleton connections between landmarks
  List<_Connection> _getSkeletonConnections() {
    return [
      // Face
      _Connection(PoseLandmarkType.leftEar, PoseLandmarkType.leftEye),
      _Connection(PoseLandmarkType.leftEye, PoseLandmarkType.nose),
      _Connection(PoseLandmarkType.nose, PoseLandmarkType.rightEye),
      _Connection(PoseLandmarkType.rightEye, PoseLandmarkType.rightEar),
      
      // Torso
      _Connection(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
      _Connection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
      _Connection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
      _Connection(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
      
      // Left arm
      _Connection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
      _Connection(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
      _Connection(PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky),
      _Connection(PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex),
      _Connection(PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb),
      
      // Right arm
      _Connection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
      _Connection(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
      _Connection(PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky),
      _Connection(PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex),
      _Connection(PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb),
      
      // Left leg
      _Connection(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
      _Connection(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
      _Connection(PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel),
      _Connection(PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex),
      
      // Right leg
      _Connection(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
      _Connection(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
      _Connection(PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel),
      _Connection(PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex),
    ];
  }
  
  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose ||
           oldDelegate.imageSize != imageSize ||
           oldDelegate.isInCorrectForm != isInCorrectForm;
  }
}

/// Helper class to define a connection between two landmarks
class _Connection {
  final PoseLandmarkType start;
  final PoseLandmarkType end;
  
  _Connection(this.start, this.end);
}
