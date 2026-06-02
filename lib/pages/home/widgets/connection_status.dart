import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../../../services/pairing_service.dart';
import '../../../services/socket_server.dart';
import '../../../theme/app_theme.dart';

class QrCodeCard extends StatelessWidget {
  final String localIP;
  final int port;
  final PairingService pairingService;
  final double borderRadius = AppTheme.borderRadius;
  final double spacing = AppTheme.spacing;
  final double padding = AppTheme.padding;

  const QrCodeCard({
    super.key,
    required this.localIP,
    required this.port,
    required this.pairingService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final qrData = jsonEncode({
      "type" : "tcp",
      "ip": localIP,
      "port": port,
      "token": pairingService.pairingToken,
    });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Scan to Pair",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: spacing),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            SizedBox(height: spacing),
            Text(
              "Waiting for client connection...",
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusNotConnected extends StatelessWidget {
  final String localIP;
  final int port;
  final VoidCallback onStartServer;
  final double borderRadius = AppTheme.borderRadius;
  final double spacing = AppTheme.spacing;
  final double padding = AppTheme.padding;

  const StatusNotConnected({
    super.key,
    required this.localIP,
    required this.port,
    required this.onStartServer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Server Settings",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: spacing), 
            
            Text("Server IP: $localIP"),
            Text("Port: $port"),
            Text("HTTP Port: ${port + 1}"),
            
            SizedBox(height: spacing),

            // Button for starting server
            FilledButton.icon(
              onPressed: onStartServer,
              icon: const Icon(Icons.power),
              label: const Text("Start Server"),
              style: ElevatedButton.styleFrom(
                elevation: 2, 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusConnected extends StatelessWidget {
  final SocketServer client;
  final double borderRadius = AppTheme.borderRadius;
  final double spacing = AppTheme.spacing;
  final double padding = AppTheme.padding;
  final ValueNotifier<String> deviceName;

  const StatusConnected({
    super.key,
    required this.client,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ValueListenableBuilder(
                valueListenable: deviceName, 
                builder: (context, deviceName, _) {
                  return Text(
                    "Welcome back, $deviceName", 
                    style: TextStyle(fontSize: 30 ,fontWeight: FontWeight.w600)
                  );
                } 
              ),
              
              Row( 
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Ping button 
                  FilledButton.icon(
                    onPressed: () => {},
                    icon: const Icon(Icons.network_ping_rounded),
                    label: const Text("Ping"),
                    style: FilledButton.styleFrom(
                      elevation: 0, 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      backgroundColor: colorScheme.primary,
                    ),
                  ),

                  SizedBox(width: spacing,),

                  // disconnect button
                  FilledButton.icon(
                    onPressed: () async {await client.stopServer();},
                    icon: const Icon(Icons.power_off),
                    label: const Text("Disconnect"),
                    style: FilledButton.styleFrom(
                      elevation: 0, 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      backgroundColor: Colors.red,
                      foregroundColor: colorScheme.surfaceBright,
                    ),
                  ),
                ],
              )
            ],
          ),

          SizedBox(height: spacing / 2),

          ValueListenableBuilder(
            valueListenable: client.connectedClients,
            builder: (context, count, child) {
              return Row(
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
                  Text(
                    "Synced With : $count",
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
