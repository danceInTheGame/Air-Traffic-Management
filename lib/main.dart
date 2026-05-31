import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'src/app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'src/features/dashboard/data/mock_data.dart';
import 'src/features/dashboard/services/collision_detection_service.dart';
import 'src/core/test/collision_test_setup.dart'; // Import du fichier de test


const bool ENABLE_COLLISION_TEST = false; // Mettre à true pour activer le scénario de test

void main() async {
  // Assurer l'initialisation des bindings Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser sqflite pour desktop uniquement 
  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }
  
  runApp(const AppInitializer());
}

/// Widget qui gère l'initialisation de la base de données
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    // Nettoyer le polling lors de la fermeture de l'app
    MockData.dispose();
    CollisionDetectionService.instance.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialiser la base de données et démarrer le polling automatique
      await MockData.initialize();
      debugPrint(' Base de données initialisée avec succès');
      debugPrint(' Polling automatique démarré (interval: 1s)');
      debugPrint(' Vols chargés: ${MockData.flights.length}');
      
      // Attendre que la base soit complètement prête
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 🧪 CRÉER LE SCÉNARIO DE TEST SI ACTIVÉ
      if (ENABLE_COLLISION_TEST) {
        debugPrint('\n Mode test activé (ENABLE_COLLISION_TEST = true)');
        try {
          await CollisionTestSetup.setupCollisionScenario();
          
          // Vérifier que le scénario est bien actif
          final isActive = await CollisionTestSetup.verifyScenario();
          if (isActive) {
            debugPrint(' Scénario de test vérifié et actif');
          } else {
            debugPrint('  ATTENTION: Le scénario n\'est pas complètement actif');
          }
        } catch (e) {
          debugPrint(' Erreur création scénario de test: $e');
        }
      } else {
        debugPrint('\n Mode normal (ENABLE_COLLISION_TEST = false)');
      }
      
      // Démarrer la détection de collision
      CollisionDetectionService.instance.startDetection(
        interval: const Duration(seconds: 5),
      );
      debugPrint(' Détection de collision démarrée (interval: 5s)');
      
      // Si mode test, forcer une première détection immédiate
      if (ENABLE_COLLISION_TEST) {
        debugPrint('\n Lancement d\'une détection immédiate...');
        await Future.delayed(const Duration(seconds: 2));
        await CollisionDetectionService.instance.detectPotentialCollisions();
      }
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint(' Erreur lors de l\'initialisation: $e');
      setState(() {
        _errorMessage = e.toString();
        _isInitialized = true; // On continue quand même
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Écran de chargement pendant l'initialisation
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0A0E27),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF00D4FF),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Initialisation de la base de données...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Démarrage du système de surveillance',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Activation de la détection de collision',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white38,
                  ),
                ),
                if (ENABLE_COLLISION_TEST) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Text(
                      '🧪 MODE TEST COLLISION ACTIVÉ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Afficher un message d'erreur si nécessaire
    if (_errorMessage.isNotEmpty) {
      debugPrint(' L\'application démarre avec des erreurs: $_errorMessage');
    }

    // Lancer l'application principale
    return const MyApp();
  }
}