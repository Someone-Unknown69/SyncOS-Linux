// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:syncos_linux/core/media/domain/i_local_media_info.dart';
import 'package:syncos_linux/core/misc/app_logging.dart';
import 'package:syncos_linux/features/media/domain/models/media_info.dart';

class MediaPoller implements ILocalMediaInfo {
  DBusClient? _client;
  final Map<String, DBusRemoteObject> _players = {};
  final List<StreamSubscription> _subscriptions = [];

  // Per-player art URL cache so switching players always re-sends art
  final Map<String, String> _lastArtUrlPerPlayer = {};

  String? _activePlayerName;

  final StreamController<MediaInfo> _metadataController =
      StreamController<MediaInfo>.broadcast();

  @override
  Stream<MediaInfo> get metadataStream => _metadataController.stream;

  // We will exclude our defined mpris service so that the app shall not display it's own music service
  // this will guarentee a healthy relationship between our mobile side and laptop side music service
  //
  // what is a healthy relationship?
  // I don't know son... we are fumblers (dead rose emoji)
  static const String myServiceName = 'org.mpris.MediaPlayer2.SyncOSPlayer';

  @override
  Future<void> start() async {
    logDebug('MediaPoller', 'Initiating');
    if (_client != null) return; // Already running
    _client = DBusClient.session();

    try {
      final names = await _client!.listNames();

      // Filter out our own service here
      final mprisPlayers = names.where(
        (n) => n.startsWith('org.mpris.MediaPlayer2.') && n != myServiceName,
      );

      for (final name in mprisPlayers) {
        _monitorPlayer(name);
      }

      // Watch for new players appearing / old players disappearing on D-Bus
      final nameOwnerSub =
          DBusSignalStream(
            _client!,
            sender: 'org.freedesktop.DBus',
            interface: 'org.freedesktop.DBus',
            name: 'NameOwnerChanged',
          ).listen((signal) {
            if (signal.values.length < 3) return;
            final serviceName = (signal.values[0] as DBusString).value;
            final newOwner = (signal.values[2] as DBusString).value;

            if (!serviceName.startsWith('org.mpris.MediaPlayer2.') ||
                serviceName == myServiceName) {
              return;
            }

            if (newOwner.isNotEmpty) {
              // A new MPRIS player just appeared
              debugPrint('New player detected: $serviceName');
              _monitorPlayer(serviceName);
            } else {
              // A player just exited
              debugPrint('Player exited: $serviceName');
              _players.remove(serviceName);
              _lastArtUrlPerPlayer.remove(serviceName);
              if (_activePlayerName == serviceName) {
                // Reset active player, the next PropertiesChanged event from a
                // remaining Playing player will automatically claim the slot.
                _activePlayerName = null;
                debugPrint(
                  'Active player removed; waiting for next active player.',
                );
              }

              // When there are no players explicitly send reset metadata signal
              if (_players.isEmpty) {
                logDebug('Media Poller', 'No players detected');
                final invalidMetadata = MediaInfo(isValid: false);
                _updateMetadata(invalidMetadata);
              }
            }
          });
      _subscriptions.add(nameOwnerSub);
    } catch (e) {
      debugPrint("Failed to start DBus client: $e");
    }
  }

  void _monitorPlayer(String name) {
    if (_client == null) return;
    if (_players.containsKey(name)) return; // Already monitoring

    // Ensure we start with a fresh art fetch for this player when it first becomes active
    _lastArtUrlPerPlayer.remove(name);

    final object = DBusRemoteObject(
      _client!,
      name: name,
      path: DBusObjectPath('/org/mpris/MediaPlayer2'),
    );
    _players[name] = object;

    // Listen for D-Bus property changes
    final sub = DBusSignalStream(
      _client!,
      sender: name,
      interface: 'org.freedesktop.DBus.Properties',
      name: 'PropertiesChanged',
      path: DBusObjectPath('/org/mpris/MediaPlayer2'),
    ).listen((signal) => _formatMetadata(name, signal: signal));

    _subscriptions.add(sub);

    // Send initial state
    _formatMetadata(name);
  }

  Future<void> _formatMetadata(String name, {DBusSignal? signal}) async {
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
      metaValue ??= await object.getProperty(
        'org.mpris.MediaPlayer2.Player',
        'Metadata',
      );
      statusValue ??= await object.getProperty(
        'org.mpris.MediaPlayer2.Player',
        'PlaybackStatus',
      );
      posValue ??= await object.getProperty(
        'org.mpris.MediaPlayer2.Player',
        'Position',
      );

      final statusStr = statusValue.asString();

      // A player that starts Playing always becomes active.
      // A player that stops should only clear the active slot if it *was* active.
      if (_activePlayerName != name) {
        // A player becomes active if it starts 'Playing' OR if no player is currently active.
        if (statusStr == 'Playing' || _activePlayerName == null) {
          debugPrint(
            'Active player switched/assigned: $_activePlayerName → $name',
          );

          // Force art re-fetch for the newly active player by clearing its cached URL.
          // This ensures that even if this player was monitored in the background
          // previously, its art is re-sent to the client now that it is active.
          _lastArtUrlPerPlayer.remove(name);

          _activePlayerName = name;
        }
      }

      if (_activePlayerName == name && statusStr != 'Playing') {
        // The currently active player paused/stopped. Look for another playing player.
        // I don't want to clear _activePlayerName immediately ,I let it stay so controls
        // stilll work until another player takes over. But i do stop pushing its
        // stale state as "the" update.
      }

      // Only push updates to the client when this player is (or has become) active.
      // We still need to process the event to detect play/pause switches above, but
      // we skip sending the data if this is a background (non-active) player.
      final isActive =
          (_activePlayerName == name) || (_activePlayerName == null);

      if (!isActive) {
        debugPrint(
          'Ignoring update from background player: $name (active: $_activePlayerName)',
        );
        return;
      }

      // --- Active Player Handling ---

      final data = metaValue.asStringVariantDict();
      final rawArtUrl = data['mpris:artUrl']?.asString() ?? '';

      final mediaInfo = MediaInfo(
        isValid: true,
        status: (statusStr == 'Playing'),
        title: data['xesam:title']?.asString() ?? 'Unknown',
        album: data['xesam:album']?.asString() ?? 'Unknown',
        artist:
            data['xesam:artist']?.asStringArray().join(', ') ??
            'Unknown Artist',
        duration: safeExtractInt(data['mpris:length']) ~/ 1000000,
        position: safeExtractInt(posValue) ~/ 1000000,
        albumArtUri: Uri.parse(rawArtUrl),
      );

      _updateMetadata(mediaInfo);
    } catch (e) {
      debugPrint("Info unavailable (likely song transition) for $name: $e");
    }
  }

  void _updateMetadata(MediaInfo mediaInfo) {
    _metadataController.add(mediaInfo);
  }

  @override
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
      if (args['method'] == 'next') {
        method = 'Next';
      } else if (args['method'] == 'previous') {
        method = 'Previous';
      } else if (args['method'] == 'play_pause') {
        method = 'PlayPause';
      } else if (args['method'] == 'seek') {
        _seek(args["position"]);
        return;
      }

      // don't await for immediate response
      targetPlayer
          .callMethod('org.mpris.MediaPlayer2.Player', method, [])
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

  Future<void> _seek(int positionSeconds) async {
    final targetName = _activePlayerName ?? _players.keys.firstOrNull;
    final targetPlayer = _players[targetName];

    if (targetPlayer == null) return;

    try {
      final meta = await targetPlayer.getProperty(
        'org.mpris.MediaPlayer2.Player',
        'Metadata',
      );
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

  @override
  void stop() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _players.clear();
    _lastArtUrlPerPlayer.clear();
    _client?.close();
    _client = null;
    _activePlayerName = null;
  }

  @override
  void dispose() {
    stop();
    _metadataController.close();
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
