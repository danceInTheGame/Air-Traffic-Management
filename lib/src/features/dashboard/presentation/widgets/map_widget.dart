import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/data_base_helper.dart';
import '../../data/mock_data.dart';
import '../../model/flight.dart';
import '../../model/postion.dart';
import '../../model/air_craft.dart';
import '../../model/airport.dart';
import '../../../../core/utils/move_algo.dart';
import '../../../../core/utils/airport_coordinates_helper.dart';


class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // Map des positions actuelles par numéro de vol
  final Map<String, Position> _flightPositions = {};
  
  // Map des trajectoires de vol (liste de waypoints)
  final Map<String, List<LatLng>> _flightRoutes = {};
  
  // Map des index actuels dans les trajectoires
  final Map<String, int> _currentWaypointIndex = {};
  
  // Map des aircrafts pour obtenir la vitesse
  final Map<String, Aircraft> _aircrafts = {};
  
  // Map des vols actifs
  final Map<String, Flight> _activeFlights = {};
  
  // Cache des aéroports
  final Map<String, Airport> _airportsCache = {};
  
  Timer? _updateTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _startSimulation();
    
    // Écouter les changements dans MockData pour recharger les vols
    MockData.updateNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    MockData.updateNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  // Callback appelé quand les données changent
  void _onDataChanged() {
    _reloadFlights();
  }

  // Recharger uniquement les vols actifs sans recharger tout
  Future<void> _reloadFlights() async {
    try {
      // Charger les vols actifs (In Flight uniquement)
      final allFlights = await _dbHelper.getAllFlights();
      final newActiveFlights = <String, Flight>{};
      
      for (var f in allFlights) {
        if (f.status == 'In Flight') {
          newActiveFlights[f.flightNumber] = f;
        }
      }

      print('DEBUG _reloadFlights: ${newActiveFlights.length} vols "In Flight" trouvés dans la DB');
      print('DEBUG _reloadFlights: ${_activeFlights.length} vols actuellement en mémoire');

      // Identifier les nouveaux vols OU les vols sans position/route
      for (var flight in newActiveFlights.values) {
        final isNew = !_activeFlights.containsKey(flight.flightNumber);
        final hasNoPosition = !_flightPositions.containsKey(flight.flightNumber);
        final hasNoRoute = !_flightRoutes.containsKey(flight.flightNumber);
        
        if (isNew || hasNoPosition || hasNoRoute) {
          print('DEBUG: Vol à initialiser: ${flight.flightNumber} (nouveau=$isNew, noPos=$hasNoPosition, noRoute=$hasNoRoute)');
          // Nouveau vol détecté OU vol existant sans position/route, initialiser sa route
          await _initializeFlightRoute(flight);
        }
      }

      // Identifier les vols qui ne sont plus actifs
      final flightsToRemove = <String>[];
      for (var flightNumber in _activeFlights.keys) {
        if (!newActiveFlights.containsKey(flightNumber)) {
          flightsToRemove.add(flightNumber);
          print('DEBUG: Vol à supprimer: $flightNumber');
        }
      }

      // Nettoyer les vols inactifs
      for (var flightNumber in flightsToRemove) {
        _flightPositions.remove(flightNumber);
        _flightRoutes.remove(flightNumber);
        _currentWaypointIndex.remove(flightNumber);
      }

      // Mettre à jour _activeFlights
      _activeFlights.clear();
      _activeFlights.addAll(newActiveFlights);

      print('DEBUG _reloadFlights: Après mise à jour:');
      print('  - _activeFlights: ${_activeFlights.length}');
      print('  - _flightPositions: ${_flightPositions.length}');
      print('  - _flightRoutes: ${_flightRoutes.length}');
      print('  - Vols actifs: ${_activeFlights.keys.join(", ")}');
      print('  - Positions: ${_flightPositions.keys.join(", ")}');
      print('  - Routes: ${_flightRoutes.keys.join(", ")}');

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Erreur lors du rechargement des vols: $e');
    }
  }

  Future<void> _initializeData() async {
    try {
      // Charger tous les aéroports
      final airports = await _dbHelper.getAllAirports();
      _airportsCache.clear();
      for (var a in airports) {
        _airportsCache[a.oaci] = a;
      }

      // Charger tous les aircrafts
      final aircrafts = await _dbHelper.getAllAircrafts();
      _aircrafts.clear();
      for (var a in aircrafts) {
        _aircrafts[a.registration] = a;
      }

      // Charger les vols actifs (In Flight uniquement)
      final allFlights = await _dbHelper.getAllFlights();
      _activeFlights.clear();
      for (var f in allFlights) {
        if (f.status == 'In Flight') {
          _activeFlights[f.flightNumber] = f;
        }
      }

      print('DEBUG: ${_activeFlights.length} vols actifs chargés');

      // Initialiser les trajectoires et positions pour chaque vol
      for (var flight in _activeFlights.values) {
        await _initializeFlightRoute(flight);
      }

      print('DEBUG: ${_flightPositions.length} positions initialisées');
      print('DEBUG: ${_flightRoutes.length} routes initialisées');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeFlightRoute(Flight flight) async {
    try {
      print('DEBUG _initializeFlightRoute: Début pour ${flight.flightNumber} (${flight.from} -> ${flight.to})');
      
      // Récupérer les coordonnées des aéroports
      final originCoords = await _getAirportCoordinates(flight.from);
      final destCoords = await _getAirportCoordinates(flight.to);

      if (originCoords == null || destCoords == null) {
        print('ERREUR: Impossible de trouver les coordonnées pour ${flight.flightNumber}');
        print('  - Origin (${flight.from}): $originCoords');
        print('  - Dest (${flight.to}): $destCoords');
        return;
      }

      print('DEBUG: Coordonnées trouvées pour ${flight.flightNumber}');
      print('  - Origin: $originCoords');
      print('  - Dest: $destCoords');

      // Générer la trajectoire courbe réaliste
      final route = _generateFlightRoute(originCoords, destCoords);
      _flightRoutes[flight.flightNumber] = route;
      print('DEBUG: Route générée avec ${route.length} waypoints');

      // Vérifier si une position existe déjà dans la DB
      var position = await _dbHelper.getLatestPosition(flight.flightNumber);
      
      if (position == null) {
        // Créer une position initiale au départ
        final heading = _calculateBearing(originCoords, route[1]);
        position = Position(
          latLng: originCoords,
          altitude: 35000.0,
          heading: heading,
        );
        await _dbHelper.insertPosition(flight.flightNumber, position);
        _currentWaypointIndex[flight.flightNumber] = 0;
        print('DEBUG: Position initiale créée pour ${flight.flightNumber} à $originCoords');
      } else {
        // Trouver le waypoint le plus proche de la position actuelle
        _currentWaypointIndex[flight.flightNumber] = 
            _findNearestWaypointIndex(position.latLng, route);
        print('DEBUG: Position existante trouvée pour ${flight.flightNumber}');
      }
      
      _flightPositions[flight.flightNumber] = position;
      
      print('DEBUG: Route initialisée avec succès pour ${flight.flightNumber}');
      print('  - Position ajoutée à _flightPositions');
      print('  - Total positions: ${_flightPositions.length}');
    } catch (e) {
      print('ERREUR lors de l\'initialisation de la route pour ${flight.flightNumber}: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<LatLng?> _getAirportCoordinates(String oaci) async {
    // Récupérer l'aéroport du cache pour avoir le nom du pays
    final airport = _airportsCache[oaci];
    final countryName = airport?.country;
    
    // Utiliser la méthode intelligente avec fallback
    final coords = await AirportCoordinatesHelper.getCoordinatesWithFallback(oaci, countryName);
    
    if (coords == null) {
      print('❌ ERREUR: Aucune coordonnée trouvée pour $oaci (${airport?.name ?? "inconnu"})');
      print('   Pays: ${countryName ?? "inconnu"}');
    }
    
    return coords;
  }

  List<LatLng> _generateFlightRoute(LatLng origin, LatLng destination) {
    // Générer une trajectoire courbe réaliste (Great Circle avec courbure)
    final route = <LatLng>[];
    const numSegments = 50; // Plus de segments = trajectoire plus lisse

    // Calculer la distance totale
    final distance = const Distance().distance(origin, destination);
    
    // Pour les vols longs, ajouter une courbure vers le nord (Great Circle)
    final midLat = (origin.latitude + destination.latitude) / 2;
    final midLon = (origin.longitude + destination.longitude) / 2;
    
    // Altitude de la courbure en fonction de la distance
    final curveFactor = math.min(distance / 10000000, 0.3); // Max 30% de courbure
    
    for (int i = 0; i <= numSegments; i++) {
      final t = i / numSegments;
      
      // Interpolation linéaire de base
      final lat = origin.latitude + (destination.latitude - origin.latitude) * t;
      final lon = origin.longitude + (destination.longitude - origin.longitude) * t;
      
      // Ajouter une courbure parabolique pour simuler la Great Circle
      final curve = 4 * curveFactor * t * (1 - t);
      final curvedLat = lat + curve * (midLat > 0 ? 10 : -10);
      
      route.add(LatLng(curvedLat, lon));
    }

    return route;
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - 
              math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearing = math.atan2(y, x) * 180 / math.pi;

    return (bearing + 360) % 360;
  }

  int _findNearestWaypointIndex(LatLng position, List<LatLng> route) {
    if (route.isEmpty) return 0;
    
    double minDistance = double.infinity;
    int nearestIndex = 0;
    
    for (int i = 0; i < route.length; i++) {
      final distance = const Distance().distance(position, route[i]);
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }
    
    return nearestIndex;
  }

  void _startSimulation() {
    // Mise à jour toutes les 2 secondes
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      // Recharger les vols depuis la DB à chaque cycle
      await _reloadFlights();
      // Puis mettre à jour les positions
      await _updateAircraftPositions();
    });
  }

  Future<void> _updateAircraftPositions() async {
    if (_flightPositions.isEmpty) return;

    // Créer une copie pour stocker les nouvelles positions
    final Map<String, Position> newPositions = {};

    // Parcourir TOUTES les positions existantes
    _flightPositions.forEach((flightNumber, currentPosition) {
      final flight = _activeFlights[flightNumber];
      final route = _flightRoutes[flightNumber];
      
      if (flight == null || route == null || route.isEmpty) {
        // Garder la position actuelle même si pas de route
        newPositions[flightNumber] = currentPosition;
        return;
      }

      // Récupérer la vitesse de l'aircraft
      final aircraft = _aircrafts[flight.aircraft];
      final speedKt = aircraft?.cruiseSpeed ?? 450.0;

      // Obtenir l'index du waypoint actuel
      int currentWaypointIdx = _currentWaypointIndex[flightNumber] ?? 0;

      // Si on a atteint la destination, garder la position actuelle
      if (currentWaypointIdx >= route.length - 1) {
        newPositions[flightNumber] = currentPosition;
        return;
      }

      // Waypoint cible
      final targetWaypoint = route[currentWaypointIdx + 1];
      
      // Calculer le cap vers le waypoint cible
      final heading = _calculateBearing(currentPosition.latLng, targetWaypoint);

      // Calculer la nouvelle position
      final newPosition = moveAircraft(
        current: currentPosition.copyWith(heading: heading),
        speedKt: speedKt,
        deltaTimeSeconds: 2.0,
      );

      // Vérifier si on a atteint le waypoint cible
      final distanceToWaypoint = const Distance().distance(
        newPosition.latLng, 
        targetWaypoint
      );

      // Si on est proche du waypoint (moins de 5 km), passer au suivant
      if (distanceToWaypoint < 5000) {
        _currentWaypointIndex[flightNumber] = currentWaypointIdx + 1;
      }

      // Stocker la nouvelle position
      newPositions[flightNumber] = newPosition;

      // Sauvegarder dans la DB (de manière asynchrone)
      _dbHelper.insertPosition(flightNumber, newPosition);
    });

    // Remplacer toutes les positions en une seule fois
    _flightPositions.clear();
    _flightPositions.addAll(newPositions);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          color: const Color(0xFF1E1E2E),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(48.8566, 2.3522), // Paris
          initialZoom: 4.5,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.atc_dashboard',
            tileBuilder: (context, widget, tile) {
              return ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  -1, 0, 0, 0, 255,
                  0, -1, 0, 0, 255,
                  0, 0, -1, 0, 255,
                  0, 0, 0, 1, 0,
                ]),
                child: widget,
              );
            },
          ),
          // Afficher les trajectoires de vol
          PolylineLayer(
            polylines: _flightRoutes.entries.map((entry) {
              return Polyline(
                points: entry.value,
                color: const Color.fromARGB(255, 0, 225, 255).withOpacity(0.3),
                strokeWidth: 2.0,
                pattern: StrokePattern.dotted(), 
              );
            }).toList(),
          ),

          // Afficher les avions en vol
          MarkerLayer(
            markers: _flightPositions.entries.map((entry) {
              final flightNumber = entry.key;
              final position = entry.value;
              final flight = _activeFlights[flightNumber];

              return Marker(
                point: position.latLng,
                width: 60,
                height: 60,
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: position.heading * math.pi / 180,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.airplanemode_active,
                        color: Colors.cyan,
                        size: 28,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.cyan, width: 1),
                        ),
                        child: Text(
                          flight?.flightNumber ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          // Afficher les aéroports de départ et d'arrivée
          MarkerLayer(
            markers: _buildAirportMarkers(),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildAirportMarkers() {
    final markers = <Marker>[];
    final processedAirports = <String>{};

    for (var flight in _activeFlights.values) {
      // Aéroport de départ
      if (!processedAirports.contains(flight.from)) {
        // Note: On doit récupérer les coordonnées de manière synchrone ici
        // Les coordonnées sont déjà calculées lors de _initializeFlightRoute
        final route = _flightRoutes[flight.flightNumber];
        if (route != null && route.isNotEmpty) {
          final coords = route.first; // Origine de la route
          markers.add(
            Marker(
              point: coords,
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: const Icon(
                Icons.flight_takeoff,
                color: Colors.green,
                size: 20,
              ),
            ),
          );
        }
        processedAirports.add(flight.from);
      }

      // Aéroport d'arrivée
      if (!processedAirports.contains(flight.to)) {
        final route = _flightRoutes[flight.flightNumber];
        if (route != null && route.isNotEmpty) {
          final coords = route.last; // Destination de la route
          markers.add(
            Marker(
              point: coords,
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: const Icon(
                Icons.flight_land,
                color: Colors.red,
                size: 20,
              ),
            ),
          );
        }
        processedAirports.add(flight.to);
      }
    }

    return markers;
  }
}