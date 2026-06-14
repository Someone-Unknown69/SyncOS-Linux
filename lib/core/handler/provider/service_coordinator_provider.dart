// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/network/provider/connection_provider.dart';
import 'package:syncos_linux/features/battery/provider/local_battery_sender_provider.dart';
import 'package:syncos_linux/features/clipboard/provider/local_clipboard_sender_provider.dart';
import 'package:syncos_linux/features/media/provider/local_media_sender_provider.dart';
import '../data/service_coordinator.dart';
import 'command_dispatcher_provider.dart';

final serviceCoordinatorProvider = Provider<ServiceCoordinator>((ref) {
  final connectionManager = ref.watch(connectionManagerProvider);
  final batteryService = ref.watch(batteryMonitorProvider);
  final mediaService = ref.watch(mediaSenderProvider);
  final commandDispatcher = ref.watch(commandDispatcherProvider);
  final clipboardService = ref.watch(localClipboardSenderProvider);

  final coordinator = ServiceCoordinator(
    connectionManager: connectionManager,
    batteryMonitorService: batteryService,
    mediaService: mediaService,
    commandDispatcher: commandDispatcher,
    clipboardService: clipboardService,
  );

  ref.onDispose(() => coordinator.dispose());

  return coordinator;
});
