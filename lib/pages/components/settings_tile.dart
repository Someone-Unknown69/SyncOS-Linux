// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:syncos_linux/theme/app_theme.dart';

Widget buildSectionHeader(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 20),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.outline,
        letterSpacing: 1.2,
      ),
    ),
  );
}

Widget buildSettingsTile({
  required IconData icon,
  required String title,
  String? subtitle,
  Widget? trailing,
  VoidCallback? onTap,
}) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null ? Text(
        subtitle,
        style: const TextStyle(fontSize: 13),
      ) : null,
      trailing: trailing ?? (onTap != null 
        ? const Icon(Icons.chevron_right_rounded, size: 20)
        : null
      )
    ),
  );
}