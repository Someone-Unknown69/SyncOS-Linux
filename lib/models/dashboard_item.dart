// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

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
