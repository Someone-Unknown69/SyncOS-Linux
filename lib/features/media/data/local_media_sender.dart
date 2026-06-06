import 'dart:async';
import 'package:laptop_controller/core/media/domain/i_local_media_info.dart';
import 'package:laptop_controller/core/network/domain/i_connection_manager.dart';
import 'package:laptop_controller/models/media_metadata.dart';
import 'package:flutter/foundation.dart';

class _MusicInfoCache {
  Map<String, dynamic> lastSent = {};
  int lastSentTime = 0;
  String lastTrackIdentity = "";

  void update(Map<String, dynamic> info, String trackIdentity) {
    lastSent = info;
    lastTrackIdentity = trackIdentity;
    lastSentTime = DateTime.now().millisecondsSinceEpoch;
  }
}

class LocalMediaSender {
  final IConnectionManager _connectionManager;
  final ILocalMediaInfo _localMediaInfo;
  StreamSubscription<MediaInfo>? _subscription;

  final _MusicInfoCache _cache = _MusicInfoCache();

  LocalMediaSender(
    this._connectionManager,
    this._localMediaInfo,
  );

  Future<void> start() async {
    debugPrint("Subscription started. Listening to Poller instance: ${identityHashCode(_localMediaInfo)}");
    await _subscription?.cancel();

    _subscription = _localMediaInfo.metadataStream.listen((info) {
      // Add a great caching system here
      _processMap(info.toMap());
    });

    await _localMediaInfo.start();
  }


  void _processMap(Map<String, dynamic> info) {
    final bool isNewTrack = _isNewTrack(info);
    final bool isStateChange = (_cache.lastSent['status']) != (info['status']);
    final bool isSeek = _isSignificantSeek(info);

    // If last art was null / NA and new art is available
    final String? lastArt = _cache.lastSent['albumArt'] as String?;
    final String? newArt = info['albumArt'] as String?;
    final bool isArtDelayed = (lastArt == null || lastArt == 'N/A') && (newArt != null && newArt != 'N/A');

    // If it's a new track, send Song Change. 
    // If not, but state changed, send State Change.
    // If neither, but seeked, send State Change.
    
    debugPrint("$isNewTrack && $isArtDelayed");

    if (isNewTrack || isArtDelayed) {
      debugPrint('[Media Service] Song Change');
      _sendSongChange(info);
    } else if (isStateChange || isSeek) {
      debugPrint('[Media Service] State/Seek Change');
      _sendStateChange(info);
      _cache.update(info, _cache.lastTrackIdentity); 
    }
  }

  bool _isNewTrack(Map<String, dynamic> info) {
    final last = _cache.lastSent;
    return last['title'] != info['title'] ||
          last['artist'] != info['artist'] ||
          last['album'] != info['album'];
  }

  bool _isSignificantSeek(Map<String, dynamic> info) {
    if (_cache.lastSent.isEmpty) return false;
    final lastPosition = (_cache.lastSent['position'] as int?) ?? 0;
    final nowPosition = (info['position'] as int?) ?? 0;
    
    final nowTime = DateTime.now().millisecondsSinceEpoch;
    final expectedPosition = (_cache.lastSent['status'] == 'Playing') 
        ? lastPosition + (nowTime - _cache.lastSentTime)
        : lastPosition;

    return (nowPosition - expectedPosition).abs() > 5000;
  }

  void _sendSongChange(Map<String, dynamic> info) {
    final metadata = MediaInfo(
      status: info['status'] ?? 'Unknown',
      title: info['title'] ?? 'Unknown',
      album: info['album'] ?? 'Unknown',
      artist: info['artist'] ?? 'Unknown Artist',
      duration: ((info['duration'] as int?) ?? 0),
      position: ((info['position'] as int?) ?? 0),
      albumArtBase64: info['albumArt'] as String? ?? 'N/A',
    );

    final payload = metadata.toMap();
    payload['albumArt'] = metadata.albumArtBase64;

    _connectionManager.send('music', 'update_metadata', payload);

    final currentIdentity = "${metadata.title}-${metadata.artist}";
    _cache.update(info, currentIdentity);

    return;
  }

  void _sendStateChange(Map<String, dynamic> info) {
    final metadata = MediaInfo(
      status: info['status'] ?? 'Unknown',
      title: info['title'] ?? 'Unknown',
      album: info['album'] ?? 'Unknown',
      artist: info['artist'] ?? 'Unknown Artist',
      duration: ((info['duration'] as int?) ?? 0),
      position: ((info['position'] as int?) ?? 0),
      albumArtBase64: info['albumArt'] as String? ?? 'N/A',
    );

    final payload = metadata.toMap(includeArt: false);
  
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