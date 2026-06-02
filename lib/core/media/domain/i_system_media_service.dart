import 'dart:async';
import 'package:laptop_controller/models/media_metadata.dart';

/// Domain interface
abstract class ISystemMediaService {
  Future<void> init();

  Future<void> updateMetadata(MediaInfo meta);

  Future<void> reset();
}
