import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:laptop_controller/theme/app_theme.dart';
import 'package:laptop_controller/core/network/domain/connection_config.dart';
import 'package:laptop_controller/core/network/provider/connection_provider.dart';
import 'package:laptop_controller/core/storage/provider/storage_service_provider.dart';

final pairingTokenProvider = FutureProvider<String>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  return await storage.getPairingToken() ?? '';
});

class PairingScreen extends ConsumerWidget {
  const PairingScreen({super.key});

  void _copyToClipboard(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
      ),
    );
  }

  void _handleManualRefresh(WidgetRef ref, BuildContext context) async {
    // Force Riverpod to clear caches and pull fresh configurations/tokens asynchronously
    ref.invalidate(pairingTokenProvider);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Refreshed Pairing Token'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    // Watch async dependencies independently 
    final configAsync = ref.watch(serverConfigProvider);
    final tokenAsync = ref.watch(pairingTokenProvider);

    return Scaffold(
      body: SafeArea(
        child: configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildErrorState(theme, error.toString(), ref, context),
          data: (config) => tokenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _buildErrorState(theme, error.toString(), ref, context),
            data: (token) {
              // Extract data safely using structural type-promotion
              final String localIP = config is TcpConfig ? config.ip : '127.0.0.1';
              final int port = config is TcpConfig ? config.port : 9999;
              final deviceName = config?.deviceName ?? "Unknown";
              final deviceOs = config?.deviceOS ?? "Unknown";
              
              debugPrint("Displaying config ${config?.toJson()}");
              debugPrint("Displaying $token on QR Screen");

              // TODO : decouple qr scanning from confirmation

              return _buildPairingContent(
                theme: theme,
                ref: ref,
                context: context,
                localIP: localIP,
                port: port,
                token: token,
                deviceName: deviceName,
                deviceOS: deviceOs,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String errorMessage, WidgetRef ref, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.padding * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: AppTheme.spacing),
            Text(
              'Failed to load pairing details',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacing / 2),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacing * 2),
            FilledButton.icon(
              onPressed: () => _handleManualRefresh(ref, context),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairingContent({
    required ThemeData theme,
    required WidgetRef ref,
    required BuildContext context,
    required String localIP,
    required int port,
    required String token,
    required String deviceName,
    required String deviceOS,
  }) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.padding * 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppTheme.padding * 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pairing Screen',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing),
                        Text(
                          'Open the scanner on your mobile device to establish a local connection with this machine.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing * 4),
                        
                        Row(
                          children: [
                            Text(
                              'MANUAL ENTRY',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacing * 2),

                        _buildInfoTile(
                          theme: theme,
                          context: context,
                          icon: Icons.wifi,
                          title: 'IP Address',
                          value: localIP,
                        ),
                        _buildInfoTile(
                          theme: theme,
                          context: context,
                          icon: Icons.numbers,
                          title: 'Port',
                          value: port.toString(),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius * 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(AppTheme.padding * 2),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          QrImageView(
                            data: jsonEncode({
                              'config': {
                                'type': 'tcp',
                                'ip': localIP,
                                'port': port,
                                "deviceName" : deviceName,
                                "deviceOS" : deviceOS,
                              },
                              'token': token,
                            }),
                            version: QrVersions.auto,
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                            size: 320,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black87,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.circle,
                              color: Colors.black87,
                            ),
                          ),
                          Material(
                            elevation: 6,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _handleManualRefresh(ref, context),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                ),
                                child: Icon(
                                  Icons.refresh_rounded,
                                  size: 32,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required ThemeData theme,
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.onPrimaryContainer,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: SelectableText(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy_rounded, size: 22),
          color: theme.colorScheme.primary,
          tooltip: 'Copy $title',
          onPressed: () => _copyToClipboard(context, title, value),
        ),
      ),
    );
  }
}