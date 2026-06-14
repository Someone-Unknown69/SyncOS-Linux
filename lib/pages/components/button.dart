// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter/material.dart';

enum ButtonVariant { primary, secondary, outlined }

class Button extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final ButtonVariant variant;

  const Button({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.variant = ButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Resolve styles based on variant selection
    final ButtonStyle buttonStyle;
    switch (variant) {
      case ButtonVariant.primary:
        buttonStyle = FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
        );
        break;
      case ButtonVariant.secondary:
        buttonStyle = FilledButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.onSurfaceVariant,
          elevation: 0,
        );
        break;
      case ButtonVariant.outlined:
        buttonStyle = OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.outlineVariant),
          foregroundColor: colorScheme.primary,
          elevation: 0,
        );
        break;
    }

    // Shared internal layout (Text + Optional Icon / Spinner)
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == ButtonVariant.primary 
                  ? colorScheme.onPrimary 
                  : colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );

    // Apply configuration constraints
    Widget button = variant == ButtonVariant.outlined
        ? OutlinedButton(
            style: buttonStyle.copyWith(
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16, horizontal: 20)),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            onPressed: isLoading ? null : onPressed,
            child: content,
          )
        : FilledButton(
            style: buttonStyle.copyWith(
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16, horizontal: 20)),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            onPressed: isLoading ? null : onPressed,
            child: content,
          );

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}