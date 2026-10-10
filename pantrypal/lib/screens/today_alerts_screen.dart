import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/alert_card.dart';
import '../widgets/stat_tile.dart';

class TodayAlertsScreen extends StatelessWidget {
  const TodayAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          color: AppColors.brown,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Good Morning, User!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.peach,
                  ),
                ),
              ),
              const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(Icons.person_outline, color: AppColors.brown),
              ),
            ],
          ),
        ),
        // Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today’s Alerts',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brown,
                      ),
                    ),
                    const Text(
                      'Sat 10 Oct',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brown,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        StatTile(
                            value: '3',
                            label: 'Expired / Today',
                            valueColor: AppColors.red),
                        SizedBox(width: 8),
                        StatTile(
                            value: '5',
                            label: 'Next 3 days',
                            valueColor: AppColors.orange),
                        SizedBox(width: 8),
                        StatTile(
                            value: 'RM142',
                            label: 'Value at risk',
                            valueColor: AppColors.cream),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle('Expires Today'),
              AlertCard(
                title: 'Fresh Milk 1L',
                details: 'Batch #B-2841     12 units     Fridge 2',
                message: 'Printed expiry today. Predicted spoilage matches.',
                daysLabel: '0 Days',
                onDiscount: () {},
                onMarkUsed: () {},
                onDiscard: () {},
              ),
              const SizedBox(height: 12),
              const _SectionTitle('Predicted to Spoil Easily'),
              AlertCard(
                title: 'Fresh Milk 1L',
                details: 'Batch #B-2842     12 units     Fridge 2',
                message: 'Printed expiry today. Predicted spoilage matches.',
                daysLabel: '0 Days',
                onDiscount: () {},
                onMarkUsed: () {},
                onDiscard: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.brown,
        ),
      ),
    );
  }
}
