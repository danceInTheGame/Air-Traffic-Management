import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../model/flight.dart';
import '../model/postion.dart';
import '../model/collision_alert.dart';
import '../data/data_base_helper.dart';
import '../../../core/utils/move_algo.dart';

class CollisionDetectionService {
  static final CollisionDetectionService instance = CollisionDetectionService._init();
  
  CollisionDetectionService._init();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // Paramètres de détection
  static const double _horizontalSafetyDistance = 5000.0; // 5 km en mètres
  static const double _verticalSafetyDistance = 1000.0; // 1000 pieds
  static const double _lookAheadTimeSeconds = 120.0; // 2 minutes dans le futur
  static const int _predictionSteps = 12; // 12 points de prédiction (10s chacun)
  
  // Notifier pour les nouvelles alertes
  final ValueNotifier<CollisionAlert?> newAlertNotifier = ValueNotifier<CollisionAlert?>(null);
  
  Timer? _detectionTimer;
  bool _isDetecting = false;

  /// Démarrer la détection automatique
  void startDetection({Duration interval = const Duration(seconds: 5)}) {
    if (_detectionTimer != null) return;

    _detectionTimer = Timer.periodic(interval, (_) async {
      if (_isDetecting) return;
      await detectPotentialCollisions();
    });
    
    debugPrint('🔍 Détection de collision démarrée (interval: ${interval.inSeconds}s)');
  }

  /// Arrêter la détection automatique
  void stopDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
    debugPrint('⏹️ Détection de collision arrêtée');
  }

  /// Détecter toutes les collisions potentielles
  Future<void> detectPotentialCollisions() async {
    _isDetecting = true;
    try {
      // Récupérer tous les vols actifs
      final flights = await _dbHelper.getFlightsByStatus('In Flight');
      final enRouteFlights = await _dbHelper.getFlightsByStatus('En Route');
      final activeFlights = [...flights, ...enRouteFlights];

      if (activeFlights.length < 2) {
        _isDetecting = false;
        return;
      }

      // Récupérer les positions actuelles de tous les vols
      Map<String, Position?> currentPositions = {};
      Map<String, double> aircraftSpeeds = {};

      for (var flight in activeFlights) {
        final position = await _dbHelper.getLatestPosition(flight.flightNumber);
        if (position != null) {
          currentPositions[flight.flightNumber] = position;
          
          // Récupérer la vitesse de croisière de l'avion
          final aircraft = await _dbHelper.getAircraft(flight.aircraft);
          aircraftSpeeds[flight.flightNumber] = aircraft?.cruiseSpeed ?? 450.0;
        }
      }

      // Comparer chaque paire de vols
      for (int i = 0; i < activeFlights.length; i++) {
        for (int j = i + 1; j < activeFlights.length; j++) {
          final flightA = activeFlights[i];
          final flightB = activeFlights[j];

          final posA = currentPositions[flightA.flightNumber];
          final posB = currentPositions[flightB.flightNumber];

          if (posA == null || posB == null) continue;

          final speedA = aircraftSpeeds[flightA.flightNumber] ?? 450.0;
          final speedB = aircraftSpeeds[flightB.flightNumber] ?? 450.0;

          // Vérifier collision potentielle
          final collision = await _checkCollisionRisk(
            flightA: flightA,
            flightB: flightB,
            positionA: posA,
            positionB: posB,
            speedA: speedA,
            speedB: speedB,
          );

          if (collision != null) {
            // Sauvegarder l'alerte
            await _dbHelper.insertCollisionAlert(collision);
            
            // Notifier l'interface
            newAlertNotifier.value = collision;
            
            debugPrint('⚠️ COLLISION DÉTECTÉE: ${flightA.flightNumber} ↔ ${flightB.flightNumber}');
            debugPrint('   Distance horizontale: ${collision.horizontalDistance.toStringAsFixed(0)}m');
            debugPrint('   Distance verticale: ${collision.verticalDistance.toStringAsFixed(0)}ft');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur détection collision: $e');
    } finally {
      _isDetecting = false;
    }
  }

  /// Vérifier le risque de collision entre deux vols
  Future<CollisionAlert?> _checkCollisionRisk({
    required Flight flightA,
    required Flight flightB,
    required Position positionA,
    required Position positionB,
    required double speedA,
    required double speedB,
  }) async {
    double minHorizontalDistance = double.infinity;
    double minVerticalDistance = double.infinity;
    bool collisionDetected = false;

    // Prédire les positions futures
    final deltaTime = _lookAheadTimeSeconds / _predictionSteps;

    Position currentA = positionA;
    Position currentB = positionB;

    for (int step = 0; step <= _predictionSteps; step++) {
      // Calculer distances
      final horizontalDist = _calculateHorizontalDistance(
        currentA.latLng,
        currentB.latLng,
      );
      final verticalDist = (currentA.altitude - currentB.altitude).abs();

      // Mettre à jour les distances minimales
      if (horizontalDist < minHorizontalDistance) {
        minHorizontalDistance = horizontalDist;
      }
      if (verticalDist < minVerticalDistance) {
        minVerticalDistance = verticalDist;
      }

      // Vérifier si collision potentielle
      if (horizontalDist < _horizontalSafetyDistance && 
          verticalDist < _verticalSafetyDistance) {
        collisionDetected = true;
        break;
      }

      // Déplacer les avions pour le prochain pas de temps
      if (step < _predictionSteps) {
        currentA = moveAircraft(
          current: currentA,
          speedKt: speedA,
          deltaTimeSeconds: deltaTime,
        );
        currentB = moveAircraft(
          current: currentB,
          speedKt: speedB,
          deltaTimeSeconds: deltaTime,
        );
      }
    }

    // Si collision détectée, créer l'alerte
    if (collisionDetected) {
      return CollisionAlert(
        flightA: flightA,
        flightB: flightB,
        horizontalDistance: minHorizontalDistance,
        verticalDistance: minVerticalDistance,
        detectedAt: DateTime.now(),
      );
    }

    return null;
  }

  /// Calculer la distance horizontale entre deux points GPS (en mètres)
  double _calculateHorizontalDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371000.0; // mètres

    final lat1 = point1.latitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    final deltaLon = (point2.longitude - point1.longitude) * pi / 180;

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Résoudre une collision en modifiant l'altitude d'un vol
  Future<bool> resolveCollision({
    required String flightNumber,
    required double newAltitude,
  }) async {
    try {
      // Récupérer la position actuelle
      final currentPosition = await _dbHelper.getLatestPosition(flightNumber);
      if (currentPosition == null) return false;

      // Créer une nouvelle position avec l'altitude modifiée
      final newPosition = currentPosition.copyWith(altitude: newAltitude);

      // Sauvegarder la nouvelle position
      await _dbHelper.insertPosition(flightNumber, newPosition);

      debugPrint('✅ Altitude modifiée: $flightNumber → ${newAltitude}ft');
      return true;
    } catch (e) {
      debugPrint('❌ Erreur résolution collision: $e');
      return false;
    }
  }

  /// Obtenir une altitude de sécurité suggérée
  double getSuggestedAltitude(double currentAltitude, bool increaseAltitude) {
    // Suggestion: ±2000 pieds
    final adjustment = 2000.0;
    return increaseAltitude 
        ? currentAltitude + adjustment 
        : currentAltitude - adjustment;
  }

  void dispose() {
    stopDetection();
    newAlertNotifier.dispose();
  }
}