import 'dart:convert';
import 'package:flutter/material.dart';
import 'socket_server.dart';
import 'dart:io';
import 'music_player.dart';
import 'pairing_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

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

// The "Stateful" Page (Where logic lives)
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
      icon: Icons.document_scanner,
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
        appBar: AppBar(title: const Text("Remote Controller")),
        body: SafeArea(
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
                    children: [
                      if(isConnected) ...[
                        _statusConnected(),
                        const SizedBox(height: _spacing),



                        ValueListenableBuilder<int>(
                          valueListenable: client.connectedClients,
                          builder: (context, clientCount, child) {
                            if (clientCount > 0) {
                              return Column(
                                children: [
                                  MusicPlayerWidget(
                                    imagePath: 'assets/images/album2.png',
                                    trackName: "Music Control",
                                    artistName: "Waiting for playback...",
                                    onPlay: () => {},
                                    onPrev: () => {},
                                    onNext: () => {},
                                  ),

                                  const SizedBox(height: _spacing),
                                  _dashBoard(),
                                ],
                              );
                            }
                            return _qrCodeCard();
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
        side: BorderSide(color: colorScheme.outlineVariant),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        side: BorderSide(color: colorScheme.outlineVariant),
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

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          
          children: [
            const Text("Server Running", style: TextStyle(fontWeight: FontWeight.bold)),

            const Divider(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ValueListenableBuilder(
                  valueListenable: client.connectedClients,
                  builder: (context, count, child) {
                    return Text("Connected Clients: $count");
                  },
                ),

                // Displays device name
                ValueListenableBuilder(
                  valueListenable: client.connectedClients, 
                  builder: (context, name, child) {
                    return Text("Device: $name");
                  }
                )

              ],
            ),

            const SizedBox(height: _spacing),

            Row( 
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // stop server button
                FilledButton.icon(
                  onPressed: () => client.stopServer(),
                  icon: const Icon(Icons.power_off),
                  label: const Text("Stop Server"),
                  style: FilledButton.styleFrom(
                    elevation: 0, 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadius),
                    ),
                    backgroundColor: Colors.red,
                    foregroundColor: colorScheme.surfaceBright,
                  ),
                ),

                const SizedBox(width: _spacing,),

                // Ping button (for testing)
                FilledButton.icon(
                  onPressed: () => {},
                  icon: const Icon(Icons.network_ping_rounded),
                  label: const Text("Ping Clients"),
                  style: FilledButton.styleFrom(
                    elevation: 0, 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadius),
                    ),
                    backgroundColor: colorScheme.primary,
                  ),
                ),

              ],
            )

          ],
        ),
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
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
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


}

