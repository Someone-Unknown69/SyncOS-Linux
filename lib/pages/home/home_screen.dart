import 'package:flutter/material.dart';
import 'dart:io';
import '../../services/socket_server.dart';
import '../../services/pairing_service.dart';
import '../../services/file_transfer.dart';
import '../../services/handle_request.dart';
import '../../core/globals.dart';
import '../../models/dashboard_item.dart';
import '../../theme/app_theme.dart';
import 'widgets/connection_status.dart';
import 'widgets/quick_actions.dart';
import 'widgets/info_cards.dart';
import 'widgets/music_player.dart';
import 'widgets/sidebar.dart';
import 'widgets/clipboard.dart';
import 'widgets/notifications.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final int _port = 9999;

  // All services used
  late final PairingService _pairingService;
  late final SocketServer client;

  static const double _padding = AppTheme.padding;
  static const double _spacing = AppTheme.spacing;

  late final List<DashboardItem> _items = [
    DashboardItem(
      label: 'Send Files',
      icon: Icons.file_copy,
      onTap: () async {
        final transfer = FileTransfer();
        await transfer.transferFile();
      },
    ),
    DashboardItem(
      label: 'Run Command',
      icon: Icons.terminal,
      onTap: () => (),
    ),
    DashboardItem(
      label: 'Ring Device',
      icon: Icons.speaker_phone,
      onTap: () => (),
    ),
  ];

  String _localIP = 'Loading...';
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _pairingService = PairingService(port: _port);
    client = SocketServer(pairingService: _pairingService);
    _initialize();
  }

  Future<void> _initialize() async {
    await _getLocalIP();
    await _pairingService.initialize();
    setState(() {
      _isInitializing = false;
    });
  }

  Future<void> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            _localIP = addr.address;
            return;
          }
        }
      }
      _localIP = 'No IP found';
    } catch (e) {
      _localIP = 'Error: $e';
    }
  }

  Future<void> _handleStartServer() async {
    debugPrint("Starting server on port $_port...");
    await client.startServer(_port);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent, 
      child: Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Sidebar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(_padding),
                  child: ValueListenableBuilder<bool>(
                      valueListenable: client.connectionStatus,
                      builder: (context, isConnected, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch, 
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            if(isConnected) ...[
                              StatusConnected(
                                client: client,
                                deviceName: processor.deviceName,
                              ),
                              const SizedBox(height: _spacing),
                              Expanded(
                                child: ValueListenableBuilder<int>(
                                  valueListenable: client.connectedClients,
                                  builder: (context, clientCount, child) {
                                    if (clientCount > 0) {
                                      return LayoutBuilder(
                                        builder: (context, constraints) {

                                          final bool isSmallScreen = constraints.maxWidth <= 1000;

                                          return Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: isSmallScreen ? 3 : 1,
                                                child: Column(
                                                  children: [
                                                    // battery and volume cards
                                                    infoCardsRow(
                                                      batteryLevelNotifier: processor.batteryLevel,
                                                      isChargingNotifier: processor.isCharging,
                                                      volumeNotifier: processor.volume, 
                                                      context: context,
                                                      onVolumeChanged: (val) {
                                                      },
                                                    ),
                                                    const SizedBox(height: _spacing),
                                          
                                                    // Quick actions
                                                    DashboardGrid(items: _items),
                                                    const SizedBox(height: _spacing),
                                          
                                                    // Clipboard history
                                                    Expanded(child: Clipboard()),
                                          
                                                  ]
                                                ) 
                                              ),
                                          
                                              const SizedBox(width: _spacing),
                                          
                                              isSmallScreen ? 

                                              Expanded(
                                                flex: 2, // Shrinks proportionally with the left column when window space is tight
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    ValueListenableBuilder<MediaMetadata>(
                                                      valueListenable: processor.metadata, 
                                                      builder: (context, info, child) {
                                                        return MusicPlayerWidget(
                                                          imagePath: info.albumArt, 
                                                          trackName: info.title, 
                                                          artistName: info.artist, 
                                                          position: info.position, 
                                                          duration: info.duration, 
                                                          status: info.status, 
                                                          albumArtBase64: info.albumArt,
                                                          client: client,
                                                        );
                                                      }
                                                    ),
                                                    const SizedBox(height: _spacing),
                                                    const Expanded(child: Notifications()),
                                                  ],
                                                ),
                                              ) 
                                              
                                              :
                                              
                                              SizedBox(
                                                width: 400,
                                                child: Column(
                                                  children: [
                                                    ValueListenableBuilder<MediaMetadata>(
                                                      valueListenable: processor.metadata, 
                                                      builder: (context, info, child) {
                                                        return MusicPlayerWidget(
                                                          imagePath: info.albumArt, 
                                                          trackName: info.title, 
                                                          artistName: info.artist, 
                                                          position: info.position, 
                                                          duration: info.duration, 
                                                          status: info.status, 
                                                          albumArtBase64: info.albumArt,
                                                          client: client,
                                                        );
                                                      }
                                                    ),
                                                
                                                    const SizedBox(height: _spacing),
                                                
                                                    Expanded(child: Notifications())
                                                  ],
                                                ),
                                              )
                                            ],
                                          );
                                        }
                                      );
                                    } else {
                                      return QrCodeCard(
                                        localIP: _localIP,
                                        port: _port,
                                        pairingService: _pairingService,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ] else  
                              StatusNotConnected(
                                localIP: _localIP, 
                                port: _port, 
                                onStartServer: _handleStartServer
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}
