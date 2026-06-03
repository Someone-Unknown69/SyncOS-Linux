import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/network/provider/connection_provider.dart';
import 'package:laptop_controller/core/storage/provider/storage_service_provider.dart';
import 'package:laptop_controller/features/notification/data/remote_notification_service_impl.dart';
import 'package:laptop_controller/features/notification/domain/i_remote_notification_service.dart';

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