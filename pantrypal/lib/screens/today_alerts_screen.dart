import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/helpers.dart';
import '../core/theme.dart';
import '../models/alert_item.dart';
import '../services/api_service.dart';
import '../widgets/alert_card.dart';
import '../widgets/app_popups.dart';
import '../widgets/stat_tile.dart';

class TodayAlertsScreen extends StatefulWidget {
  const TodayAlertsScreen({super.key});

  @override
  State<TodayAlertsScreen> createState() => _TodayAlertsScreenState();
}

class _TodayAlertsScreenState extends State<TodayAlertsScreen> {
  late Future<AlertsResponse> _future = ApiService.fetchAlerts();

  void _reload() => setState(() => _future = ApiService.fetchAlerts());

  Future<void> _refresh() async {
    final f = ApiService.fetchAlerts();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {
      // The error is shown by the FutureBuilder below.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          color: AppColors.brown,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
          child: const Row(
            children: [
              Expanded(
                child: Text(
                  'Good Morning, User!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.peach,
                  ),
                ),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(Icons.person_outline, color: AppColors.brown),
              ),
            ],
          ),
        ),
        // Body
        Expanded(
          child: FutureBuilder<AlertsResponse>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.brown),
                );
              }
              if (snap.hasError) {
                return _ErrorView(
                  message: snap.error.toString(),
                  onRetry: _reload,
                );
              }
              return RefreshIndicator(
                color: AppColors.brown,
                onRefresh: _refresh,
                child: _AlertsBody(data: snap.data!, onChanged: _reload),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AlertsBody extends StatelessWidget {
  final AlertsResponse data;
  final VoidCallback onChanged;
  const _AlertsBody({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final expired = data.alerts.where((a) => a.daysLeft <= 0).toList();
    final predicted = data.alerts
        .where((a) =>
            a.daysLeft > 0 &&
            a.issueType != 'expiring_soon' &&
            a.issueType != 'expired')
        .toList();
    final soon = data.alerts
        .where((a) => a.daysLeft > 0 && !predicted.contains(a))
        .toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
              Text(
                formatLongDate(data.today),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brown,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  StatTile(
                    value: '${data.expiredOrToday}',
                    label: 'Expired / Today',
                    valueColor: AppColors.red,
                  ),
                  const SizedBox(width: 8),
                  StatTile(
                    value: '${data.dueSoon}',
                    label: 'Next 2 days',
                    valueColor: AppColors.orange,
                  ),
                  const SizedBox(width: 8),
                  StatTile(
                    value: formatRm(data.totalRmAtRisk),
                    label: 'Value at risk',
                    valueColor: AppColors.cream,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (data.alerts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No alerts today. Nothing is at risk.',
                style: TextStyle(fontSize: 15, color: AppColors.brown),
              ),
            ),
          ),

        ..._section(context, 'Expired / Expires Today', expired),
        ..._section(context, 'Predicted to Spoil Easily', predicted),
        ..._section(context, '1-3 Days', soon),
      ],
    );
  }

  List<Widget> _section(
      BuildContext context, String title, List<AlertItem> items) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.brown,
          ),
        ),
      ),
      for (final a in items) ...[
        _AlertTile(alert: a, onChanged: onChanged),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 6),
    ];
  }
}

class _AlertTile extends StatelessWidget {
  final AlertItem alert;
  final VoidCallback onChanged;
  const _AlertTile({required this.alert, required this.onChanged});

  // Saves the change to the backend when the whole batch is used or discarded.
  Future<void> _save(BuildContext context, int? qty, String status) async {
    if (qty == null) return;
    if (qty < _units) {
      showAppSnack(context, 'Partial updates are not saved yet');
      return;
    }
    await _patch(context, status: status);
  }

  // Sends PATCH /batches/{id}, then reloads the alerts so this one drops off.
  // Returns false (after showing the error) if the save failed.
  Future<bool> _patch(BuildContext context,
      {String? status, int? discountPct}) async {
    try {
      await ApiService.updateBatch(alert.batchId,
          status: status, discountPct: discountPct);
      onChanged();
      return true;
    } catch (e) {
      if (context.mounted) showAppSnack(context, e.toString());
      return false;
    }
  }

  String get _qty => '${formatQty(alert.quantity)} ${alert.unit}';
  String get _risk => '${(alert.risk * 100).round()}% risk';
  int get _units => math.max(1, alert.quantity.round());

  String get _recommendation => switch (alert.action) {
        'discount' =>
          'Discount by ${alert.discountPct}% to sell more before it expires.',
        'remove' => 'Remove it from the shelf and record it as waste.',
        'donate' => 'Donate what is left before closing.',
        'monitor' => 'Check again tomorrow. No discount pays off yet.',
        _ => alert.action,
      };

  List<CardAction> _actions(BuildContext context) {
    final name = alert.name;
    final markUsed =
        CardAction('Mark Used', onTap: () async {
      final q = await markUsedFlow(context, name, _units);
      if (context.mounted) await _save(context, q, 'sold_out');
    });

    switch (alert.action) {
      case 'discount':
        return [
          CardAction('Discount ${alert.discountPct}%', filled: true,
              onTap: () async {
            final pct = await discountSheet(context,
                product: name, initial: alert.discountPct);
            if (pct == null || !context.mounted) return;
            final ok = await _patch(context, discountPct: pct);
            if (ok && context.mounted) {
              showAppSnack(context, '$pct% discount applied to $name');
            }
          }),
          markUsed,
        ];
      case 'remove':
        return [
          CardAction('Discard',
              filled: true,
              onTap: () async {
                final q = await discardFlow(context, name, _units);
                if (context.mounted) await _save(context, q, 'discarded');
              }),
        ];
      case 'donate':
        return [
          CardAction('Donate', filled: true, onTap: () async {
            final ok = await _patch(context, status: 'donated');
            if (ok && context.mounted) {
              showAppSnack(context, 'Donation noted for $name');
            }
          }),
          CardAction('Discard', onTap: () async {
            final q = await discardFlow(context, name, _units);
            if (context.mounted) await _save(context, q, 'discarded');
          }),
        ];
      case 'monitor':
        return [
          CardAction('Snooze',
              filled: true, onTap: () => snoozeFlow(context, name)),
          markUsed,
        ];
      default:
        return [markUsed];
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showAlertDetailSheet(
        context,
        title: alert.name,
        details: 'Batch #${alert.batchId} · $_qty · $_risk',
        why: alert.explanation,
        recommendation: _recommendation,
        saving: alert.expectedRmSaved > 0
            ? 'RM ${alert.expectedRmSaved.toStringAsFixed(2)}'
            : null,
      ),
      child: AlertCard(
        title: alert.name,
        details: 'Batch #${alert.batchId}     $_qty     $_risk',
        message: alert.explanation,
        daysLabel: daysLabel(alert.daysLeft),
        badgeColor: alert.daysLeft <= 0 ? AppColors.red : AppColors.peach,
        actions: _actions(context),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 44, color: AppColors.brown),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.brown),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brown,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cream,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}