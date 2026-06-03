import 'dart:async';
import 'package:laptop_controller/core/media/domain/i_local_media_info.dart';
import 'package:laptop_controller/core/network/domain/connection_config.dart';
import 'package:laptop_controller/core/network/domain/i_connection_manager.dart';
import 'package:laptop_controller/core/storage/data/storage_service.dart';
import 'package:laptop_controller/features/battery/domain/i_local_battery_sender.dart';
import 'package:laptop_controller/core/handler/data/command_dispatcher.dart';
import 'package:flutter/foundation.dart';
import 'package:laptop_controller/features/pairing/domain/i_pairing_service.dart';

class ServiceCoordinator {
  final IConnectionManager _connectionManager;
  final IBatteryMonitorService _batteryMonitorService;
  final ILocalMediaInfo _mediaService;
  final CommandDispatcher _commandDispatcher;
  final StorageService _storageService;
  final IPairingService _pairingService;

  StreamSubscription? _connectionSubscription;

  ServiceCoordinator({
    required IConnectionManager connectionManager,
    required IBatteryMonitorService batteryMonitorService,
    required ILocalMediaInfo mediaService,
    required CommandDispatcher commandDispatcher,
    required StorageService storageService,
    required IPairingService pairingService,
  })  : _commandDispatcher = commandDispatcher,
        _connectionManager = connectionManager,
        _batteryMonitorService = batteryMonitorService,
        _mediaService = mediaService,
        _storageService = storageService,
        _pairingService = pairingService {
    _init();
  }

  void _init() {
    _connectionSubscription = _connectionManager.connectionStatusStream.listen((status) async {
      if (status == ConnectionStatus.connected) {
        await _startServices();
      } else {
        _stopServices();
      }
    });

    _startServerOnAppLaunch();
  }

  Future<void> _startServerOnAppLaunch() async {
    try {
      var config = await _storageService.getConnectionConfig();
      config ??= TcpConfig(port: 9999);
      
      debugPrint('Start Server $config');

      await _pairingService.initialize(config);

      await _connectionManager.startServer(config);
    } catch (e) {
      debugPrint('[Coordinator Error] Failed to boot network stack: $e');
    }
  }

  Future<void> _startServices() async {
    await _batteryMonitorService.start();
    await _mediaService.start();
    _commandDispatcher.start();
  }

  void _stopServices() {
    _batteryMonitorService.stop();
    _mediaService.dispose();
    _commandDispatcher.stop();
  }

  void dispose() {
    _connectionSubscription?.cancel();
    _stopServices();
  }
}
