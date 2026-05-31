import 'flight.dart';

class CollisionAlert {
  final Flight flightA;
  final Flight flightB;
  final double horizontalDistance; // en NM
  final double verticalDistance;   // en ft
  final DateTime detectedAt;

  CollisionAlert({
    required this.flightA,
    required this.flightB,
    required this.horizontalDistance,
    required this.verticalDistance,
    required this.detectedAt,
  });
}
