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

  Future<String> _getAlbumArtBase64(String artUrl) async {
    if (artUrl.isEmpty) return "";
    
    try {
      Uint8List? bytes;

      if (artUrl.startsWith('file://')) {
        final filePath = Uri.decodeFull(artUrl.replaceFirst('file://', ''));
        final file = File(filePath);
        if (!await file.exists()) return "";
        bytes = await file.readAsBytes();
      } else if (artUrl.startsWith('http://') || artUrl.startsWith('https://')) {
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(Uri.parse(artUrl));
        final response = await request.close();
        if (response.statusCode == 200) {
          final builder = BytesBuilder();
          await response.forEach(builder.add);
          bytes = builder.toBytes();
        } else {
          return "";
        }
      } else {
        return "";
      }

      final image = img.decodeImage(bytes);
      if (image == null) return "";

      final thumbnail = img.copyResize(image, width: 200, height: 200);
      final jpg = img.encodeJpg(thumbnail, quality: 75);
      
      return base64Encode(jpg);
    } catch (e) {
      debugPrint("Image processing error: $e");
      return "";
    }
  }

  Future<void> _updateMetadata(String name, void Function(String op, Map<String, dynamic> args) onSend) async {
    final object = _players[name];
    if (object == null) return;

    try {
      // Fetch properties with individual error handling
      final meta = await object.getProperty('org.mpris.MediaPlayer2.Player', 'Metadata');
      final status = await object.getProperty('org.mpris.MediaPlayer2.Player', 'PlaybackStatus');
      final pos = await object.getProperty('org.mpris.MediaPlayer2.Player', 'Position');

      final data = meta.asStringVariantDict();
      final artUrl = await _getAlbumArtBase64(data['mpris:artUrl']?.asString() ?? '');

      final newInfo = MediaInfo(
        status: status.asString(),
        title: data['xesam:title']?.asString() ?? 'Unknown',
        album: data['xesam:album']?.asString() ?? 'Unknown',
        artist: data['xesam:artist']?.asStringArray().join(', ') ?? 'Unknown Artist',
        duration: (data['mpris:length']?.asInt64() ?? 0) ~/ 1000000,
        position: (pos.asInt64()) ~/ 1000000, 
        volume: 0.0,
      );

      // Dirty Cache Check (Send even if Unknown, to clear UI on start)
      bool artChanged = artUrl != _lastArtUrl;

      if (!newInfo.isSameAs(_lastInfo) || artChanged) {
        _lastInfo = newInfo;
        _lastArtUrl = artUrl;
        
        onSend('music', newInfo.toMap());
        
        if (artUrl.isNotEmpty) {
          onSend('albumArt_internal', {'albumArt': artUrl});
          if (artChanged) {
            onSend('fetch_art', {});
          }
        }
        
        debugPrint("Data updated and sent: ${newInfo.title}");
      }

    } catch (e) {
      debugPrint("Info unavailable (likely song transition): $e");
    }
  }

  Future<void> seek(int positionSeconds) async {
    for (var name in _players.keys) {
      try {
        final object = _players[name];
        if (object != null) {
          final meta = await object.getProperty('org.mpris.MediaPlayer2.Player', 'Metadata');
          final data = meta.asStringVariantDict();
          final trackId = data['mpris:trackid']?.asObjectPath();
          if (trackId != null) {
            await object.callMethod(
              'org.mpris.MediaPlayer2.Player',
              'SetPosition',
              [DBusObjectPath(trackId.value), DBusInt64(positionSeconds * 1000000)],
            );
            debugPrint("Seeked $name to $positionSeconds");
          }
        }
      } catch (e) {
        debugPrint("Failed to seek player $name: $e");
      }
    }
  }

  Future<void> control(String action) async {
    for (var name in _players.keys) {
      try {
        final object = _players[name];
        if (object != null) {
          String method = '';
          if (action == 'next') method = 'Next';
          else if (action == 'previous') method = 'Previous';
          else if (action == 'play_pause') method = 'PlayPause';
          
          if (method.isNotEmpty) {
            await object.callMethod(
              'org.mpris.MediaPlayer2.Player',
              method,
              [],
            );
            debugPrint("Sent $method to $name");
          }
        }
      } catch (e) {
        debugPrint("Failed to send $action to player $name: $e");
      }
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
}