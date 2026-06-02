import 'dart:async';
import 'package:laptop_controller/models/media_metadata.dart';

/// Domain interface
abstract class ILocalMediaInfo {
  Stream<MediaInfo> get metadataStream;

  Future<void> start();

  void dispose();

  void control(Map<String, dynamic> args);
}
