import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/features/clipboard/provider/remote_clipboard_notifier.dart';
import '../../../theme/app_theme.dart';

class ClipboardWidget extends ConsumerStatefulWidget {
  const ClipboardWidget({super.key});

  @override
  ConsumerState<ClipboardWidget> createState() => _ClipboardState();
}

class _ClipboardState extends ConsumerState<ClipboardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final clipboardData = ref.watch(remoteClipboardProvider);

    return Container(
      padding: EdgeInsets.all(AppTheme.padding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              FilledButton.icon(
                onPressed: clipboardData != null
                    ? () {
                        Clipboard.setData(ClipboardData(text: clipboardData.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard!')),
                        );
                      }
                    : null,
                icon: const Icon(Icons.copy),
                label: const Text("Copy Text"),
                style: FilledButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                  // Force the background color for the enabled state
                  backgroundColor: clipboardData != null 
                      ? colorScheme.primary 
                      : colorScheme.surfaceContainerHighest, 
                  foregroundColor: clipboardData != null 
                      ? colorScheme.onPrimary 
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacing),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppTheme.padding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                color: colorScheme.surfaceContainer,
              ),
              child: Center(
                child: Text(
                  clipboardData?.content ?? "No content synced yet",
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}