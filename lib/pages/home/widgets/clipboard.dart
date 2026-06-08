import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class Clipboard extends StatelessWidget {
  final double borderRadius = AppTheme.borderRadius;
  final double spacing = AppTheme.spacing;
  final double padding = AppTheme.padding;

  const Clipboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.paste_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 20.0,
                  ),
                  SizedBox(width: AppTheme.spacing),
                  Text(
                    'Clipboard',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14.0,
                      fontWeight: FontWeight(500)
                    ),
                  ),
                ],
              ),
      
              FilledButton.icon(
                onPressed: () => {},
                icon: const Icon(Icons.sync),
                label: const Text("Sync Clipboard"),
                style: FilledButton.styleFrom(
                  elevation: 0, 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  backgroundColor: colorScheme.primary,
                ),
              ),
            ],
          ),
      
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                color: colorScheme.surfaceContainerLow,
              ),
              child: const Center(
                child: Text("This fills the rest of the vertical space"),
              )
            ),
          )
        ],
      ),
    );
  }

}