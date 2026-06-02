import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/network/provider/connection_provider.dart';
import 'package:laptop_controller/core/media/provider/local_media_info_provider.dart';
import 'package:laptop_controller/features/media/data/local_media_sender.dart';

final mediaSenderProvider = Provider((ref) {
  final connectionManager = ref.watch(connectionManagerProvider);
  final localMediaInfo = ref.watch(localMediaInfoProvider);

  return LocalMediaSender(
    connectionManager,
    localMediaInfo,
  );
});