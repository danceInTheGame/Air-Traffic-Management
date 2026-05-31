class Aircraft {
  final String registration; // ex: F-GSPY
  final String model;        // ex: A320
  final double cruiseSpeed;  // en nœuds (kt)
  final double maxAltitude;  // en pieds (ft)

  Aircraft({
    required this.registration,
    required this.model,
    required this.cruiseSpeed,
    required this.maxAltitude,
  });
}
