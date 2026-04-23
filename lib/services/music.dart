import 'dart:async';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;


class MediaInfo {
  final String title;
  final String artist;
  final String album;
  final String status;
  final int position;
  final int duration;
  final double volume;

  // returns false if title is "Unknown" or empty
  bool get isValid => title != 'Unknown' && title.isNotEmpty;

  MediaInfo({
    required this.title, required this.artist, required this.album,
    required this.status, required this.position,
    required this.duration, required this.volume,
  });

  Map<String, dynamic> toMap() => {
    'title': title, 'artist': artist, 'album': album,
    'status': status, 'position': position,
    'duration': duration, 'volume': volume,
  };

  // Used for Dirty Cache Check
  bool isSameAs(MediaInfo? other) {
    if (other == null) return false;
    return title == other.title &&
           artist == other.artist &&
           status == other.status &&
           position == other.position;
  }
}

class MediaPoller {
  DBusClient? _client;
  final Map<String, DBusRemoteObject> _players = {};
  final List<StreamSubscription> _subscriptions = [];
  MediaInfo? _lastInfo; // Dirty cache tracker
  String _lastArtUrl = "";
  String? _activePlayerName;

  Future<void> start(void Function(String op, Map<String, dynamic> args) onSend) async {
    if (_client != null) return; // Already running
    
    _client = DBusClient.session();
    
    try {
      final names = await _client!.listNames();
      for (final name in names.where((n) => n.startsWith('org.mpris.MediaPlayer2.'))) {
        _monitorPlayer(name, onSend);
      }
    } catch (e) {
      debugPrint("Failed to start DBus client: $e");
    }
  }

  void _monitorPlayer(String name, void Function(String op, Map<String, dynamic> args) onSend) {
    if (_client == null) return;
    
    final object = DBusRemoteObject(_client!, name: name, path: DBusObjectPath('/org/mpris/MediaPlayer2'));
    _players[name] = object;

    // Listen for D-Bus property changes (this covers Skip, Pause, Resume)
    final sub = DBusSignalStream(_client!, sender: name, interface: 'org.freedesktop.DBus.Properties', 
                     name: 'PropertiesChanged', path: DBusObjectPath('/org/mpris/MediaPlayer2'))
      .listen((signal) => _updateMetadata(name, onSend));
      
    _subscriptions.add(sub);
    
    // Send initial state
    _updateMetadata(name, onSend);
  }

  Future<void> _updateMetadata(String name, void Function(String op, Map<String, dynamic> args) onSend) async {
    final object = _players[name];
    if (object == null) return;

    try {
      final meta = await object.getProperty('org.mpris.MediaPlayer2.Player', 'Metadata');
      final status = await object.getProperty('org.mpris.MediaPlayer2.Player', 'PlaybackStatus');
      final pos = await object.getProperty('org.mpris.MediaPlayer2.Player', 'Position');

      if (status.asString() == 'Playing') {
        _activePlayerName = name;
      }

      final data = meta.asStringVariantDict();
      final rawArtUrl = data['mpris:artUrl']?.asString() ?? '';
      String processedArtBase64 = "";

      // Only fetch/process if the URL has actually changed
      if (rawArtUrl.isNotEmpty && rawArtUrl != _lastArtUrl) {
        final bytes = await _fetchRawBytes(rawArtUrl);
        if (bytes != null) {
          processedArtBase64 = await compute(_processAlbumArt, bytes);
          _lastArtUrl = rawArtUrl; // Update tracker with the new URL
        } else {
          debugPrint("Poller: Failed to fetch bytes for: $rawArtUrl");
        }
      }

      // Construct Info
      final newInfo = MediaInfo(
        status: status.asString(),
        title: data['xesam:title']?.asString() ?? 'Unknown',
        album: data['xesam:album']?.asString() ?? 'Unknown',
        artist: data['xesam:artist']?.asStringArray().join(', ') ?? 'Unknown Artist',
        duration: safeExtractInt(data['mpris:length']) ~/ 1000000,
        position: safeExtractInt(pos) ~/ 1000000,
        volume: 0.0,
      );

      // Send Updates
      // Always check info change
      if (!newInfo.isSameAs(_lastInfo)) {
        _lastInfo = newInfo;
        onSend('music', newInfo.toMap());
      }

      // Send image update only if we processed a new one
      if (processedArtBase64.isNotEmpty) {
        onSend('albumArt_internal', {'albumArt': processedArtBase64});
        onSend('fetch_art', {}); // Trigger fetch event
      }

      debugPrint("Data updated: ${newInfo.title}");

    } catch (e) {
      debugPrint("Info unavailable (likely song transition): $e");
    }
  }

  Future<void> seek(int positionSeconds) async {
    final targetName = _activePlayerName ?? _players.keys.firstOrNull;
    final targetPlayer = _players[targetName];

    if (targetPlayer == null) return;

    try {
      final meta = await targetPlayer.getProperty('org.mpris.MediaPlayer2.Player', 'Metadata');
      final data = meta.asStringVariantDict();
      
      final trackIdValue = data['mpris:trackid'];
      DBusObjectPath? trackIdPath;

      // handling both possible types for trackIdValue
      // spotify sends string insetad of DBusObjectPath
      if (trackIdValue is DBusObjectPath) {
        trackIdPath = trackIdValue;
      } else if (trackIdValue is DBusString) {
        trackIdPath = DBusObjectPath(trackIdValue.value);
      }

      if (trackIdPath != null) {
        await targetPlayer.callMethod(
          'org.mpris.MediaPlayer2.Player',
          'SetPosition',
          [trackIdPath, DBusInt64(positionSeconds * 1000000)],
        );
        debugPrint("Seeked $targetName to $positionSeconds");
      } else {
        debugPrint("Could not determine track ID for seeking.");
      }
    } catch (e) {
      debugPrint("Failed to seek player $targetName: $e");
    }
  }

  Future<void> control(String action) async {
    // Use the cached player
    final targetName = _activePlayerName ?? _players.keys.firstOrNull;
    final targetPlayer = _players[targetName];

    if (targetPlayer == null) return;

    try {
      String method = '';
      if (action == 'next') {method = 'Next';}
      else if (action == 'previous') {method = 'Previous';}
      else if (action == 'play_pause') {method = 'PlayPause';}

      await targetPlayer.callMethod('org.mpris.MediaPlayer2.Player', method, []);
      debugPrint("Sent $method to $targetName");
    } catch (e) {
      debugPrint("Failed to send $action: $e");
      _activePlayerName = null;
    }
  }

  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _players.clear();
    _client?.close();
    _client = null;
    _lastInfo = null;
    _lastArtUrl = "";
  }

  // helper function to support multple dbus types
  int safeExtractInt(DBusValue? value) {
    if (value == null) return 0;
    if (value is DBusInt64) return value.value;
    if (value is DBusUint64) return value.value;
    if (value is DBusInt32) return value.value;
    if (value is DBusUint32) return value.value;
    return 0;
  }
}

Future<Uint8List?> _fetchRawBytes(String artUrl) async {
  try {
    if (artUrl.startsWith('file://')) {
      final file = File(Uri.decodeFull(artUrl.replaceFirst('file://', '')));
      return await file.readAsBytes();
    } else if (artUrl.startsWith('http')) {
      final response = await HttpClient().getUrl(Uri.parse(artUrl)).then((r) => r.close());
      if (response.statusCode == 200) {
        final builder = BytesBuilder();
        await response.forEach(builder.add);
        return builder.toBytes();
      }
    }
  } catch (e) {
    debugPrint("Failed to fetch art bytes: $e");
  }
  return null;
}

Future<String> _processAlbumArt(Uint8List bytes) async {
  return await compute((Uint8List raw) {
    final image = img.decodeImage(raw);
    if (image == null) {
        debugPrint("Isolate: Image decoding failed"); 
        return "";
    }
    // debugPrint("Isolate: Received ${raw.length} bytes.");
    
    final thumbnail = img.copyResize(image, 
      width: 200, 
      interpolation: img.Interpolation.average
    );

    
    final jpg = img.encodeJpg(thumbnail, quality: 100);
    // debugPrint("Isolate: Successfully encoded, length: ${jpg.length}");
    return base64Encode(jpg);
  }, bytes);
}