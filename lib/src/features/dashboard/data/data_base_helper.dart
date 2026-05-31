import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

// Import des modèles
import '../model/air_craft.dart';
import '../model/flight.dart';
import '../model/postion.dart';
import '../model/air_route.dart';
import '../model/collision_alert.dart';
import '../model/airport.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  
  // Cache pour les aéroports du JSON
  static List<Airport>? _airportsCache;
  static Map<String, Airport>? _airportsByOaciCache;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('atc_database.db');
    return _database!;
  }

  // Charger les aéroports depuis le fichier JSON (assets)
  Future<void> _loadAirportsFromJson() async {
    if (_airportsCache != null) return; // Déjà chargé

    try {
      // Lire le fichier JSON depuis les assets
      final jsonString = await rootBundle.loadString('assets/airports_1163.json');
      final List<dynamic> airportsJson = json.decode(jsonString);
      
      // Convertir en objets Airport
      _airportsCache = [];
      _airportsByOaciCache = {};
      
      for (var airportData in airportsJson) {
        if (airportData['OACI'] != null && 
            airportData['OACI'].toString().trim().isNotEmpty) {
          
          final airport = Airport(
            oaci: airportData['OACI'].toString().trim(),
            name: airportData['nom']?.toString().trim() ?? '',
            city: airportData['ville']?.toString().trim() ?? '',
            country: airportData['Pays']?.toString().trim() ?? '',
          );
          
          _airportsCache!.add(airport);
          _airportsByOaciCache![airport.oaci] = airport;
        }
      }
      
      print('${_airportsCache!.length} aéroports chargés depuis le JSON');
    } catch (e) {
      print('Erreur lors du chargement des aéroports: $e');
      _airportsCache = [];
      _airportsByOaciCache = {};
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Ajout de la table airport
      await db.execute('''
        CREATE TABLE airport (
          oaci TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          city TEXT NOT NULL,
          country TEXT NOT NULL
        )
      ''');

      // Ajout de l'index pour améliorer les recherches
      await db.execute('CREATE INDEX idx_airport_country ON airport(country)');
      await db.execute('CREATE INDEX idx_airport_city ON airport(city)');

      // Insertion des données par défaut
      await _insertDefaultAirports(db);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Table Airport
    await db.execute('''
      CREATE TABLE airport (
        oaci TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        city TEXT NOT NULL,
        country TEXT NOT NULL
      )
    ''');

    // Table Aircraft
    await db.execute('''
      CREATE TABLE aircraft (
        registration TEXT PRIMARY KEY,
        model TEXT NOT NULL,
        cruise_speed REAL NOT NULL,
        max_altitude REAL NOT NULL
      )
    ''');

    // Table Flight
    await db.execute('''
      CREATE TABLE flight (
        flight_number TEXT PRIMARY KEY,
        aircraft TEXT NOT NULL,
        origin TEXT NOT NULL,
        destination TEXT NOT NULL,
        status TEXT NOT NULL,
        dep_time TEXT NOT NULL,
        arr_time TEXT NOT NULL,
        FOREIGN KEY (aircraft) REFERENCES aircraft (registration),
        FOREIGN KEY (origin) REFERENCES airport (oaci),
        FOREIGN KEY (destination) REFERENCES airport (oaci)
      )
    ''');

    // Table Position
    await db.execute('''
      CREATE TABLE position (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        flight_number TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL NOT NULL,
        heading REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (flight_number) REFERENCES flight (flight_number) ON DELETE CASCADE
      )
    ''');

    // Table AirRoute
    await db.execute('''
      CREATE TABLE air_route (
        id TEXT PRIMARY KEY,
        origin TEXT NOT NULL,
        destination TEXT NOT NULL,
        FOREIGN KEY (origin) REFERENCES airport (oaci),
        FOREIGN KEY (destination) REFERENCES airport (oaci)
      )
    ''');

    // Table Waypoint (pour stocker les waypoints des routes)
    await db.execute('''
      CREATE TABLE waypoint (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        sequence_order INTEGER NOT NULL,
        FOREIGN KEY (route_id) REFERENCES air_route (id) ON DELETE CASCADE
      )
    ''');

    // Table CollisionAlert
    await db.execute('''
      CREATE TABLE collision_alert (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        flight_a TEXT NOT NULL,
        flight_b TEXT NOT NULL,
        horizontal_distance REAL NOT NULL,
        vertical_distance REAL NOT NULL,
        detected_at TEXT NOT NULL,
        FOREIGN KEY (flight_a) REFERENCES flight (flight_number),
        FOREIGN KEY (flight_b) REFERENCES flight (flight_number)
      )
    ''');

    // TRIGGERS

    // Trigger pour empêcher la suppression d'un aircraft utilisé par un vol actif
    await db.execute('''
      CREATE TRIGGER prevent_aircraft_delete
      BEFORE DELETE ON aircraft
      BEGIN
        SELECT CASE
          WHEN EXISTS (
            SELECT 1 FROM flight 
            WHERE aircraft = OLD.registration 
            AND status IN ('In Flight', 'En Route', 'Boarding')
          )
          THEN RAISE(ABORT, 'Cannot delete aircraft with active flights')
        END;
      END;
    ''');

    // Trigger pour empêcher la suppression d'un airport utilisé par des vols ou routes
    await db.execute('''
      CREATE TRIGGER prevent_airport_delete
      BEFORE DELETE ON airport
      BEGIN
        SELECT CASE
          WHEN EXISTS (
            SELECT 1 FROM flight 
            WHERE (origin = OLD.oaci OR destination = OLD.oaci)
            AND status IN ('In Flight', 'En Route', 'Boarding')
          )
          THEN RAISE(ABORT, 'Cannot delete airport with active flights')
          WHEN EXISTS (
            SELECT 1 FROM air_route 
            WHERE origin = OLD.oaci OR destination = OLD.oaci
          )
          THEN RAISE(ABORT, 'Cannot delete airport with associated routes')
        END;
      END;
    ''');

    // Trigger pour supprimer automatiquement les positions anciennes (> 24h)
    await db.execute('''
      CREATE TRIGGER auto_delete_old_positions
      AFTER INSERT ON position
      BEGIN
        DELETE FROM position 
        WHERE datetime(timestamp) < datetime('now', '-1 day');
      END;
    ''');

    // Trigger pour mettre à jour automatiquement le timestamp
    await db.execute('''
      CREATE TRIGGER update_collision_timestamp
      AFTER INSERT ON collision_alert
      BEGIN
        UPDATE collision_alert 
        SET detected_at = datetime('now')
        WHERE id = NEW.id;
      END;
    ''');

    // Index pour améliorer les performances
    await db.execute('CREATE INDEX idx_flight_status ON flight(status)');
    await db.execute('CREATE INDEX idx_position_flight ON position(flight_number)');
    await db.execute('CREATE INDEX idx_position_timestamp ON position(timestamp)');
    await db.execute('CREATE INDEX idx_airport_country ON airport(country)');
    await db.execute('CREATE INDEX idx_airport_city ON airport(city)');

    // Initialisation avec des données standard
    await _insertDefaultData(db);
  }

  Future<void> _insertDefaultAirports(Database db) async {
    // Ne plus insérer d'aéroports par défaut dans la base de données
    // Les aéroports seront lus depuis le JSON
    print('Les aéroports seront chargés depuis le fichier JSON');
  }

  Future<void> _insertDefaultData(Database db) async {
    // Airports par défaut
    await _insertDefaultAirports(db);

    // Aircrafts par défaut
    final defaultAircrafts = [
      {'registration': 'F-GSPY', 'model': 'A320', 'cruise_speed': 450.0, 'max_altitude': 39000.0},
      {'registration': 'F-HBNA', 'model': 'B737', 'cruise_speed': 460.0, 'max_altitude': 41000.0},
      {'registration': 'F-GTAD', 'model': 'B738', 'cruise_speed': 455.0, 'max_altitude': 41000.0},
      {'registration': 'F-HEPB', 'model': 'A321', 'cruise_speed': 470.0, 'max_altitude': 39000.0},
      {'registration': 'F-GKXS', 'model': 'A319', 'cruise_speed': 440.0, 'max_altitude': 39000.0},
    ];

    for (var aircraft in defaultAircrafts) {
      await db.insert('aircraft', aircraft);
    }

    // Flights par défaut (avec codes OACI)
    final defaultFlights = [
      {
        'flight_number': 'AF102',
        'aircraft': 'F-GSPY',
        'origin': 'LFPG',
        'destination': 'KJFK',
        'status': 'In Flight',
        'dep_time': '09:20',
        'arr_time': '12:15'
      },
      {
        'flight_number': 'DL305',
        'aircraft': 'F-HBNA',
        'origin': 'KATL',
        'destination': 'KLAX',
        'status': 'Delayed',
        'dep_time': '08:45',
        'arr_time': '11:30'
      },
      {
        'flight_number': 'FR742',
        'aircraft': 'F-GTAD',
        'origin': 'EGLL',
        'destination': 'LEMD',
        'status': 'En Route',
        'dep_time': '10:00',
        'arr_time': '13:00'
      },
      {
        'flight_number': 'BA456',
        'aircraft': 'F-HEPB',
        'origin': 'EGLL',
        'destination': 'LFPG',
        'status': 'Boarding',
        'dep_time': '14:30',
        'arr_time': '16:45'
      },
      {
        'flight_number': 'LH789',
        'aircraft': 'F-GKXS',
        'origin': 'EDDF',
        'destination': 'LEBL',
        'status': 'On Ground',
        'dep_time': '11:15',
        'arr_time': '13:20'
      },
    ];

    for (var flight in defaultFlights) {
      await db.insert('flight', flight);
    }

    // Positions par défaut pour les vols actifs
    final defaultPositions = [
      {
        'flight_number': 'AF102',
        'latitude': 48.8566,
        'longitude': 2.3522,
        'altitude': 35000.0,
        'heading': 270.0,
        'timestamp': DateTime.now().toIso8601String()
      },
      {
        'flight_number': 'FR742',
        'latitude': 51.5074,
        'longitude': -0.1278,
        'altitude': 37000.0,
        'heading': 180.0,
        'timestamp': DateTime.now().toIso8601String()
      },
    ];

    for (var position in defaultPositions) {
      await db.insert('position', position);
    }

    // Routes aériennes par défaut (avec codes OACI)
    final defaultRoutes = [
      {'id': 'ROUTE_LFPG_KJFK', 'origin': 'LFPG', 'destination': 'KJFK'},
      {'id': 'ROUTE_EGLL_LEMD', 'origin': 'EGLL', 'destination': 'LEMD'},
      {'id': 'ROUTE_KATL_KLAX', 'origin': 'KATL', 'destination': 'KLAX'},
    ];

    for (var route in defaultRoutes) {
      await db.insert('air_route', route);
    }

    // Waypoints pour les routes
    final defaultWaypoints = [
      // Route LFPG -> KJFK
      {'route_id': 'ROUTE_LFPG_KJFK', 'latitude': 48.8566, 'longitude': 2.3522, 'sequence_order': 0},
      {'route_id': 'ROUTE_LFPG_KJFK', 'latitude': 50.0, 'longitude': -10.0, 'sequence_order': 1},
      {'route_id': 'ROUTE_LFPG_KJFK', 'latitude': 45.0, 'longitude': -40.0, 'sequence_order': 2},
      {'route_id': 'ROUTE_LFPG_KJFK', 'latitude': 40.7128, 'longitude': -74.0060, 'sequence_order': 3},
      
      // Route EGLL -> LEMD
      {'route_id': 'ROUTE_EGLL_LEMD', 'latitude': 51.5074, 'longitude': -0.1278, 'sequence_order': 0},
      {'route_id': 'ROUTE_EGLL_LEMD', 'latitude': 48.0, 'longitude': -2.0, 'sequence_order': 1},
      {'route_id': 'ROUTE_EGLL_LEMD', 'latitude': 40.4168, 'longitude': -3.7038, 'sequence_order': 2},
    ];

    for (var waypoint in defaultWaypoints) {
      await db.insert('waypoint', waypoint);
    }
  }

  // ==================== CRUD AIRPORT (depuis JSON) ====================

  // Ces méthodes ne modifient plus la base de données
  // Elles lisent directement depuis le fichier JSON

  Future<int> insertAirport(Airport airport) async {
    // Les aéroports ne peuvent pas être ajoutés (JSON statique)
    throw UnsupportedError('Les aéroports sont en lecture seule depuis le JSON');
  }

  Future<List<Airport>> getAllAirports() async {
    await _loadAirportsFromJson();
    return List.from(_airportsCache ?? []);
  }

  Future<Airport?> getAirport(String oaci) async {
    await _loadAirportsFromJson();
    return _airportsByOaciCache?[oaci];
  }

  Future<List<Airport>> getAirportsByCountry(String country) async {
    await _loadAirportsFromJson();
    return _airportsCache!
        .where((airport) => airport.country.toLowerCase().contains(country.toLowerCase()))
        .toList();
  }

  Future<List<Airport>> searchAirports(String query) async {
    await _loadAirportsFromJson();
    final queryLower = query.toLowerCase();
    return _airportsCache!
        .where((airport) =>
            airport.name.toLowerCase().contains(queryLower) ||
            airport.city.toLowerCase().contains(queryLower) ||
            airport.country.toLowerCase().contains(queryLower) ||
            airport.oaci.toLowerCase().contains(queryLower))
        .toList();
  }

  Future<int> updateAirport(Airport airport) async {
    // Les aéroports ne peuvent pas être modifiés (JSON statique)
    throw UnsupportedError('Les aéroports sont en lecture seule depuis le JSON');
  }

  Future<int> deleteAirport(String oaci) async {
    // Les aéroports ne peuvent pas être supprimés (JSON statique)
    throw UnsupportedError('Les aéroports sont en lecture seule depuis le JSON');
  }

  // ==================== CRUD AIRCRAFT ====================

  Future<int> insertAircraft(Aircraft aircraft) async {
    final db = await database;
    return await db.insert('aircraft', {
      'registration': aircraft.registration,
      'model': aircraft.model,
      'cruise_speed': aircraft.cruiseSpeed,
      'max_altitude': aircraft.maxAltitude,
    });
  }

  Future<List<Aircraft>> getAllAircrafts() async {
    final db = await database;
    final result = await db.query('aircraft');
    return result.map((map) => Aircraft(
      registration: map['registration'] as String,
      model: map['model'] as String,
      cruiseSpeed: map['cruise_speed'] as double,
      maxAltitude: map['max_altitude'] as double,
    )).toList();
  }

  Future<Aircraft?> getAircraft(String registration) async {
    final db = await database;
    final result = await db.query(
      'aircraft',
      where: 'registration = ?',
      whereArgs: [registration],
    );
    if (result.isEmpty) return null;
    final map = result.first;
    return Aircraft(
      registration: map['registration'] as String,
      model: map['model'] as String,
      cruiseSpeed: map['cruise_speed'] as double,
      maxAltitude: map['max_altitude'] as double,
    );
  }

  Future<int> updateAircraft(Aircraft aircraft) async {
    final db = await database;
    return await db.update(
      'aircraft',
      {
        'model': aircraft.model,
        'cruise_speed': aircraft.cruiseSpeed,
        'max_altitude': aircraft.maxAltitude,
      },
      where: 'registration = ?',
      whereArgs: [aircraft.registration],
    );
  }

  Future<int> deleteAircraft(String registration) async {
    final db = await database;
    return await db.delete(
      'aircraft',
      where: 'registration = ?',
      whereArgs: [registration],
    );
  }

  // ==================== CRUD FLIGHT ====================

  Future<int> insertFlight(Flight flight) async {
    final db = await database;
    return await db.insert('flight', {
      'flight_number': flight.flightNumber,
      'aircraft': flight.aircraft,
      'origin': flight.from,
      'destination': flight.to,
      'status': flight.status,
      'dep_time': flight.depTime,
      'arr_time': flight.arrTime,
    });
  }

  Future<List<Flight>> getAllFlights() async {
    final db = await database;
    final result = await db.query('flight');
    return result.map((map) => Flight(
      flightNumber: map['flight_number'] as String,
      aircraft: map['aircraft'] as String,
      from: map['origin'] as String,
      to: map['destination'] as String,
      status: map['status'] as String,
      depTime: map['dep_time'] as String,
      arrTime: map['arr_time'] as String,
    )).toList();
  }

  Future<Flight?> getFlight(String flightNumber) async {
    final db = await database;
    final result = await db.query(
      'flight',
      where: 'flight_number = ?',
      whereArgs: [flightNumber],
    );
    if (result.isEmpty) return null;
    final map = result.first;
    return Flight(
      flightNumber: map['flight_number'] as String,
      aircraft: map['aircraft'] as String,
      from: map['origin'] as String,
      to: map['destination'] as String,
      status: map['status'] as String,
      depTime: map['dep_time'] as String,
      arrTime: map['arr_time'] as String,
    );
  }

  Future<List<Flight>> getFlightsByStatus(String status) async {
    final db = await database;
    final result = await db.query(
      'flight',
      where: 'status = ?',
      whereArgs: [status],
    );
    return result.map((map) => Flight(
      flightNumber: map['flight_number'] as String,
      aircraft: map['aircraft'] as String,
      from: map['origin'] as String,
      to: map['destination'] as String,
      status: map['status'] as String,
      depTime: map['dep_time'] as String,
      arrTime: map['arr_time'] as String,
    )).toList();
  }

  Future<List<Flight>> getFlightsByAirport(String oaci) async {
    final db = await database;
    final result = await db.query(
      'flight',
      where: 'origin = ? OR destination = ?',
      whereArgs: [oaci, oaci],
    );
    return result.map((map) => Flight(
      flightNumber: map['flight_number'] as String,
      aircraft: map['aircraft'] as String,
      from: map['origin'] as String,
      to: map['destination'] as String,
      status: map['status'] as String,
      depTime: map['dep_time'] as String,
      arrTime: map['arr_time'] as String,
    )).toList();
  }

  Future<int> updateFlight(Flight flight) async {
    final db = await database;
    return await db.update(
      'flight',
      {
        'aircraft': flight.aircraft,
        'origin': flight.from,
        'destination': flight.to,
        'status': flight.status,
        'dep_time': flight.depTime,
        'arr_time': flight.arrTime,
      },
      where: 'flight_number = ?',
      whereArgs: [flight.flightNumber],
    );
  }

  Future<int> updateFlightStatus(String flightNumber, String newStatus) async {
    final db = await database;
    return await db.update(
      'flight',
      {'status': newStatus},
      where: 'flight_number = ?',
      whereArgs: [flightNumber],
    );
  }

  Future<int> deleteFlight(String flightNumber) async {
    final db = await database;
    return await db.delete(
      'flight',
      where: 'flight_number = ?',
      whereArgs: [flightNumber],
    );
  }

  // ==================== CRUD POSITION ====================

  Future<int> insertPosition(String flightNumber, Position position) async {
    final db = await database;
    return await db.insert('position', {
      'flight_number': flightNumber,
      'latitude': position.latLng.latitude,
      'longitude': position.latLng.longitude,
      'altitude': position.altitude,
      'heading': position.heading,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Position>> getFlightPositions(String flightNumber) async {
    final db = await database;
    final result = await db.query(
      'position',
      where: 'flight_number = ?',
      whereArgs: [flightNumber],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => Position(
      latLng: LatLng(
        map['latitude'] as double,
        map['longitude'] as double,
      ),
      altitude: map['altitude'] as double,
      heading: map['heading'] as double,
    )).toList();
  }

  Future<Position?> getLatestPosition(String flightNumber) async {
    final db = await database;
    final result = await db.query(
      'position',
      where: 'flight_number = ?',
      whereArgs: [flightNumber],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    final map = result.first;
    return Position(
      latLng: LatLng(
        map['latitude'] as double,
        map['longitude'] as double,
      ),
      altitude: map['altitude'] as double,
      heading: map['heading'] as double,
    );
  }

  Future<int> deleteFlightPositions(String flightNumber) async {
    final db = await database;
    return await db.delete(
      'position',
      where: 'flight_number = ?',
      whereArgs: [flightNumber],
    );
  }

  // ==================== CRUD AIR ROUTE ====================

  Future<int> insertAirRoute(AirRoute route) async {
    final db = await database;
    
    // Insert route
    await db.insert('air_route', {
      'id': route.id,
      'origin': route.from,
      'destination': route.to,
    });

    // Insert waypoints
    for (int i = 0; i < route.waypoints.length; i++) {
      await db.insert('waypoint', {
        'route_id': route.id,
        'latitude': route.waypoints[i].latitude,
        'longitude': route.waypoints[i].longitude,
        'sequence_order': i,
      });
    }
    
    return 1;
  }

  Future<List<AirRoute>> getAllAirRoutes() async {
    final db = await database;
    final routes = await db.query('air_route');
    
    List<AirRoute> airRoutes = [];
    for (var routeMap in routes) {
      final waypoints = await db.query(
        'waypoint',
        where: 'route_id = ?',
        whereArgs: [routeMap['id']],
        orderBy: 'sequence_order ASC',
      );
      
      airRoutes.add(AirRoute(
        id: routeMap['id'] as String,
        from: routeMap['origin'] as String,
        to: routeMap['destination'] as String,
        waypoints: waypoints.map((w) => LatLng(
          w['latitude'] as double,
          w['longitude'] as double,
        )).toList(),
      ));
    }
    
    return airRoutes;
  }

  Future<AirRoute?> getAirRoute(String routeId) async {
    final db = await database;
    final result = await db.query(
      'air_route',
      where: 'id = ?',
      whereArgs: [routeId],
    );
    
    if (result.isEmpty) return null;
    
    final routeMap = result.first;
    final waypoints = await db.query(
      'waypoint',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'sequence_order ASC',
    );
    
    return AirRoute(
      id: routeMap['id'] as String,
      from: routeMap['origin'] as String,
      to: routeMap['destination'] as String,
      waypoints: waypoints.map((w) => LatLng(
        w['latitude'] as double,
        w['longitude'] as double,
      )).toList(),
    );
  }

  Future<int> deleteAirRoute(String routeId) async {
    final db = await database;
    // Les waypoints seront supprimés automatiquement grâce au ON DELETE CASCADE
    return await db.delete(
      'air_route',
      where: 'id = ?',
      whereArgs: [routeId],
    );
  }

  // ==================== CRUD COLLISION ALERT ====================

  Future<int> insertCollisionAlert(CollisionAlert alert) async {
    final db = await database;
    return await db.insert('collision_alert', {
      'flight_a': alert.flightA.flightNumber,
      'flight_b': alert.flightB.flightNumber,
      'horizontal_distance': alert.horizontalDistance,
      'vertical_distance': alert.verticalDistance,
      'detected_at': alert.detectedAt.toIso8601String(),
    });
  }

  Future<List<CollisionAlert>> getAllCollisionAlerts() async {
    final db = await database;
    final result = await db.query('collision_alert', orderBy: 'detected_at DESC');
    
    List<CollisionAlert> alerts = [];
    for (var map in result) {
      final flightA = await getFlight(map['flight_a'] as String);
      final flightB = await getFlight(map['flight_b'] as String);
      
      if (flightA != null && flightB != null) {
        alerts.add(CollisionAlert(
          flightA: flightA,
          flightB: flightB,
          horizontalDistance: map['horizontal_distance'] as double,
          verticalDistance: map['vertical_distance'] as double,
          detectedAt: DateTime.parse(map['detected_at'] as String),
        ));
      }
    }
    
    return alerts;
  }

  Future<int> deleteCollisionAlert(int id) async {
    final db = await database;
    return await db.delete(
      'collision_alert',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteOldCollisionAlerts(Duration duration) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(duration);
    return await db.delete(
      'collision_alert',
      where: 'datetime(detected_at) < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  // ==================== STATISTIQUES ====================

  Future<Map<String, int>> getFlightStatistics() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT status, COUNT(*) as count
      FROM flight
      GROUP BY status
    ''');
    
    Map<String, int> stats = {};
    for (var row in result) {
      stats[row['status'] as String] = row['count'] as int;
    }
    
    return stats;
  }

  Future<int> getTotalAircrafts() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM aircraft');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalAirports() async {
    await _loadAirportsFromJson();
    return _airportsCache?.length ?? 0;
  }

  Future<int> getActiveFlights() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM flight
      WHERE status IN ('In Flight', 'En Route')
    ''');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, int>> getAirportsByCountryCount() async {
    await _loadAirportsFromJson();
    
    Map<String, int> stats = {};
    for (var airport in _airportsCache ?? []) {
      stats[airport.country] = (stats[airport.country] ?? 0) + 1;
    }
    
    // Trier par nombre décroissant
    final sortedEntries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Map.fromEntries(sortedEntries);
  }

  // ==================== UTILITAIRES ====================

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('collision_alert');
    await db.delete('waypoint');
    await db.delete('air_route');
    await db.delete('position');
    await db.delete('flight');
    await db.delete('aircraft');
    // Ne pas supprimer les aéroports car ils viennent du JSON
  }

  Future<void> resetDatabase() async {
    await clearAllData();
  }

  // Recharger le cache des aéroports
  Future<void> reloadAirports() async {
    _airportsCache = null;
    _airportsByOaciCache = null;
    await _loadAirportsFromJson();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
