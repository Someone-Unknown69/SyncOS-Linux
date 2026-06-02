import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/handler/data/command_dispatcher.dart';
import 'package:laptop_controller/core/network/provider/connection_provider.dart';
import 'package:laptop_controller/features/media/provider/local_media_sender_provider.dart';
import 'package:laptop_controller/features/file_transfer/provider/file_transfer_provider.dart';

final commandDispatcherProvider = Provider<CommandDispatcher>((ref) {
  final connectionManager = ref.watch(connectionManagerProvider);
  final mediaSender = ref.watch(mediaSenderProvider);
  final fileTransferService = ref.read(fileTransferServiceProvider);
  
  return CommandDispatcher(
    ref,
    connectionManager,
    mediaSender,
    fileTransferService,
  );
});