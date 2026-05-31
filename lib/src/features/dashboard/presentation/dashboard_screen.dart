import 'package:flutter/material.dart';
import 'package:atc_dashboard/src/features/dashboard/data/mock_data.dart';
import 'widgets/detail_panels.dart';
import 'widgets/flight_table.dart';
import 'widgets/header_bar.dart';
import 'widgets/map_widget.dart';
import '../services/collision_detection_service.dart';
import '../../../features/dashboard/presentation/widgets/collision_alert_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final CollisionDetectionService _collisionService = CollisionDetectionService.instance;

  @override
  void initState() {
    super.initState();
    
    // Écouter les nouvelles alertes de collision
    _collisionService.newAlertNotifier.addListener(_onNewCollisionAlert);
  }

  @override
  void dispose() {
    _collisionService.newAlertNotifier.removeListener(_onNewCollisionAlert);
    super.dispose();
  }

  void _onNewCollisionAlert() {
    final alert = _collisionService.newAlertNotifier.value;
    if (alert != null && mounted) {
      // Afficher le dialogue d'alerte
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => CollisionAlertDialog(
          alert: alert,
          onResolved: () {
            // Rafraîchir les données après résolution
            setState(() {});
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Votre build de dashboard existant
    return Scaffold(
      appBar: const HeaderBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<int>(
          valueListenable: MockData.updateNotifier,
          builder: (context, _, __) {
            return Column(
              children: [
                // KPI Cards Row - Se met à jour automatiquement
                SizedBox(
                  height: 80,
                  child: Row(
                    children: MockData.kpiCards(context),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Main Content Area
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Map Section
                      const Expanded(
                        flex: 2,
                        child: MapWidget(),
                      ),
                      
                      const SizedBox(width: 16),

                      // Side Panel (Flights Overview + Details)
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            // Flights Table - Se met à jour automatiquement
                            Expanded(
                              flex: 3,
                              child: FlightTable(flights: MockData.flights),
                            ),
                            
                            const SizedBox(height: 16),

                            // Details & Logs Row 
                            const Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: FlightDetailsPanel(),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: EventLogPanel(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}