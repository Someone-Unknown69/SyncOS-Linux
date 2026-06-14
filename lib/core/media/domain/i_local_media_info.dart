// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'package:syncos_linux/models/media_metadata.dart';

/// Domain interface
abstract class ILocalMediaInfo {
  Stream<MediaInfo> get metadataStream;

  Future<void> start();

  void stop();

  void dispose();

  void control(Map<String, dynamic> args);
}
