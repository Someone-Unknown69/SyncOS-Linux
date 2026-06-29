// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:syncos_linux/core/misc/app_logging.dart';
import 'package:syncos_linux/core/network/domain/i_connection_manager.dart';
import 'package:syncos_linux/features/media/domain/models/media_info.dart';

// This provides remote media updates to both background services as well as UI listeners , the metadata is cached so anyone can request metadata anytime
// Note that this shall be the only source for remote media data as well as control methods
// Also note that this is not supposed to perform any checking of cached things (we are caching for new listeners only) it was aleady supposed to be done on sender side
// Why we are not checking ? What is even going to happen here that already has not happened

class RemoteMediaService {
  final IConnectionManager _connectionManager;

  MediaInfo _mediaCache = MediaInfo.empty;

  final StreamController<MediaInfo> _controller =
      StreamController<MediaInfo>.broadcast();

  StreamSubscription? _bgServiceSubscription;

  MediaInfo get currentState => _mediaCache;

  Stream<MediaInfo> get mediaUpdates => _controller.stream;

  RemoteMediaService(this._connectionManager);

  // Currently this is useless, it shall be utlized in future updates while making the linux backgroound daemon:w
  Future<void> start() async {
    try {
      logDebug('Remote Media', 'Started background media receiver');
    } catch (e) {
      logDebug('Remote Media', 'Initialization failed $e');
    }
  }

  Future<void> stop() async {
    logDebug('Remote Media', 'Stopping service');

    await _bgServiceSubscription?.cancel();
    _bgServiceSubscription = null;
    await _controller.close();
  }

  Future<void> updateMedia(MediaInfo metadata) async {
    try {
      // Merges to cache the data
      _mediaCache = _mediaCache.mergeWith(metadata);
      _controller.add(_mediaCache);
    } catch (e) {
      logDebug('Remote Media', 'Update media failed $e');
    }
  }

  void playPauseToggle() {
    _sendSongChange('play_pause');
  }

  void next() {
    _sendSongChange('next');
  }

  void previous() {
    _sendSongChange('previous');
  }

  void sendSeek(int position) {
    _sendSeekChange(position);
  }

  void _sendSongChange(String method) {
    _connectionManager.send('music', 'control', {'method': method});
  }

  void _sendSeekChange(int position) {
    final updatedMetadata = _mediaCache.copyWith(
      isValid: _mediaCache.isValid,
      position: position,
    );
    updateMedia(updatedMetadata);

    _connectionManager.send('music', 'control', {
      'method': 'seek',
      'position': position / 1000,
    });
  }
}
