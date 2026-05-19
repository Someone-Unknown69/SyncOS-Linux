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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final int _port = 9999;
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
        final String? filePath = await transfer.pickFile();

        if(filePath == null) {
          debugPrint("[FTP] User cancelled file selection");
          return;
        }

        final file = File(filePath);
        final fileName = file.path.split(Platform.pathSeparator).last;
        final fileSize = await file.length();

        final progress = ValueNotifier<double>(0.0);
          
        final task = transfer.sendFile(
          filePath,
          onProgress: (p) => progress.value = p,
        );

        TransferSnackbar.show(
          label: "Sending File",
          fileName: fileName,
          fileSize: fileSize,
          progressNotifier: progress,
          task: task,
          onCancel: () {
            debugPrint("[FTP] File : $fileName Transfer Cancelled");
          }
        );
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
  bool _isExpanded = true;

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
              _buildSidebar(),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
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
                              ValueListenableBuilder<int>(
                                valueListenable: client.connectedClients,
                                builder: (context, clientCount, child) {
                                  if (clientCount > 0) {
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              infoCardsRow(
                                                batteryLevelNotifier: processor.batteryLevel,
                                                isChargingNotifier: processor.isCharging,
                                                volumeNotifier: processor.volume, 
                                                context: context,
                                                onVolumeChanged: (val) {
                                                },
                                              ),
                                              const SizedBox(height: _spacing * 2),
                                              DashboardGrid(items: _items),
                                            ]
                                          ) 
                                        ),
                                        const SizedBox(width: _spacing),
                                        SizedBox(
                                          width: 400,
                                          child: ValueListenableBuilder<MediaMetadata>(
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
                                          )
                                        )
                                      ],
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: _isExpanded ? 260 : 80,
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          const SizedBox(height: 30),
          
          // --- HEADER SECTION ---
          SizedBox(
            height: 48,
            child: Stack(
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isExpanded ? 1.0 : 0.0,
                  child: const Center(
                    child: Text(
                      "SyncOS",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  right: _isExpanded ? 8 : 16, 
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: AnimatedSwitcher( 
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _isExpanded ? Icons.menu_open : Icons.menu,
                          key: ValueKey(_isExpanded),
                        ),
                      ),
                      onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
          
          // --- NAVIGATION ITEMS ---
          _sidebarTile(Icons.dashboard, "Dashboard", true),
          _sidebarTile(Icons.folder_shared, "Files", false),
          _sidebarTile(Icons.terminal, "Configure Commands", false),
          _sidebarTile(Icons.notifications, "Notifications", false),
          _sidebarTile(Icons.settings, "Settings", false),
          
          const Spacer(), 
          
          // --- PC STATUS CARD ---
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isExpanded ? 1.0 : 0.0,
            child: ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: Alignment.center,
                heightFactor: _isExpanded ? 1.0 : 0.0,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sidebarTile(IconData icon, String title, bool selected) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 56, 
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? colorScheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
              ),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isExpanded ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                        color: selected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
                      ),
                    ),
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
