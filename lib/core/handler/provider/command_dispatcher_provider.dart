// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/handler/data/command_dispatcher.dart';
import 'package:syncos_linux/core/network/provider/connection_provider.dart';
import 'package:syncos_linux/core/utilities/provider/remote_command_provider.dart';
import 'package:syncos_linux/features/gamepad/provider/controller_service_provider.dart';
import 'package:syncos_linux/features/media/provider/local_media_sender_provider.dart';
import 'package:syncos_linux/features/file_transfer/provider/file_transfer_provider.dart';
import 'package:syncos_linux/features/notification/provider/remote_notification_service_provider.dart';

final commandDispatcherProvider = Provider<CommandDispatcher>((ref) {
  final connectionManager = ref.watch(connectionManagerProvider);
  final mediaSender = ref.watch(mediaSenderProvider);
  final fileTransferService = ref.read(fileTransferServiceProvider);
  final controllerService = ref.watch(controllerServiceProvider);
  final remoteNotificationService = ref.watch(remoteNotificationServiceProvider);
  final remoteCommandService = ref.watch(remoteCommandProvider);
  
  return CommandDispatcher(
    ref,
    connectionManager,
    mediaSender,
    fileTransferService,
    controllerService,
    remoteNotificationService,
    remoteCommandService,
  );
});