import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'add_stock_screen.dart';  
import 'batches_screen.dart';
import 'sales_import_screen.dart';
import 'settings_screen.dart';
import 'today_alerts_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Replace the placeholders as you build each screen.
  final _pages = const [
    TodayAlertsScreen(),
    BatchesScreen(),
    AddStockScreen(),  
    SalesImportScreen(),
    SettingsScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: _pages[_index]),
      bottomNavigationBar: Container(
        color: AppColors.brown,
        padding: const EdgeInsets.only(top: 8, bottom: 14),
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(Icons.notifications_none, 'Alerts', 0, _index, _go),
              _NavItem(Icons.inventory_2_outlined, 'Stock', 1, _index, _go),
              _AddButton(active: _index == 2, onTap: () => _go(2)),
              _NavItem(Icons.show_chart, 'Sales', 3, _index, _go),
              _NavItem(Icons.settings_outlined, 'Settings', 4, _index, _go),
            ],
          ),
        ),
      ),
    );
  }

  void _go(int i) => setState(() => _index = i);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavItem(this.icon, this.label, this.index, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    final color = active ? AppColors.navActive : AppColors.cream;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: color),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _AddButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.navActive : AppColors.cream;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -14),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.brown,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(Icons.add, size: 38, color: color),
            ),
          ),
          Text('Add',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}