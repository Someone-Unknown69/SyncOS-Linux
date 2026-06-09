import 'dart:async';
import 'package:laptop_controller/core/network/domain/i_connection_manager.dart';
import 'package:laptop_controller/features/battery/domain/i_local_battery_sender.dart';
import 'package:laptop_controller/core/handler/data/command_dispatcher.dart';
import 'package:flutter/foundation.dart';
import 'package:laptop_controller/features/clipboard/data/local_clipboard_sender.dart';
import 'package:laptop_controller/features/media/data/local_media_sender.dart';

class ServiceCoordinator {
  final CommandDispatcher _commandDispatcher;
  
  // network manager
  final IConnectionManager _connectionManager;
  
  // services 
  final IBatteryMonitorService _batteryMonitorService;
  final LocalMediaSender _mediaService;
  final LocalClipboardSender _clipboardSender;

  StreamSubscription? _connectionSubscription;

  ServiceCoordinator({
    required IConnectionManager connectionManager,
    required IBatteryMonitorService batteryMonitorService,
    required LocalMediaSender mediaService,
    required CommandDispatcher commandDispatcher,
    required LocalClipboardSender clipboardService,
  })  : _commandDispatcher = commandDispatcher,
        _connectionManager = connectionManager,
        _batteryMonitorService = batteryMonitorService,
        _mediaService = mediaService,
        _clipboardSender = clipboardService {
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
      await _connectionManager.startServer();
    } catch (e) {
      debugPrint('[Coordinator Error] Failed to boot network stack: $e');
    }
  }

  Future<void> _startServices() async {
    await _batteryMonitorService.start();
    await _mediaService.start();
    _commandDispatcher.start();
    _clipboardSender.start();
  }

  void _stopServices() {
    _batteryMonitorService.stop();
    _mediaService.stop();
    _commandDispatcher.stop();
    _clipboardSender.stop();
  }

  void dispose() {
    _connectionSubscription?.cancel();
    _stopServices();
  }
}
