import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/storage/provider/file_service_provider.dart';
import '../data/file_transfer_service.dart';
import '../../../core/network/provider/connection_provider.dart';
import '../../../core/notification/provider/notification_provider.dart';
import '../../../core/network/provider/file_transfer_provider.dart';

final fileTransferServiceProvider = Provider((ref) {
  final fileService = ref.watch(fileServiceProvider);
  final mainChannel = ref.watch(connectionManagerProvider);
  final transport = ref.watch(fileTransferTransportProvider);
  final notification = ref.watch(notificationServiceProvider);

  return FileTransferService(
    mainChannel, 
    fileService, 
    transport,
    notification,
  );
});