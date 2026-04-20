import 'dart:async';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;


class MediaInfo {
  final String title;
  final String artist;
  final String album;
  final String albumArt;
  final String status;
  final int position;
  final int duration;
  final double volume;

  // returns false if title is "Unknown" or empty
  bool get isValid => title != 'Unknown' && title.isNotEmpty;

  MediaInfo({
    required this.title, required this.artist, required this.album,
    required this.albumArt, required this.status, required this.position,
    required this.duration, required this.volume,
  });

  Map<String, dynamic> toMap() => {
    'title': title, 'artist': artist, 'album': album,
    'albumArt': albumArt, 'status': status, 'position': position,
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
  final DBusClient _client = DBusClient.session();
  final Map<String, DBusRemoteObject> _players = {};
  MediaInfo? _lastInfo; // Dirty cache tracker

  Future<void> start(void Function(String op, Map<String, dynamic> args) onSend) async {
    final names = await _client.listNames();
    for (final name in names.where((n) => n.startsWith('org.mpris.MediaPlayer2.'))) {
      _monitorPlayer(name, onSend);
    }
  }

  void _monitorPlayer(String name, void Function(String op, Map<String, dynamic> args) onSend) {
    final object = DBusRemoteObject(_client, name: name, path: DBusObjectPath('/org/mpris/MediaPlayer2'));
    _players[name] = object;

    // Listen for D-Bus property changes (this covers Skip, Pause, Resume)
    DBusSignalStream(_client, sender: name, interface: 'org.freedesktop.DBus.Properties', 
                     name: 'PropertiesChanged', path: DBusObjectPath('/org/mpris/MediaPlayer2'))
      .listen((signal) => _updateMetadata(name, onSend));
  }

  Future<String> _getAlbumArtBase64(String artUrl) async {
    if (!artUrl.startsWith('file://')) return "";
    
    final filePath = artUrl.replaceFirst('file://', '');
    final file = File(filePath);
    
    if (!await file.exists()) return "";

    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return "";

      // RESIZE to 200x200 for speed and low bandwidth usage
      final thumbnail = img.copyResize(image, width: 200, height: 200);
      
      // Encode as JPG and then Base64
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
        albumArt: artUrl,
        duration: (data['mpris:length']?.asInt64() ?? 0) ~/ 1000000,
        position: (pos.asInt64()) ~/ 1000000, 
        volume: 0.0,
      );

      // Dirty Cache Check
      if (!newInfo.isSameAs(_lastInfo) && newInfo.isValid) {
        _lastInfo = newInfo;
        onSend('music', newInfo.toMap());
        debugPrint("Data updated and sent: ${newInfo.title}");
      }
    } catch (e) {
      debugPrint("Info unavailable (likely song transition): $e");
    }
  }

  void dispose() {
    _client.close();
  }
}