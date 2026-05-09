import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:laptop_controller/services/handle_request.dart';
import 'socket_server.dart';
import 'dart:io';
import 'dashboard/music_player.dart';
import 'pairing_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

final processor = HandleRequest();

class DashboardItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  DashboardItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

// The Entry Point
void main() {
  runApp(const RemoteControllerApp());
}


//Theme config
ThemeData _buildTheme(Brightness brightness) {
  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorSchemeSeed: Colors.blue,
  );

  return baseTheme.copyWith(
    // Global styling for all TextFields
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    // Global styling for all SnackBars
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}


// Wrapper
class RemoteControllerApp extends StatelessWidget {
  const RemoteControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,      // Hides the debug banner
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,            // Forces app to use system mode as theme

      home: const HomeScreen(),               // The starting page
    );
  }
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // Controllers / We can say variables
  final int _port = 9999; // Default is always 9999
  late final PairingService _pairingService;
  late final SocketServer client;

  // Customization for UI
  static const double _borderRadius = 20;       // Can be used to change border radius
  static const double _padding = 16;            // Self explanatory
  static const double _spacing = 12;            // Spacing between widgets

  // Dashboard Items
  late final List<DashboardItem> _items = [
    DashboardItem(
      label: 'Send Files',
      icon: Icons.file_copy,
      onTap: () => (),
    ),
    DashboardItem(
      label: 'Run Command',
      icon: Icons.terminal,
      onTap: () => (),
    ),
    DashboardItem(
      label: 'Send Clipboard',
      icon: Icons.copy_all,
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

  // Method to handle starting server
  Future<void> _handleStartServer() async {
    debugPrint("Starting server on port $_port...");
    await client.startServer(_port);
  }


  @override
  void dispose() { // Clean up memory when the app closes
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    //GestureDetector handles tapping "empty space" to hide keyboard
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
                              _statusConnected(),
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
                                              _infoCardsRow(
                                                batteryLevel: 0.85, // Pass real data here
                                                isCharging: false,
                                                volume: 0.5, // State variable from your parent widget
                                                context: context,
                                                onVolumeChanged: (val) {
                                                  // setState(() => _currentVolume = val);
                                                  // client.send(...) logic here
                                                },
                                              ),

                                              const SizedBox(height: _spacing),

                                              _dashBoard(),
                                            ]
                                          ) 
                                        ),

                                        const SizedBox(width: _spacing),

                                        SizedBox(
                                          width:400,
                                          child: 
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
                                          )
                                        )
                                      ],
                                    );
                                  } else {
                                    return _qrCodeCard();
                                  }
                                },
                              ),
                            ] else  
                              _statusNotConnected(),
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

  bool _isExpanded = true;

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
                // child: _pcStatusCard(colorScheme),
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

  Widget _qrCodeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final qrData = jsonEncode({
      "ip": _localIP,
      "port": _port,
      "http_port": _port + 1,
      "token": _pairingService.pairingToken,
    });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Scan to Pair",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: _spacing),
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
            const SizedBox(height: _spacing),
            Text(
              "Waiting for client connection...",
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }


  // Server settings widget
  Widget _statusNotConnected() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Server Settings",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: _spacing), 
            
            Text("Server IP: $_localIP"),
            Text("Port: $_port"),
            Text("HTTP Port: ${_port + 1}"),
            
            const SizedBox(height: _spacing),

            // Button for starting server
            FilledButton.icon(
              onPressed: _handleStartServer,
              icon: const Icon(Icons.power),
              label: const Text("Start Server"),
              style: ElevatedButton.styleFrom(
                elevation: 2, 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Info after the server is started
  Widget _statusConnected() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Welcome back, USER_NAME", style: TextStyle(fontSize: 30 ,fontWeight: FontWeight.w600)),
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
                          borderRadius: BorderRadius.circular(_borderRadius),
                        ),
                        backgroundColor: colorScheme.primary,
                      ),
                    ),

                    const SizedBox(width: _spacing,),

                    // disconnect button
                    FilledButton.icon(
                      onPressed: () => client.stopServer(),
                      icon: const Icon(Icons.power_off),
                      label: const Text("Disconnect"),
                      style: FilledButton.styleFrom(
                        elevation: 0, 
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_borderRadius),
                        ),
                        backgroundColor: Colors.red,
                        foregroundColor: colorScheme.surfaceBright,
                      ),
                    ),

                  ],
                )
              ],
            ),

            const SizedBox(height: _spacing / 2),

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


  Widget _dashBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 600;
      
        // Using a Grid for both, but changing column count makes it look like a list on desktop
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 1 : 2, // 1 column for list look, 2 for grid
            mainAxisExtent: isDesktop ? 65 : 100, // Height of the item
            crossAxisSpacing: _spacing / 2,
            mainAxisSpacing: _spacing / 2,
          ),
          itemBuilder: (context, index) {
            return _cardTemplate(_items[index], isDesktop);
          },
        );
      },
    );
  }


  Widget _cardTemplate(DashboardItem item, bool isDesktop) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.all(_padding),
            child: !isDesktop ? 
            // For grid 
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(item.icon, size: 24, color: colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )

            // For list
            : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row (
                  children: [
                    Icon(item.icon, color: colorScheme.primary, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ]
                ),
                Icon(
                  Icons.chevron_right_rounded, 
                  size: 18, 
                  color: colorScheme.outline,
                ),
              ],
            )
          ),
        ),
      );
  }

  Widget _infoCardsRow({
    required double batteryLevel,
    required bool isCharging,
    required double volume,
    required ValueChanged<double> onVolumeChanged,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cardBgColor = colorScheme.surfaceContainerLow;
    final batteryColor = isCharging ? Colors.blueAccent : (batteryLevel < 0.2 ? Colors.redAccent : const Color(0xFF4CAF50));

    return IntrinsicHeight( 
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch, 
        children: [
          // --- BATTERY CARD ---
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(_borderRadius),
              ),
              child: Row(
                children: [
                  _buildIconWell(
                    child: _VerticalBattery(level: batteryLevel, color: batteryColor),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Battery", style: TextStyle(color: Colors.white54, fontSize: 13)),
                      Text("${(batteryLevel * 100).toInt()}%", 
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (isCharging)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.bolt, size: 14, color: batteryColor),
                              Text("Charging", style: TextStyle(color: batteryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // --- VOLUME CARD ---
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  _buildIconWell(
                    child: const Icon(Icons.volume_up, color: Colors.white70, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Volume", style: TextStyle(color: Colors.white54, fontSize: 13)),
                        Text("${(volume * 100).toInt()}%", 
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),

                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            activeTrackColor: const Color(0xFF448AFF),
                            inactiveTrackColor: Colors.white10,
                            thumbColor: const Color(0xFF90CAF9),
                            overlayShape: SliderComponentShape.noOverlay,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: Slider(
                              value: volume,
                              onChanged: onVolumeChanged, 
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconWell({required Widget child}) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }
}


class _VerticalBattery extends StatelessWidget {
  final double level;
  final Color color;
  const _VerticalBattery({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 2, decoration: BoxDecoration(color: color.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(1))),
        Container(
          width: 18,
          height: 30,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 24 * level,
              width: double.infinity,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
            ),
          ),
        ),
      ],
    );
  }
}
