import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/theme/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:laptop_controller/core/network/domain/connection_config.dart';
import 'package:laptop_controller/core/storage/provider/storage_service_provider.dart';
import 'package:laptop_controller/features/pairing/provider/pairing_provider.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  bool _isLoading = true;
  String _localIP = 'Loading...';
  int _port = 9999;
  String _token = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readPairingDetails());
  }

Future<void> _readPairingDetails() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final pairingService = ref.read(pairingProvider);
      final storage = ref.read(storageServiceProvider);
      
      final config = await storage.getConnectionConfig();
      final localIP = await pairingService.getLocalIP();
      
      String secureToken = pairingService.pairingToken;
      if (secureToken.isEmpty) {
        secureToken = await storage.getPairingToken() ?? '';
      }

      if (!mounted) return;

      setState(() {
        _localIP = localIP;
        _port = config is TcpConfig ? config.port : 9999;
        _token = secureToken;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pairing Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.padding),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? Center(
                    child: Text(
                      'Failed to load pairing details: $_error',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Scan the QR code to pair a device',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppTheme.spacing),

                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.padding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                color: Colors.white,
                                padding: const EdgeInsets.all(12),
                                child: QrImageView(
                                  data: jsonEncode({
                                    'type': 'tcp',
                                    'ip': _localIP,
                                    'port': _port,
                                    'token': _token,
                                  }),
                                  version: QrVersions.auto,
                                  size: 240,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacing),

                              SelectableText(
                                'IP: $_localIP',
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: AppTheme.spacing / 2),
                              
                              SelectableText(
                                'Port: $_port',
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: AppTheme.spacing / 2),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing * 1.5),
                      
                      FilledButton.icon(
                        onPressed: _readPairingDetails,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh pairing details'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
