// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'package:syncos_linux/models/media_metadata.dart';

/// Domain interface
abstract class IMediaNotification {
  Future<void> init();
  Future<void> updateMetadata(MediaInfo meta);
  Future<void> reset();
}
