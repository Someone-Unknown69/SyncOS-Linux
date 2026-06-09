import 'package:flutter/material.dart';
import 'package:laptop_controller/theme/app_theme.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;

  const PageHeader(this.title, {super.key, this.showBackButton = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppTheme.padding * 1,
      ),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          Text(
            title,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}