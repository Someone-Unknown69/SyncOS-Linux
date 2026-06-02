import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/core/media/domain/i_local_media_info.dart';
import 'package:laptop_controller/models/media_metadata.dart';
import '../data/mediapoller.dart';

final localMediaInfoProvider = Provider<ILocalMediaInfo>((ref) {
  final poller = MediaPoller();

  ref.onDispose(() {
    poller.dispose();
  });

  return poller;
});

final mediaMetadataStreamProvider = StreamProvider<MediaInfo>((ref) async* {
  final streamProvider = ref.watch(localMediaInfoProvider);
  await streamProvider.start();
  yield* streamProvider.metadataStream;
});
