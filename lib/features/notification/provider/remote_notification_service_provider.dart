// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/network/provider/connection_provider.dart';
import 'package:syncos_linux/core/storage/provider/storage_service_provider.dart';
import 'package:syncos_linux/features/notification/data/remote_notification_service_impl.dart';
import 'package:syncos_linux/features/notification/domain/i_remote_notification_service.dart';

final remoteNotificationServiceProvider = Provider<IRemoteNotificationService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final connectionManager = ref.watch(connectionManagerProvider);

  final provider = RemoteNotificationServiceImpl(
    connectionManager,
    storage,
  );

  ref.onDispose(() {
    provider.dispose();
  });

  return provider;
});