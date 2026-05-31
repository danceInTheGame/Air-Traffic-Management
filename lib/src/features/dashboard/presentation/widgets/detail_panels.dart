import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';

class DetailPanel extends StatelessWidget {
  final String title;
  final Widget content;
  final IconData? icon;

  const DetailPanel({
    super.key,
    required this.title,
    required this.content,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (icon != null) Icon(icon, color: AppColors.textSecondary, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class FlightDetailsPanel extends StatelessWidget {
  const FlightDetailsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPanel(
      title: 'Flight Details',
      content: Center(
        child: Text(
          'Select a flight to view\ndetails.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class EventLogPanel extends StatelessWidget {
  const EventLogPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPanel(
      title: 'Event Log',
      icon: LucideIcons.messageSquare,
      content: ListView(
        children: const [
          _LogItem(time: '10:15', message: 'DL305 Delayed due to weather.'),
          _LogItem(time: '09:50', message: 'TK834 Landed at Dubai.'),
          _LogItem(time: '09:20', message: 'AF102 Departed from Paris CDG.'),
        ],
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  final String time;
  final String message;

  const _LogItem({required this.time, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
