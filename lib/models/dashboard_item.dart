import 'package:flutter/material.dart';

class DashboardItem {
  final String label;
  final String body;
  final IconData icon;
  final VoidCallback onTap;

  DashboardItem({
    required this.label,
    required this.icon,
    required this.body,
    required this.onTap,
  });
}
