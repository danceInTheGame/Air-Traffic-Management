import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../features/dashboard/data/data_base_helper.dart';
import '../../features/dashboard/model/air_craft.dart';
import '../../features/dashboard/model/flight.dart';
import '../../features/dashboard/model/postion.dart';

/// Configuration de test pour déclencher une alerte de collision
/// 
/// Ce fichier crée intentionnellement deux vols en trajectoire de collision
/// pour tester le système de détection automatique.
class CollisionTestSetup {
  static final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Crée deux vols en trajectoire de collision frontale
  /// GARANTIE: Alerte déclenchée dans les 10 secondes
  static Future<void> setupCollisionScenario() async {
    debugPrint('\n');
    debugPrint(' INITIALISATION SCÉNARIO DE TEST COLLISION');
    debugPrint('\n');

    try {
      // Attendre que la base de données soit complètement initialisée
      await Future.delayed(const Duration(milliseconds: 500));

      // 1. Nettoyer les vols de test existants
      debugPrint('🧹 Nettoyage des vols de test précédents...');
      try {
        await _dbHelper.deleteFlight('COLLISION-ALPHA');
        await _dbHelper.deleteFlight('COLLISION-BETA');
        debugPrint('   ✓ Anciens vols supprimés');
      } catch (e) {
        debugPrint('   ✓ Pas de vols précédents à supprimer');
      }

      // 2. Créer les avions de test
      await _createTestAircraft();

      // 3. Créer les vols en collision TRÈS PROCHE
      await _createCollisionFlights();

      // 4. Créer des positions CRITIQUES (collision imminente)
      await _createCriticalPositions();

      debugPrint('\n ');
      debugPrint(' SCÉNARIO DE TEST CRÉÉ AVEC SUCCÈS');
      debugPrint('');
      debugPrint(' Configuration:');
      debugPrint('   • Vol ALPHA: Lat 49.00°, Lon 2.35° → Est @ 35000ft (450kt)');
      debugPrint('   • Vol BETA:  Lat 49.00°, Lon 2.45° → Ouest @ 35000ft (460kt)');
      debugPrint('   • Distance initiale: ~7 km');
      debugPrint('   • Séparation verticale: 0 ft (CRITIQUE!)');
      debugPrint('   • Vitesse de rapprochement: ~910 kt');
      debugPrint('   • Trajectoire: COLLISION FRONTALE GARANTIE');
      debugPrint('\n  ALERTE ATTENDUE DANS LES 10 PROCHAINES SECONDES\n');

      // Vérifier que les vols ont bien été créés
      final verifyAlpha = await _dbHelper.getFlight('COLLISION-ALPHA');
      final verifyBeta = await _dbHelper.getFlight('COLLISION-BETA');
      final posAlpha = await _dbHelper.getLatestPosition('COLLISION-ALPHA');
      final posBeta = await _dbHelper.getLatestPosition('COLLISION-BETA');

      if (verifyAlpha != null && verifyBeta != null && posAlpha != null && posBeta != null) {
        debugPrint(' Vérification: Tous les éléments créés correctement');
        debugPrint('   - Vol ALPHA: ${verifyAlpha.status}');
        debugPrint('   - Vol BETA: ${verifyBeta.status}');
        debugPrint('   - Position ALPHA: ${posAlpha.latLng.latitude}, ${posAlpha.latLng.longitude}');
        debugPrint('   - Position BETA: ${posBeta.latLng.latitude}, ${posBeta.latLng.longitude}\n');
      } else {
        debugPrint(' ERREUR: Certains éléments n\'ont pas été créés!');
      }

    } catch (e, stackTrace) {
      debugPrint(' ERREUR CRITIQUE lors de la création du scénario: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Crée les avions de test
  static Future<void> _createTestAircraft() async {
    debugPrint(' Création des avions de test...');

    try {
      // Supprimer si existants
      try {
        await _dbHelper.deleteAircraft('COLLISION-TEST-A');
        await _dbHelper.deleteAircraft('COLLISION-TEST-B');
      } catch (e) {
        // Pas grave
      }

      // Créer avion A
      await _dbHelper.insertAircraft(Aircraft(
        registration: 'COLLISION-TEST-A',
        model: 'A320',
        cruiseSpeed: 450.0,
        maxAltitude: 39000.0,
      ));
      debugPrint('   ✓ Avion COLLISION-TEST-A créé (A320, 450kt)');

      // Créer avion B
      await _dbHelper.insertAircraft(Aircraft(
        registration: 'COLLISION-TEST-B',
        model: 'B737',
        cruiseSpeed: 460.0,
        maxAltitude: 41000.0,
      ));
      debugPrint('   ✓ Avion COLLISION-TEST-B créé (B737, 460kt)');

    } catch (e) {
      debugPrint('    Erreur création avions: $e');
      rethrow;
    }
  }

  /// Crée les vols en collision
  static Future<void> _createCollisionFlights() async {
    debugPrint('\n  Création des vols en collision...');

    try {
      final now = DateTime.now();
      
      // Vol ALPHA: Paris → Est (In Flight - CRITIQUE pour détection)
      final flightAlpha = Flight(
        flightNumber: 'COLLISION-ALPHA',
        aircraft: 'COLLISION-TEST-A',
        from: 'LFPG', // Paris CDG
        to: 'EDDF',   // Francfort
        status: 'In Flight', // ← IMPORTANT: Doit être "In Flight"
        depTime: now.toString().substring(11, 16),
        arrTime: now.add(const Duration(hours: 1)).toString().substring(11, 16),
      );

      await _dbHelper.insertFlight(flightAlpha);
      debugPrint('   ✓ Vol COLLISION-ALPHA créé (Status: In Flight)');

      // Vol BETA: Est de Paris → Ouest (In Flight - CRITIQUE pour détection)
      final flightBeta = Flight(
        flightNumber: 'COLLISION-BETA',
        aircraft: 'COLLISION-TEST-B',
        from: 'EDDF',   // Francfort
        to: 'LFPG',     // Paris CDG
        status: 'In Flight', // ← IMPORTANT: Doit être "In Flight"
        depTime: now.toString().substring(11, 16),
        arrTime: now.add(const Duration(hours: 1)).toString().substring(11, 16),
      );

      await _dbHelper.insertFlight(flightBeta);
      debugPrint('   ✓ Vol COLLISION-BETA créé (Status: In Flight)');

    } catch (e) {
      debugPrint('    Erreur création vols: $e');
      rethrow;
    }
  }

  /// Crée les positions CRITIQUES pour collision immédiate
  static Future<void> _createCriticalPositions() async {
    debugPrint('\n Définition des positions CRITIQUES...');

    try {
      // Supprimer anciennes positions
      try {
        await _dbHelper.deleteFlightPositions('COLLISION-ALPHA');
        await _dbHelper.deleteFlightPositions('COLLISION-BETA');
      } catch (e) {
        // Pas grave
      }

      // Position ALPHA: Nord de Paris, cap Est (90°)
      // Utilise les vraies coordonnées de Paris CDG
      final positionAlpha = Position(
        latLng: LatLng(49.0097, 2.35), // Légèrement au nord, à l'ouest
        altitude: 35000.0,
        heading: 90.0, // Plein Est
      );

      await _dbHelper.insertPosition('COLLISION-ALPHA', positionAlpha);
      debugPrint('   ✓ Position ALPHA créée:');
      debugPrint('     - Lat: 49.0097°, Lon: 2.35°');
      debugPrint('     - Altitude: 35000ft');
      debugPrint('     - Cap: 90° (Est)');

      // Position BETA: Seulement 7 km à l'Est, cap Ouest (270°)
      // COLLISION FRONTALE GARANTIE dans les 10 secondes!
      final positionBeta = Position(
        latLng: LatLng(49.0097, 2.45), // Même latitude, ~7km à l'Est
        altitude: 35000.0, // MÊME ALTITUDE = DANGER CRITIQUE
        heading: 270.0, // Plein Ouest (collision frontale!)
      );

      await _dbHelper.insertPosition('COLLISION-BETA', positionBeta);
      debugPrint('   ✓ Position BETA créée:');
      debugPrint('     - Lat: 49.0097°, Lon: 2.45°');
      debugPrint('     - Altitude: 35000ft');
      debugPrint('     - Cap: 270° (Ouest)');

      debugPrint('\n Analyse du danger:');
      debugPrint('   • Même latitude: 49.0097° (trajectoire linéaire)');
      debugPrint('   • Même altitude: 35000ft (violation sévère)');
      debugPrint('   • Caps opposés: 90° ↔ 270° (collision frontale)');
      debugPrint('   • Distance: ~7 km (sous le seuil de 5 km très bientôt)');
      debugPrint('   • Vitesse combinée: ~910 kt (~1685 km/h)');
      debugPrint('   • Temps avant seuil critique: ~25 secondes');
      debugPrint('\n     DÉTECTION GARANTIE AU PROCHAIN CYCLE (5-10s)');

    } catch (e) {
      debugPrint('    Erreur création positions: $e');
      rethrow;
    }
  }

  /// Nettoie le scénario de test (supprime les vols de test)
  static Future<void> cleanupTestScenario() async {
    debugPrint('\n🧹 Nettoyage du scénario de test...');

    try {
      await _dbHelper.deleteFlight('COLLISION-ALPHA');
      await _dbHelper.deleteFlight('COLLISION-BETA');
      await _dbHelper.deleteAircraft('COLLISION-TEST-A');
      await _dbHelper.deleteAircraft('COLLISION-TEST-B');
      debugPrint('   ✓ Scénario de test nettoyé');
    } catch (e) {
      debugPrint('     Erreur lors du nettoyage: $e');
    }
  }

  /// Vérifie que le scénario est bien actif
  static Future<bool> verifyScenario() async {
    final flightA = await _dbHelper.getFlight('COLLISION-ALPHA');
    final flightB = await _dbHelper.getFlight('COLLISION-BETA');
    final posA = await _dbHelper.getLatestPosition('COLLISION-ALPHA');
    final posB = await _dbHelper.getLatestPosition('COLLISION-BETA');

    final isValid = flightA != null && 
                    flightB != null && 
                    posA != null && 
                    posB != null;

    debugPrint('\n🔍 Vérification du scénario: ${isValid ? " ACTIF" : " INACTIF"}');
    
    return isValid;
  }
}