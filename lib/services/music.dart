import 'dart:async';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

@immutable
class MediaInfo {
  final String title;
  final String artist;
  final String album;
  final String status;
  final int position;
  final int duration;
  final String albumArtBase64;

  const MediaInfo({
    required this.title,
    required this.artist,
    required this.album,
    required this.status,
    required this.position,
    required this.duration,
    required this.albumArtBase64,
  });

  static const empty = MediaInfo(
    title: '',
    artist: '',
    album: '',
    status: 'Stopped',
    position: 0,
    duration: 0,
    albumArtBase64: '',
  );

  bool get isValid => title != 'Unknown' && title.isNotEmpty;

  Map<String, dynamic> toMap({bool includeArt = true}) => {
    'title': title,
    'artist': artist,
    'album': album,
    'status': status,
    'position': position,
    'duration': duration,
    if (includeArt)'albumArt': albumArtBase64.isNotEmpty ? albumArtBase64 : null,
  };

  MediaInfo copyWith({
    String? title,
    String? artist,
    String? album,
    String? status,
    int? position,
    int? duration,
    String? albumArtBase64,
  }) => MediaInfo(
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    status: status ?? this.status,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    albumArtBase64: albumArtBase64 ?? this.albumArtBase64,
  );

  // Used for Dirty Cache Check (ignores the album art url)
  bool isSameAs(MediaInfo? other) {
    if (other == null) return false;
    return title == other.title &&
           artist == other.artist &&
           status == other.status &&
           position == other.position;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaInfo &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          artist == other.artist &&
          album == other.album &&
          status == other.status &&
          position == other.position &&
          duration == other.duration &&
          albumArtBase64 == other.albumArtBase64;

  @override
  int get hashCode => Object.hash(
      title, artist, album, status, position, duration, albumArtBase64);

  @override
  String toString() => 'MediaInfo(title: $title, status: $status)';
}


class MediaPoller {
  DBusClient? _client;
  final Map<String, DBusRemoteObject> _players = {};
  final List<StreamSubscription> _subscriptions = [];
  MediaInfo? _lastInfo; // Dirty cache tracker

  // Per-player art URL cache so switching players always re-sends art
  final Map<String, String> _lastArtUrlPerPlayer = {};

  String? _activePlayerName;

  Future<void> start(void Function(String op, String action, Map<String, dynamic> args) onSend) async {
    if (_client != null) return; // Already running
    
    _client = DBusClient.session();
    
    try {
      final names = await _client!.listNames();
      for (final name in names.where((n) => n.startsWith('org.mpris.MediaPlayer2.'))) {
        _monitorPlayer(name, onSend);
      }

      // Watch for new players appearing / old players disappearing on D-Bus
      final nameOwnerSub = DBusSignalStream(
        _client!,
        sender: 'org.freedesktop.DBus',
        interface: 'org.freedesktop.DBus',
        name: 'NameOwnerChanged',
      ).listen((signal) {
        if (signal.values.length < 3) return;
        final serviceName = (signal.values[0] as DBusString).value;
        final newOwner   = (signal.values[2] as DBusString).value;

        if (!serviceName.startsWith('org.mpris.MediaPlayer2.')) return;

        if (newOwner.isNotEmpty) {
          // A new MPRIS player just appeared
          debugPrint('New player detected: $serviceName');
          _monitorPlayer(serviceName, onSend);
        } else {
          // A player just exited
          debugPrint('Player exited: $serviceName');
          _players.remove(serviceName);
          _lastArtUrlPerPlayer.remove(serviceName);
          if (_activePlayerName == serviceName) {
            // Reset active player, the next PropertiesChanged event from a
            // remaining Playing player will automatically claim the slot.
            _activePlayerName = null;
            _lastInfo = null; // force a fresh push when the next player takes over
            debugPrint('Active player removed; waiting for next active player.');
          }
        }
      });
      _subscriptions.add(nameOwnerSub);

    } catch (e) {
      debugPrint("Failed to start DBus client: $e");
    }
  }

  void _monitorPlayer(String name, void Function(String op, String action, Map<String, dynamic> args) onSend) {
    if (_client == null) return;
    if (_players.containsKey(name)) return; // Already monitoring
    
    // Ensure we start with a fresh art fetch for this player when it first becomes active
    _lastArtUrlPerPlayer.remove(name);
    
    final object = DBusRemoteObject(_client!, name: name, path: DBusObjectPath('/org/mpris/MediaPlayer2'));
    _players[name] = object;

    // Listen for D-Bus property changes
    final sub = DBusSignalStream(_client!, sender: name, interface: 'org.freedesktop.DBus.Properties', 
                     name: 'PropertiesChanged', path: DBusObjectPath('/org/mpris/MediaPlayer2'))
      .listen((signal) => _updateMetadata(name, onSend, signal: signal));
      
    _subscriptions.add(sub);
    
    // Send initial state
    _updateMetadata(name, onSend);
  }

  Future<void> _updateMetadata(String name, void Function(String op, String action, Map<String, dynamic> args) onSend, {DBusSignal? signal}) async {
    final object = _players[name];
    if (object == null) return;

    try {
      DBusValue? metaValue;
      DBusValue? statusValue;
      DBusValue? posValue;

      // If we have a signal, extract the properties directly from it
      if (signal != null && signal.values.length >= 2) {
        final changedProps = signal.values[1].asStringVariantDict();
        metaValue = changedProps['Metadata'];
        statusValue = changedProps['PlaybackStatus'];
        posValue = changedProps['Position'];
      }

      // If properties weren't in the signal (or no signal), fetch them manually
      metaValue ??= await object.getProperty('org.mpris.MediaPlayer2.Player', 'Metadata');
      statusValue ??= await object.getProperty('org.mpris.MediaPlayer2.Player', 'PlaybackStatus');
      posValue ??= await object.getProperty('org.mpris.MediaPlayer2.Player', 'Position');

      final statusStr = statusValue.asString();

      // A player that starts Playing always becomes active.
      // A player that stops should only clear the active slot if it *was* active.
      if (_activePlayerName != name) {
        // A player becomes active if it starts 'Playing' OR if no player is currently active.
        if (statusStr == 'Playing' || _activePlayerName == null) {
          debugPrint('Active player switched/assigned: $_activePlayerName → $name');
          
          // Reset dirty cache so the new player's state is always pushed
          _lastInfo = null;
          
          // Force art re-fetch for the newly active player by clearing its cached URL.
          // This ensures that even if this player was monitored in the background 
          // previously, its art is re-sent to the client now that it is active.
          _lastArtUrlPerPlayer.remove(name);
          
          _activePlayerName = name;
        }
      }

      if (_activePlayerName == name && statusStr != 'Playing') {
        // The currently active player paused/stopped. Look for another playing player.
        // We don't clear _activePlayerName immediately ,we let it stay so controls
        // still work until another player takes over. But we do stop pushing its
        // stale state as "the" update.
      }

      // Only push updates to the client when this player is (or has become) active.
      // We still need to process the event to detect play/pause switches above, but
      // we skip sending the data if this is a background (non-active) player.
      final isActive = (_activePlayerName == name) || (_activePlayerName == null);

      if (!isActive) {
        debugPrint('Ignoring update from background player: $name (active: $_activePlayerName)');
        return;
      }

      // --- Active Player Handling ---

      final data = metaValue.asStringVariantDict();
      final rawArtUrl = data['mpris:artUrl']?.asString() ?? '';
      String processedArtBase64 = "";

      // Using per-player art URL cache so switching players always re-sends art
      final lastArtUrlForThisPlayer = _lastArtUrlPerPlayer[name] ?? '';

      if (rawArtUrl.isNotEmpty && rawArtUrl != lastArtUrlForThisPlayer) {
        final bytes = await _fetchRawBytes(rawArtUrl);
        if (bytes != null) {
          processedArtBase64 = await compute(_processAlbumArt, bytes);
          _lastArtUrlPerPlayer[name] = rawArtUrl;
        } else {
          debugPrint("Poller: Failed to fetch bytes for: $rawArtUrl");
        }
      }
      final isNewArt = processedArtBase64.isNotEmpty;

      // Check cache
      final newInfo = (_lastInfo ?? MediaInfo.empty).copyWith(
        status: statusStr,
        title: data['xesam:title']?.asString() ?? 'Unknown',
        album: data['xesam:album']?.asString() ?? 'Unknown',
        artist: data['xesam:artist']?.asStringArray().join(', ') ?? 'Unknown Artist',
        duration: safeExtractInt(data['mpris:length']) ~/ 1000000,
        position: safeExtractInt(posValue) ~/ 1000000,
        albumArtBase64: isNewArt ? processedArtBase64 : null,
      );

      // Send Updates
      if (!newInfo.isSameAs(_lastInfo) || isNewArt) {
        _lastInfo = newInfo;
        onSend('music', 'update_metadata', newInfo.toMap(includeArt: isNewArt));
      }

      debugPrint("Data updated from active player [$name]: ${newInfo.title} (${newInfo.status})");

    } catch (e) {
      debugPrint("Info unavailable (likely song transition) for $name: $e");
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
      // spotify sends string instead of DBusObjectPath
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

  void control(Map<String, dynamic> args) {
    _control(args);
  }

  Future<void> _control(Map<String, dynamic> args) async {
    // Use the cached player
    final targetName = _activePlayerName ?? _players.keys.firstOrNull;
    final targetPlayer = _players[targetName];

    if (targetPlayer == null) return;

    try {
      String method = '';
      if (args['method'] == 'next') {method = 'Next';}
      else if (args['method'] == 'previous') {method = 'Previous';}
      else if (args['method'] == 'play_pause') {method = 'PlayPause';}
      else if (args['method'] == 'seek') {seek(args["position"]); return;}

      // don't await for immediate response
      targetPlayer.callMethod('org.mpris.MediaPlayer2.Player', method, [])
        .then((_) => debugPrint("Sent $method to $targetName"))
        .catchError((e) {
          debugPrint("Failed to send $method: $e");
          _activePlayerName = null;
        });
    } catch (e) {
      debugPrint("Failed to send $args['method']: $e");
      _activePlayerName = null;
    }
  }

  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _players.clear();
    _lastArtUrlPerPlayer.clear();
    _client?.close();
    _client = null;
    _lastInfo = null;
    _activePlayerName = null;
  }

  // helper function to support multiple dbus types
  int safeExtractInt(DBusValue? value) {
    if (value == null) return 0;
    if (value is DBusInt64) return value.value;
    if (value is DBusUint64) return value.value;
    if (value is DBusInt32) return value.value;
    if (value is DBusUint32) return value.value;
    return 0;
  }
}

// ----  Hereon there is album art fetching system  ----

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
    
    final thumbnail = img.copyResize(image, 
      width: 200, 
      interpolation: img.Interpolation.average,
    );

    
    final jpg = img.encodeJpg(thumbnail, quality: 100);
    return base64Encode(jpg);
  }, bytes);
}
