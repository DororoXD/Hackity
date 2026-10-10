import 'package:flutter/material.dart';
import '../core/theme.dart';

class AlertCard extends StatelessWidget {
  final String title;
  final String details;
  final String message;
  final String daysLabel;
  final VoidCallback? onDiscount;
  final VoidCallback? onMarkUsed;
  final VoidCallback? onDiscard;

  const AlertCard({
    super.key,
    required this.title,
    required this.details,
    required this.message,
    required this.daysLabel,
    this.onDiscount,
    this.onMarkUsed,
    this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brown,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  daysLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(details,
              style: const TextStyle(fontSize: 11, color: AppColors.brown)),
          const SizedBox(height: 2),
          Text(message,
              style: const TextStyle(fontSize: 11, color: AppColors.brown)),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionButton('Discount', filled: true, onTap: onDiscount),
              const SizedBox(width: 8),
              _ActionButton('Mark Used', onTap: onMarkUsed),
              const SizedBox(width: 8),
              _ActionButton('Discard', onTap: onDiscard),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _ActionButton(this.label, {this.filled = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? AppColors.brown : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.brown),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: filled ? AppColors.cream : AppColors.brown,
            ),
          ),
        ),
      ),
    );
  }
}
