import 'dart:async';
import 'package:dbus/dbus.dart';

class MediaInfo {
  final String title;
  final String artist;
  final String album;
  final String albumArt;
  final String status;
  final Duration position;
  final Duration duration;
  final double volume;

  MediaInfo({
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArt,
    required this.status,
    required this.position,
    required this.duration,
    required this.volume,
  });

  Map<String, dynamic> toMap() {
      return {
        'title': title,
        'artist': artist,
        'album': album,
        'albumArt': albumArt,
        'status': status,
        'position': position.inMicroseconds,
        'duration': duration.inMicroseconds,
        'volume': volume,
      };
  }
}

extension DurationFormat on Duration {
  String format() => toString().split('.').first.padLeft(8, "0");
}

class MediaPoller {
  final DBusClient _client = DBusClient.session();
  bool _isRunning = false;
  final _controller = StreamController<MediaInfo>.broadcast();

  Stream<MediaInfo> get mediaStream => _controller.stream;

  static const String _mprisInterface = 'org.mpris.MediaPlayer2.Player';
  static const String _mprisPath = '/org/mpris/MediaPlayer2';


  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    while (_isRunning) {
      try {
        final names = await _client.listNames();
        final playerNames = names.where((n) => n.startsWith('org.mpris.MediaPlayer2.'));

        for (final name in playerNames) {
          try {
            final object = DBusRemoteObject(_client, name: name, path: DBusObjectPath(_mprisPath));

            // Fetch properties from the Player interface
            final metadataVar = await object.getProperty(_mprisInterface, 'Metadata');
            final statusVar = await object.getProperty(_mprisInterface, 'PlaybackStatus');
            final volumeVar = await object.getProperty(_mprisInterface, 'Volume');
            
            // Note: Position is often handled separately as it can fail if player is idle
            DBusValue positionVar;
            try {
              positionVar = await object.getProperty(_mprisInterface, 'Position');
            } catch (_) {
              positionVar = DBusInt64(0);
            }

            final data = metadataVar.asStringVariantDict();

            // Extract and Parse
            final info = MediaInfo(
              status: statusVar.asString(),
              title: data['xesam:title']?.asString() ?? 'Unknown Title',
              album: data['xesam:album']?.asString() ?? 'Unknown Album',
              artist: _parseArtists(data['xesam:artist']),
              albumArt: data['mpris:albumArt']?.asString() ?? '',
              duration: Duration(microseconds: data['mpris:length']?.asInt64() ?? 0),
              position: Duration(microseconds: positionVar.asInt64()),
              volume: volumeVar.asDouble(),
            );

            if (!_controller.isClosed) {
              _controller.add(info);
            }

            if (info.status == 'Playing') break;
          } catch (e) {
            continue;
          }
        }
      } catch (e) {
        _controller.addError(e);
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  String _parseArtists(DBusValue? value) {
    if (value == null) return 'Unknown Artist';
    try {
      return value.asStringArray().join(', ');
    } catch (_) {
      return 'Unknown Artist';
    }
  }

  void stop() => _isRunning = false;
  
  void dispose() {
    stop();
    _controller.close();
    _client.close();
  }
}


