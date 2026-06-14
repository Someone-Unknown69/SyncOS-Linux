import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/network/provider/connection_provider.dart';
import '../../../theme/app_theme.dart';

class StatusNotConnected extends ConsumerWidget {
  const StatusNotConnected({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.padding * 1.5,
          horizontal: AppTheme.padding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.phonelink_off_rounded,
                size: 48,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),

            // Headline
            Text(
              "Device Disconnected",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              "Linked Device is not available",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),

            // Elegant Divider
            Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 16),

            // Quick Checklist items
            _buildChecklistItem(
              context,
              icon: Icons.power_rounded,
              text: "Make sure your phone is turned on",
            ),
            const SizedBox(height: 12),
            _buildChecklistItem(
              context,
              icon: Icons.sync_disabled_rounded,
              text: "Verify the SyncOS companion app is open on your mobile device",
            ),
            const SizedBox(height: 12),
            _buildChecklistItem(
              context,
              icon: Icons.wifi_rounded,
              text: "Ensure both devices are linked to the exact same Wi-Fi network",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(BuildContext context, {required IconData icon, required String text}) {
    final theme = Theme.of(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class StatusConnected extends ConsumerWidget {
  const StatusConnected({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.all(AppTheme.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Welcome back!", 
                style: TextStyle(fontSize: 30 ,fontWeight: FontWeight.w600)
              ),

              FilledButton.icon(
                onPressed: () async {
                  ref.read(connectionManagerProvider).unpair();
                },
                icon: const Icon(Icons.power_off),
                label: const Text("Unpair"),
                style: FilledButton.styleFrom(
                  elevation: 0, 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                  backgroundColor: Colors.red,
                  foregroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),

          SizedBox(height: AppTheme.spacing / 2),

          Row(
            mainAxisSize: MainAxisSize.min, // Prevents row from taking too much space
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.greenAccent, blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 8), // Space between dot and text
              
              Text("Synced"),
            ],
          ),
        ],
      ),
    );
  }
}
