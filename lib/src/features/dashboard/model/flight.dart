class Flight {
  final String flightNumber;
  final String aircraft;
  final String from;
  final String to;
  final String status; // 'In Flight', 'Delayed', 'En Route', 'Boarding'
  final String depTime;
  final String arrTime;

  Flight({
    required this.flightNumber,
    required this.aircraft,
    required this.from,
    required this.to,
    required this.status,
    required this.depTime,
    required this.arrTime,
  });
}
