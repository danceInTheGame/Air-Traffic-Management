import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../model/flight.dart';

class FlightTable extends StatelessWidget {
  final List<Flight> flights;

  const FlightTable({super.key, required this.flights});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Flights Overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.list, color: AppColors.textSecondary, size: 18),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(LucideIcons.layoutGrid, color: AppColors.textSecondary, size: 18),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          
          // Column Headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                _buildHeaderCell('Flight', flex: 2),
                _buildHeaderCell('Aircraft', flex: 2),
                _buildHeaderCell('From -> To', flex: 3),
                _buildHeaderCell('Status', flex: 2),
                _buildHeaderCell('Dep / Arr', flex: 2, alignment: Alignment.centerRight),
              ],
            ),
          ),
           const Divider(height: 1, color: AppColors.divider),

          // List
          Expanded(
            child: ListView.separated(
              itemCount: flights.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final flight = flights[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      _buildCell(flight.flightNumber, flex: 2, isBold: true),
                      _buildCell(flight.aircraft, flex: 2),
                       Expanded(
                         flex: 3,
                         child: Row(
                           children: [
                             Text(flight.from, style: const TextStyle(color: Colors.white)),
                             const Padding(
                               padding: EdgeInsets.symmetric(horizontal: 4.0),
                               child: Icon(LucideIcons.arrowRight, size: 12, color: AppColors.textSecondary),
                             ),
                             Text(flight.to, style: const TextStyle(color: Colors.white)),
                           ],
                         ),
                       ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildStatusBadge(flight.status),
                        ),
                      ),
                       _buildCell('${flight.depTime}  ${flight.arrTime}', flex: 2, alignment: Alignment.centerRight),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1, Alignment alignment = Alignment.centerLeft}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildCell(String text, {int flex = 1, bool isBold = false, Alignment alignment = Alignment.centerLeft}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color textColor = Colors.white;
    switch (status) {
      case 'In Flight':
        color = AppColors.successGreen.withOpacity(0.2);
        textColor = AppColors.successGreen;
        break;
      case 'Delayed':
        color = AppColors.warningOrange.withOpacity(0.2);
        textColor = AppColors.warningOrange;
        break;
      case 'En Route':
        color = AppColors.primaryBlue.withOpacity(0.2);
        textColor = AppColors.primaryBlue;
        break;
      case 'Boarding':
        color = Colors.yellow.withOpacity(0.2);
        textColor = Colors.yellow;
        break;
      default:
        color = Colors.grey.withOpacity(0.2);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
