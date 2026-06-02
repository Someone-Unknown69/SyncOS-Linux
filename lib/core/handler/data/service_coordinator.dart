import 'dart:async';
import 'package:laptop_controller/core/media/domain/i_local_media_info.dart';
import 'package:laptop_controller/core/network/domain/i_connection_manager.dart';
import 'package:laptop_controller/features/battery/domain/i_local_battery_sender.dart';
import 'package:laptop_controller/core/handler/data/command_dispatcher.dart';

class ServiceCoordinator {
  final IConnectionManager _connectionManager;
  final IBatteryMonitorService _batteryMonitorService;
  final ILocalMediaInfo _mediaService;
  final CommandDispatcher _commandDispatcher;

  StreamSubscription? _connectionSubscription;

  ServiceCoordinator({
    required IConnectionManager connectionManager,
    required IBatteryMonitorService batteryMonitorService,
    required ILocalMediaInfo mediaService,
    required CommandDispatcher commandDispatcher,
  })  : _commandDispatcher = commandDispatcher,
        _connectionManager = connectionManager,
        _batteryMonitorService = batteryMonitorService,
        _mediaService = mediaService {
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
