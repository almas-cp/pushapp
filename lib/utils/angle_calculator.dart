import 'dart:math';
import 'dart:ui';

/// Utility class for geometric calculations used in pose detection
/// Provides methods for angle calculation, distance measurement, and alignment checking
class AngleCalculator {
  /// Calculates the angle formed by three points (a, b, c) where b is the vertex
  /// 
  /// Uses the arctangent formula with cross product and dot product
  /// to calculate the angle between vectors ba and bc
  /// 
  /// Parameters:
  ///   - a: First point
  ///   - b: Vertex point (the angle is measured at this point)
  ///   - c: Third point
  /// 
  /// Returns: Angle in degrees (0-180)
  static double calculateAngle(Point<double> a, Point<double> b, Point<double> c) {
    // Create vectors from b to a and b to c
    final ba = Offset(a.x - b.x, a.y - b.y);
    final bc = Offset(c.x - b.x, c.y - b.y);
    
    // Calculate dot product: ba · bc
    final dot = ba.dx * bc.dx + ba.dy * bc.dy;
    
    // Calculate cross product: ba × bc (z-component in 2D)
    final cross = ba.dx * bc.dy - ba.dy * bc.dx;
    
    // Calculate angle using atan2 and convert to degrees
    final angle = atan2(cross, dot) * 180 / pi;
    
    // Return absolute value to get angle between 0-180 degrees
    return angle.abs();
  }
  
  /// Calculates the Euclidean distance between two points
  /// 
  /// Uses the formula: sqrt((x2-x1)² + (y2-y1)²)
  /// 
  /// Parameters:
  ///   - a: First point
  ///   - b: Second point
  /// 
  /// Returns: Distance between the two points
  static double calculateDistance(Point<double> a, Point<double> b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    
    return sqrt(dx * dx + dy * dy);
  }
  
  /// Checks if a list of points are aligned within a threshold
  /// 
  /// Determines alignment by checking if all intermediate points
  /// lie close to the line formed by the first and last points
  /// 
  /// Parameters:
  ///   - points: List of points to check (must have at least 2 points)
  ///   - threshold: Maximum allowed deviation from the line (in degrees)
  /// 
  /// Returns: true if all points are aligned within the threshold
  static bool isAligned(List<Point<double>> points, double threshold) {
    if (points.length < 2) {
      return true; // Single point or empty list is considered aligned
    }
    
    if (points.length == 2) {
      return true; // Two points always form a line
    }
    
    // Check alignment by calculating angles between consecutive triplets
    // If all angles are close to 180°, the points are aligned
    for (int i = 0; i < points.length - 2; i++) {
      final angle = calculateAngle(points[i], points[i + 1], points[i + 2]);
      
      // Check if angle deviates from 180° (straight line) by more than threshold
      final deviation = (180 - angle).abs();
      
      if (deviation > threshold) {
        return false;
      }
    }
    
    return true;
  }
}
