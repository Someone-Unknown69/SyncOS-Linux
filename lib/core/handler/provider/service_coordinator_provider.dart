import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/media/provider/local_media_info_provider.dart';
import 'package:laptop_controller/core/network/provider/connection_provider.dart';
import 'package:laptop_controller/core/storage/provider/storage_service_provider.dart';
import 'package:laptop_controller/features/battery/provider/local_battery_sender_provider.dart';
import 'package:laptop_controller/features/pairing/provider/pairing_provider.dart';
import '../data/service_coordinator.dart';
import 'command_dispatcher_provider.dart';

final serviceCoordinatorProvider = Provider<ServiceCoordinator>((ref) {
  final connectionManager = ref.watch(connectionManagerProvider);
  final batteryService = ref.watch(batteryMonitorProvider);
  final mediaService = ref.watch(localMediaInfoProvider);
  final commandDispatcher = ref.watch(commandDispatcherProvider);
  final storageService = ref.watch(storageServiceProvider);
  final pairingService = ref.watch(pairingProvider);

  final coordinator = ServiceCoordinator(
    connectionManager: connectionManager,
    batteryMonitorService: batteryService,
    mediaService: mediaService,
    commandDispatcher: commandDispatcher,
    storageService: storageService,
    pairingService: pairingService,
  );

  ref.onDispose(() => coordinator.dispose());

  return coordinator;
});
