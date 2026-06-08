import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/network/domain/i_connection_manager.dart';
import 'package:laptop_controller/core/network/provider/connection_provider.dart';
import 'package:laptop_controller/features/file_transfer/provider/file_transfer_provider.dart';
import 'package:laptop_controller/pages/home/widgets/battery_card.dart';
import 'package:laptop_controller/pages/home/widgets/music_player.dart';
import 'package:laptop_controller/pages/home/widgets/notifications.dart';
import 'package:laptop_controller/pages/home/widgets/volume_card.dart';
import 'package:laptop_controller/pages/pairing_screen/pairing_screen.dart';
import '../../models/dashboard_item.dart';
import '../../theme/app_theme.dart';
import 'widgets/connection_status.dart';
import 'widgets/quick_actions.dart';
import 'widgets/clipboard.dart';

final _connectionStatusStreamProvider =
  StreamProvider<ConnectionStatus>((ref) {
    final connectionManager = ref.watch(connectionManagerProvider);
    return connectionManager.connectionStatusStream;
  });

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final List<DashboardItem> _items = [
    DashboardItem(
      label: 'Send Files',
      icon: Icons.file_copy,
      onTap: () async {
        final fileTransferService = ref.read(fileTransferServiceProvider);
        fileTransferService.sendFile();
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
      onTap: () async {},
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final connectionStatusAsync = ref.watch(_connectionStatusStreamProvider);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent, 
      child: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.padding),
                child: connectionStatusAsync.when(
                  loading: () => const StatusNotConnected(),
                  error: (error, stackTrace) => const StatusNotConnected(), 
                  data: (connectionStatus) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch, 
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        if (connectionStatus == ConnectionStatus.connected) ...[
                          StatusConnected(),
                          const SizedBox(height: AppTheme.spacing),
        
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final bool isSmallScreen = constraints.maxWidth <= 1000;
        
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: isSmallScreen ? 3 : 1,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: const [
                                                Expanded(child: BatteryCard()),
                                                SizedBox(width: AppTheme.spacing),
                                                Expanded(child: VolumeCard()),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: AppTheme.spacing),
                                    
                                          // Quick actions dashboard
                                          DashboardGrid(items: _items),
                                          const SizedBox(height: AppTheme.spacing),
                                
                                          Expanded(
                                            child: const Clipboard(),
                                          ),
                                        ],
                                      ),
                                    ),
        
                                    const SizedBox(width: AppTheme.spacing),
        
                                    isSmallScreen 
                                      ? Expanded(flex: 2, child: _buildMainContent())
                                      : SizedBox(width: 400, child: _buildMainContent()),
                                  ],
                                );
                              },
                            ),
                          ),
                        ] else if (connectionStatus == ConnectionStatus.active) ...[
                          const Expanded(child: StatusNotConnected()),
                        ] else if (connectionStatus == ConnectionStatus.inactive) ...[
                          const Expanded(child: PairingScreen()),
                        ]
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        MusicPlayerWidget(),
        SizedBox(height: AppTheme.spacing),
        Expanded(child: Notifications()),
      ],
    );
  }
}