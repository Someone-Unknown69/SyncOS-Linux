import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/hardware/provider/hardware_providers.dart';
import 'package:laptop_controller/core/network/provider/connection_provider.dart';
import 'package:laptop_controller/features/clipboard/data/local_clipboard_sender.dart';

final localClipboardSenderProvider = Provider<LocalClipboardSender>((ref) {
  final connectionManager = ref.watch(connectionManagerProvider);
  final localClipboardInfo = ref.watch(localClipboardInfoProvider); 

  return LocalClipboardSender(
    connectionManager,
    localClipboardInfo,
  );
});