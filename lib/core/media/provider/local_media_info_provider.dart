// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/media/domain/i_local_media_info.dart';
import 'package:syncos_linux/models/media_metadata.dart';
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
