/// Represents the coordinate positions of two fingers for multi-touch simulation.
library;

class FingerIndicators {
  FingerIndicators({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
  final double x1;
  final double y1;
  final double x2;
  final double y2;
}
