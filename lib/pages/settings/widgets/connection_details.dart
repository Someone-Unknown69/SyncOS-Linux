import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/network/domain/connection_config.dart';
import 'package:laptop_controller/core/network/domain/i_connection_manager.dart';
import 'package:laptop_controller/core/network/provider/connection_provider.dart';
import 'package:laptop_controller/theme/app_theme.dart';

class ConnectionDetailsCard extends ConsumerWidget {
  const ConnectionDetailsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusAsync = ref.watch(connectionStatusProvider);
    final clientConfigAsync = ref.watch(clientConfigProvider);

    final status = statusAsync.value ?? ConnectionStatus.inactive;
    final config = clientConfigAsync.value as TcpConfig?;

    final bool isConnected = status == ConnectionStatus.connected;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.padding),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected ? Colors.green : colorScheme.error,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isConnected ? "CONNECTED" : "DISCONNECTED",
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: isConnected ? Colors.green : colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Text(
                    isConnected ? "Mobile Controller" : "No Device Linked",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  Text(
                    isConnected && config != null
                        ? "${config.ip}:${config.port}"
                        : "Waiting for connection...",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: isConnected ? 'monospace' : null,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: AppTheme.spacing),

            Container(
              padding: const EdgeInsets.all(AppTheme.padding),
              decoration: BoxDecoration(
                color: isConnected 
                    ? colorScheme.primaryContainer.withValues(alpha:0.5)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              child: Icon(
                isConnected ? Icons.phone_android_rounded : Icons.mobile_off_rounded,
                size: 32,
                color: isConnected 
                    ? colorScheme.primary 
                    : colorScheme.onSurfaceVariant.withValues(alpha:0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}