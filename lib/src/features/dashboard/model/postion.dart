import 'package:latlong2/latlong.dart';

class Position {
  final LatLng latLng;
  final double altitude; // en pieds
  final double heading;  // cap en degrés (0–360)

  Position({
    required this.latLng,
    required this.altitude,
    required this.heading,
  });

  Position copyWith({
    LatLng? latLng,
    double? altitude,
    double? heading,
  }) {
    return Position(
      latLng: latLng ?? this.latLng,
      altitude: altitude ?? this.altitude,
      heading: heading ?? this.heading,
    );
  }
}
