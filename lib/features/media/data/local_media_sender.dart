import 'dart:async';
import 'package:laptop_controller/core/media/domain/i_local_media_info.dart';
import 'package:laptop_controller/core/network/domain/i_connection_manager.dart';
import 'package:laptop_controller/models/media_metadata.dart';
import 'package:flutter/foundation.dart';

class LocalMediaSender {
  final IConnectionManager _connectionManager;
  final ILocalMediaInfo _localMediaInfo;
  StreamSubscription<MediaInfo>? _subscription;

  LocalMediaSender(
    this._connectionManager,
    this._localMediaInfo,
  );

  Future<void> start() async {
    debugPrint("Subscription started. Listening to Poller instance: ${identityHashCode(_localMediaInfo)}");
    await _subscription?.cancel();

    _subscription = _localMediaInfo.metadataStream.listen((info) {
      debugPrint("This never runs");
      _sendInfoUpdate(info);
    });

    await _localMediaInfo.start();
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

  void _sendInfoUpdate(MediaInfo info) {
    final hasNewArt = info.albumArtBase64.isNotEmpty;
    debugPrint("Sending info $info");
    _connectionManager.send('music', 'update_metadata', info.toMap(includeArt: hasNewArt));
  }

  // TODO : Add a global stream for these

  void sendPlayPause() {
    _connectionManager.send('music', 'control', {'method' : 'play_pause'});
  }

  void sendNext() {
    _connectionManager.send('music', 'control', {'method': 'next'});
  }

  void sendPrev() {
    _connectionManager.send('music', 'control', {'method': 'previous'});
  }

  void sendSeek(int position) {
    _connectionManager.send(
      "music",
      "control",
      {
        "method": 'seek',
        "position": position,
      },
    );
  }
}