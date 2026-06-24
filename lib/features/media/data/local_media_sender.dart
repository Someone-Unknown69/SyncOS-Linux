// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'package:syncos_linux/core/media/domain/i_local_media_info.dart';
import 'package:syncos_linux/core/misc/app_logging.dart';
import 'package:syncos_linux/core/network/domain/i_connection_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:syncos_linux/features/media/domain/models/media_info.dart';

class LocalMediaSender {
  final IConnectionManager _connectionManager;
  final ILocalMediaInfo _localMediaInfo;

  StreamSubscription<MediaInfo>? _subscription;

  MediaInfo _mediaCache = MediaInfo.empty;
  int _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;

  LocalMediaSender(this._connectionManager, this._localMediaInfo);

  Future<void> start() async {
    debugPrint("Subscription started. Listening to Poller");
    await _subscription?.cancel();

    _subscription = _localMediaInfo.metadataStream.listen((info) {
      _processMap(info);
    });

    await _localMediaInfo.start();
  }

  void _processMap(MediaInfo newMetadata) {
    logDebug('Recieved shit', '${newMetadata.toMap()}');
    final int duration = (newMetadata.duration ?? 0);
    if (duration <= 0 && newMetadata.isValid) return;

    final bool isNewTrack = newMetadata.identity != _mediaCache.identity;
    final changedInfo = newMetadata.calculateDeltaObject(_mediaCache);

    if (changedInfo.toMap().isEmpty) {
      return;
    }

    if (isNewTrack) {
      // Reset the cache media info
      _mediaCache = MediaInfo.empty;
    } else {
      if (changedInfo.position != null &&
          changedInfo.title == null &&
          changedInfo.artist == null &&
          changedInfo.status == null) {
        final int newPos = changedInfo.position!;

        // If the jump is less than or equal to 5000 milliseconds (5 seconds), skip sending
        if (_isNotSignificantChange(newPos)) {
          return;
        }
      }
    }

    _mediaCache = _mediaCache.mergeWith(newMetadata);

    logDebug('Media Cache', 'Sending payload : ${changedInfo.toMap()}');
    _sendChange(changedInfo);
  }

  bool _isNotSignificantChange(int newPos) {
    final int oldPos = _mediaCache.position ?? 0;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int elapsed = now - _lastUpdateTime;
    final int predictedPos = (_mediaCache.status == true)
        ? (oldPos + elapsed)
        : oldPos;
    return (predictedPos - newPos).abs() <= 2000;
  }

  void _sendChange(MediaInfo metadata) async {
    final payload = await metadata.toPayload();
    _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
    _connectionManager.send('music', 'update_metadata', payload);
    return;
  }

  void handleControlCommand(Map<String, dynamic> args) {
    _localMediaInfo.control(args);
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _localMediaInfo.stop();
  }

  void dispose() {
    stop();
    _localMediaInfo.dispose();
  }
}
