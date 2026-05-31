import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../../features/dashboard/model/postion.dart';

Position moveAircraft({
  required Position current,
  required double speedKt,
  required double deltaTimeSeconds,
}) {
  const earthRadius = 6371000.0; // mètres

  final speedMs = speedKt * 0.514444; // kt → m/s
  final distance = speedMs * deltaTimeSeconds;

  final lat1 = current.latLng.latitude * pi / 180;
  final lon1 = current.latLng.longitude * pi / 180;
  final bearing = current.heading * pi / 180;

  final lat2 = asin(
    sin(lat1) * cos(distance / earthRadius) +
        cos(lat1) * sin(distance / earthRadius) * cos(bearing),
  );

  final lon2 =
      lon1 +
      atan2(
        sin(bearing) * sin(distance / earthRadius) * cos(lat1),
        cos(distance / earthRadius) - sin(lat1) * sin(lat2),
      );

  return current.copyWith(latLng: LatLng(lat2 * 180 / pi, lon2 * 180 / pi));
}
