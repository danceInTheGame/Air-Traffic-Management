import 'dart:async';
import 'package:flutter/material.dart';
import 'package:atc_dashboard/src/features/dashboard/model/flight.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:atc_dashboard/src/features/dashboard/presentation/widgets/kpi_card.dart';
import 'package:atc_dashboard/src/core/theme/app_colors.dart';
import '../presentation/admin_login_page.dart';
import 'data_base_helper.dart';
import '../services/collision_detection_service.dart';

void navigateToAdminLogin(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const AdminLoginPage()),
  );
}

class MockData {
  static final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static final CollisionDetectionService _collisionService = CollisionDetectionService.instance;

  /* ===========================
   * CACHE
   * =========================== */
  static List<Flight> _cachedFlights = [];
  static Map<String, int> _cachedStats = {};
  static int _cachedActiveFlights = 0;
  static int _cachedAlerts = 0;

  static DateTime? _lastUpdate;

  /* ===========================
   * NOTIFIER POUR UI AUTO-REFRESH
   * =========================== */
  static final ValueNotifier<int> _updateNotifier = ValueNotifier<int>(0);
  
  /// Stream pour notifier les widgets des changements
  static ValueNotifier<int> get updateNotifier => _updateNotifier;

  /* ===========================
   * POLLING (1s)
   * =========================== */
  static Timer? _pollingTimer;
  static bool _isFetching = false;

  static const Duration _pollingInterval = Duration(seconds: 1);

  /* ===========================
   * INITIALISATION
   * =========================== */
  static Future<void> initialize() async {
    await _refreshFromDatabase();
    _startPolling();
    _collisionService.startDetection();
  }

  /* ===========================
   * POLLING CONTROL
   * =========================== */
  static void _startPolling() {
    if (_pollingTimer != null) return; // ❌ déjà actif

    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      if (_isFetching) return; // ❌ évite appels concurrents
      await _refreshFromDatabase();
    });
  }

  static void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _updateNotifier.dispose();
    _collisionService.dispose();
  }

  /* ===========================
   * DB REFRESH (CENTRAL)
   * =========================== */
  static Future<void> _refreshFromDatabase() async {
    _isFetching = true;
    try {
      // Vols
      final flights = await _dbHelper.getAllFlights();

      // Stats
      final stats = await _dbHelper.getFlightStatistics();
      final activeFlights = await _dbHelper.getActiveFlights();

      // Alertes récentes (< 1h)
      final alerts = await _dbHelper.getAllCollisionAlerts();
      final recentAlerts = alerts.where((a) {
        return DateTime.now().difference(a.detectedAt).inHours < 1;
      }).length;

      // Commit atomique du cache
      _cachedFlights = flights;
      _cachedStats = stats;
      _cachedActiveFlights = activeFlights;
      _cachedAlerts = recentAlerts;
      _lastUpdate = DateTime.now();

      // 🔔 NOTIFIER LES WIDGETS DU CHANGEMENT
      _updateNotifier.value++;

      debugPrint('🔄 DB refresh OK - '
          'Flights=${flights.length}, '
          'Active=$activeFlights, '
          'Delayed=${stats['Delayed'] ?? 0}, '
          'OnGround=${stats['On Ground'] ?? 0}, '
          'Alerts=$recentAlerts');
    } catch (e) {
      debugPrint('❌ DB refresh error: $e');
    } finally {
      _isFetching = false;
    }
  }

  /* ===========================
   * API PUBLIQUE (INCHANGÉE)
   * =========================== */

  /// Getter synchrone (UI-safe)
  static List<Flight> get flights => _cachedFlights;

  /// Async (compatibilité legacy)
  static Future<List<Flight>> getFlights() async => _cachedFlights;

  static List<Widget> kpiCards(BuildContext context) {
    final delayedCount = _cachedStats['Delayed'] ?? 0;
    final onGroundCount = _cachedStats['On Ground'] ?? 0;

    return [
      Expanded(
        child: KpiCard(
          label: 'Active Flights',
          value: '$_cachedActiveFlights',
          icon: LucideIcons.plane,
          color: AppColors.primaryBlue,
          onTap: () => navigateToAdminLogin(context),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: KpiCard(
          label: 'Delayed Flights',
          value: '$delayedCount',
          icon: LucideIcons.alertCircle,
          color: AppColors.warningOrange,
          onTap: () => navigateToAdminLogin(context),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: KpiCard(
          label: 'On Ground',
          value: '$onGroundCount',
          icon: LucideIcons.planeLanding,
          color: AppColors.cardBackground,
          backgroundColor: AppColors.cardBackground,
          onTap: () => navigateToAdminLogin(context),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: KpiCard(
          label: 'Alerts',
          value: '$_cachedAlerts',
          icon: LucideIcons.alertTriangle,
          color: AppColors.alertRed,
          onTap: () => navigateToAdminLogin(context),
        ),
      ),
    ];
  }

  static Future<List<Widget>> kpiCardsAsync(BuildContext context) async {
    return kpiCards(context);
  }
}