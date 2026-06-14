// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:syncos_linux/theme/app_theme.dart';

class AppPopupDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String primaryButtonLabel;
  final VoidCallback? onPrimaryPressed;
  final String secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;

  const AppPopupDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.primaryButtonLabel = 'Confirm',
    this.onPrimaryPressed,
    this.secondaryButtonLabel = 'Cancel',
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 520),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.padding,
                  AppTheme.padding,
                  AppTheme.padding,
                  0,
                ),
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.padding),
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacing / 2),

              Padding(
                padding: const EdgeInsets.all(AppTheme.padding),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: onPrimaryPressed,
                        child: Text(primaryButtonLabel),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSecondaryPressed,
                        child: Text(secondaryButtonLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> showAppPopupDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  String primaryButtonLabel = 'Confirm',
  String secondaryButtonLabel = 'Cancel',
  bool barrierDismissible = true,
  VoidCallback? onPrimaryPressed,
  VoidCallback? onSecondaryPressed,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) {
      return AppPopupDialog(
        title: title,
        subtitle: subtitle,
        primaryButtonLabel: primaryButtonLabel,
        secondaryButtonLabel: secondaryButtonLabel,
        onPrimaryPressed: () {
          if (onPrimaryPressed != null) {
            onPrimaryPressed();
          }
          Navigator.of(context).pop(true);
        },
        onSecondaryPressed: () {
          if (onSecondaryPressed != null) {
            onSecondaryPressed();
          }
          Navigator.of(context).pop(false);
        },
      );
    },
  );
}
