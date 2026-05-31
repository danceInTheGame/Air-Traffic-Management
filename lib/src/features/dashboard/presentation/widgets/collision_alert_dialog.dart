import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../model/collision_alert.dart';
import '../../services/collision_detection_service.dart';
import '../../data/data_base_helper.dart';
import '../../../../core/theme/app_colors.dart';

class CollisionAlertDialog extends StatefulWidget {
  final CollisionAlert alert;
  final VoidCallback? onResolved;

  const CollisionAlertDialog({
    super.key,
    required this.alert,
    this.onResolved,
  });

  @override
  State<CollisionAlertDialog> createState() => _CollisionAlertDialogState();
}

class _CollisionAlertDialogState extends State<CollisionAlertDialog> {
  final CollisionDetectionService _collisionService = CollisionDetectionService.instance;
  bool _isResolving = false;
  String? _selectedFlight;

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = screenSize.width * 0.9;
    final maxHeight = screenSize.height * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth.clamp(300.0, 550.0),
          maxHeight: maxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F3A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.alertRed, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.alertRed.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1428),
                    border: Border(
                      bottom: BorderSide(color: Colors.white10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.alertRed.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          LucideIcons.alertTriangle,
                          color: AppColors.alertRed,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COLLISION RISK DETECTED',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.alertRed,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Immediate action required',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: Colors.white60, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Flight A info
                        _buildFlightInfo(
                          flightNumber: alert.flightA.flightNumber,
                          route: '${alert.flightA.from} → ${alert.flightA.to}',
                          aircraft: alert.flightA.aircraft,
                        ),

                        const SizedBox(height: 12),

                        // Distance indicators
                        Row(
                          children: [
                            Expanded(
                              child: _buildDistanceCard(
                                label: 'Horizontal',
                                value: '${(alert.horizontalDistance / 1000).toStringAsFixed(1)} km',
                                icon: LucideIcons.moveHorizontal,
                                color: alert.horizontalDistance < 3000 
                                    ? AppColors.alertRed 
                                    : AppColors.warningOrange,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildDistanceCard(
                                label: 'Vertical',
                                value: '${alert.verticalDistance.toStringAsFixed(0)} ft',
                                icon: LucideIcons.moveVertical,
                                color: alert.verticalDistance < 500 
                                    ? AppColors.alertRed 
                                    : AppColors.warningOrange,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Flight B info
                        _buildFlightInfo(
                          flightNumber: alert.flightB.flightNumber,
                          route: '${alert.flightB.from} → ${alert.flightB.to}',
                          aircraft: alert.flightB.aircraft,
                        ),

                        const SizedBox(height: 20),

                        // Divider
                        Container(
                          height: 1,
                          color: Colors.white10,
                        ),

                        const SizedBox(height: 20),

                        // Resolution title
                        const Text(
                          'SELECT FLIGHT TO ADJUST',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white60,
                            letterSpacing: 1,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Flight selection buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildFlightSelectionButton(
                                flightNumber: alert.flightA.flightNumber,
                                isSelected: _selectedFlight == alert.flightA.flightNumber,
                                onTap: () => setState(() => _selectedFlight = alert.flightA.flightNumber),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildFlightSelectionButton(
                                flightNumber: alert.flightB.flightNumber,
                                isSelected: _selectedFlight == alert.flightB.flightNumber,
                                onTap: () => setState(() => _selectedFlight = alert.flightB.flightNumber),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Action buttons
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: _buildActionButton(
                                label: 'Increase Altitude (+2000ft)',
                                icon: LucideIcons.arrowUp,
                                color: AppColors.successGreen,
                                enabled: _selectedFlight != null && !_isResolving,
                                onPressed: () => _resolveCollision(increaseAltitude: true),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: _buildActionButton(
                                label: 'Decrease Altitude (-2000ft)',
                                icon: LucideIcons.arrowDown,
                                color: AppColors.primaryBlue,
                                enabled: _selectedFlight != null && !_isResolving,
                                onPressed: () => _resolveCollision(increaseAltitude: false),
                              ),
                            ),
                          ],
                        ),

                        if (_isResolving) ...[
                          const SizedBox(height: 16),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Applying altitude change...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlightInfo({
    required String flightNumber,
    required String route,
    required String aircraft,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1428),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              LucideIcons.plane,
              color: AppColors.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flightNumber,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  route,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Aircraft: $aircraft',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFlightSelectionButton({
    required String flightNumber,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryBlue.withOpacity(0.2) 
              : const Color(0xFF0F1428),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.white10,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              color: isSelected ? AppColors.primaryBlue : Colors.white38,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                flightNumber,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primaryBlue : Colors.white60,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? color : Colors.white10,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveCollision({required bool increaseAltitude}) async {
    if (_selectedFlight == null) return;

    setState(() => _isResolving = true);

    try {
      final dbHelper = DatabaseHelper.instance;
      final position = await dbHelper.getLatestPosition(_selectedFlight!);
      
      if (position != null) {
        final currentAltitude = position.altitude;
        final newAltitude = _collisionService.getSuggestedAltitude(
          currentAltitude,
          increaseAltitude,
        );

        final success = await _collisionService.resolveCollision(
          flightNumber: _selectedFlight!,
          newAltitude: newAltitude,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.checkCircle2, color: AppColors.successGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Altitude adjusted for $_selectedFlight: $currentAltitude ft → $newAltitude ft',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1A1F3A),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );

          widget.onResolved?.call();
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la résolution: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to apply altitude change'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }
}