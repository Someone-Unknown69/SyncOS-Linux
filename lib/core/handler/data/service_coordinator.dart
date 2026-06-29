// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'package:syncos_linux/core/media/domain/i_media_notification.dart';
import 'package:syncos_linux/core/network/domain/i_connection_manager.dart';
import 'package:syncos_linux/features/battery/domain/i_local_battery_sender.dart';
import 'package:syncos_linux/core/handler/data/command_dispatcher.dart';
import 'package:flutter/foundation.dart';
import 'package:syncos_linux/features/clipboard/data/local_clipboard_sender.dart';
import 'package:syncos_linux/features/media/data/local_media_sender.dart';

class ServiceCoordinator {
  final CommandDispatcher _commandDispatcher;

  // network manager
  final IConnectionManager _connectionManager;

  // services
  final IBatteryMonitorService _batteryMonitorService;
  final LocalMediaSender _mediaService;
  final LocalClipboardSender _clipboardSender;
  final IMediaNotification _mediaNotification;

  StreamSubscription? _connectionSubscription;

  ServiceCoordinator({
    required IConnectionManager connectionManager,
    required IBatteryMonitorService batteryMonitorService,
    required LocalMediaSender mediaService,
    required CommandDispatcher commandDispatcher,
    required LocalClipboardSender clipboardService,
    required IMediaNotification mediaNotification,
  }) : _commandDispatcher = commandDispatcher,
       _connectionManager = connectionManager,
       _batteryMonitorService = batteryMonitorService,
       _mediaService = mediaService,
       _mediaNotification = mediaNotification,
       _clipboardSender = clipboardService {
    _init();
  }

  void _init() {
    _connectionSubscription = _connectionManager.connectionStatusStream.listen((
      status,
    ) async {
      if (status == ConnectionStatus.connected) {
        await _startServices();
      } else {
        await _stopServices();
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
    await _mediaNotification.start();
    _clipboardSender.start();
    _commandDispatcher.start();
  }

  Future<void> _stopServices() async {
    _batteryMonitorService.stop();
    _mediaService.stop();
    _clipboardSender.stop();
    await _mediaNotification.stop();
    _commandDispatcher.stop();
  }

  void dispose() {
    _connectionSubscription?.cancel();
    _stopServices();
  }
}
