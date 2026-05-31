import 'package:latlong2/latlong.dart';

class AirRoute {
  final String id;
  final String from;
  final String to;
  final List<LatLng> waypoints;

  AirRoute({
    required this.id,
    required this.from,
    required this.to,
    required this.waypoints,
  });
}
