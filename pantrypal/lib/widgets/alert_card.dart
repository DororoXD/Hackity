import 'package:flutter/material.dart';
import '../core/theme.dart';

class CardAction {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const CardAction(this.label, {this.filled = false, this.onTap});
}

class AlertCard extends StatelessWidget {
  final String title;
  final String details;
  final String? message;
  final String daysLabel;
  final Color badgeColor;
  final List<CardAction> actions;

  const AlertCard({
    super.key,
    required this.title,
    required this.details,
    this.message,
    required this.daysLabel,
    this.badgeColor = AppColors.red,
    required this.actions,
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
                  color: badgeColor,
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
          if (message != null) ...[
            const SizedBox(height: 2),
            Text(
              message!,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.brown.withOpacity(0.6),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _ActionButton(actions[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final CardAction action;
  const _ActionButton(this.action);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: action.onTap,
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: action.filled ? AppColors.brown : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.brown),
          ),
          child: Text(
            action.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: action.filled ? AppColors.cream : AppColors.brown,
            ),
          ),
        ),
      ),
    );
  }
}