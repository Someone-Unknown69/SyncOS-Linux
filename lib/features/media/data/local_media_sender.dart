import 'dart:async';
import 'package:laptop_controller/core/media/domain/i_local_media_info.dart';
import 'package:laptop_controller/core/network/domain/i_connection_manager.dart';
import 'package:laptop_controller/models/media_metadata.dart';

class LocalMediaSender {
  final IConnectionManager _connectionManager;
  final ILocalMediaInfo _localMediaInfo;
  StreamSubscription<MediaInfo>? _subscription;

  LocalMediaSender(
    this._connectionManager,
    this._localMediaInfo,
  );

  Future<void> start() async {
    await _localMediaInfo.start();

    _subscription = _localMediaInfo.metadataStream.listen((info) {
      _handleInfoUpdate(info);
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _localMediaInfo.dispose();
  }

  void dispose() {
    stop();
  }

  void _handleInfoUpdate(MediaInfo info) {
    final hasNewArt = info.albumArtBase64.isNotEmpty;

    _connectionManager.send('music', 'update_metadata', info.toMap(includeArt: hasNewArt));
  }

  void sendControlCommand(Map<String, dynamic> args) {
    _localMediaInfo.control(args);
  }
}