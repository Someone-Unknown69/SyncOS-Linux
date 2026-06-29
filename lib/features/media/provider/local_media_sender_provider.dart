// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncos_linux/core/network/provider/connection_provider.dart';
import 'package:syncos_linux/core/media/provider/local_media_info_provider.dart';
import 'package:syncos_linux/features/media/data/local_media_sender.dart';

final mediaSenderProvider = Provider((ref) {
  final connectionManager = ref.watch(connectionManagerProvider);
  final localMediaInfo = ref.watch(localMediaInfoProvider);
  return LocalMediaSender(
    connectionManager,
    localMediaInfo,
  );
});
