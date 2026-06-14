// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:io';
import 'dart:convert';
import 'package:dbus/dbus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:syncos_linux/core/media/domain/i_media_notification.dart';
import 'package:syncos_linux/features/media/provider/remote_media_state.dart';
import 'package:syncos_linux/models/media_metadata.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

class MprisService extends DBusObject implements IMediaNotification{
  final DBusClient _client;
  final Ref _ref;

  MprisService(this._client, this._ref) : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  final String serviceName = 'org.mpris.MediaPlayer2.SyncOSPlayer';
  MediaInfo _currentMetadata = MediaInfo.empty;

  bool _initialized = false;
  Future<void>? _initFuture;

  // cache and pooling for time
  String? _lastArtPath;
  DateTime? _playbackStartedAt;
  double _basePositionSeconds = 0.0;

  @override
  Future<void> init() async {
    if (_initialized) return;
    if (_initFuture != null) return _initFuture!;

    _initFuture = () async {
      try {
        await _client.releaseName(serviceName);
      } catch (e) {
        debugPrint("[MPRIS] service release failed : $e");
      }

      await _client.registerObject(this);
      await _client.requestName(serviceName);
      _initialized = true;
      debugPrint("[MPRIS] Service initialized at $serviceName");
    }();

    try {
      await _initFuture;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if(methodCall.interface == 'org.mpris.MediaPlayer2' && methodCall.name == 'Raise') {
      debugPrint("[MPRIS] Raise Requested");
      return DBusMethodSuccessResponse([]);
    }

    if (methodCall.interface == 'org.freedesktop.DBus.Properties' && methodCall.name == 'Get') {
      String interface = methodCall.values[0].asString();
      String property = methodCall.values[1].asString();
      return await getProperty(interface, property);
    }

    if (methodCall.interface == 'org.mpris.MediaPlayer2.Player') {
    final notifier = _ref.read(musicProvider.notifier);
    switch (methodCall.name) {
        case 'Play':
          notifier.togglePlayPause();
          return DBusMethodSuccessResponse([]);

        case 'Pause':
          notifier.togglePlayPause();
          return DBusMethodSuccessResponse([]);

        case 'PlayPause':
          notifier.togglePlayPause();
          return DBusMethodSuccessResponse([]);

        case 'Next':
          notifier.next();
          return DBusMethodSuccessResponse([]);

        case 'Previous':
          notifier.previous();
          return DBusMethodSuccessResponse([]);

        case 'Seek':
          final int offsetUs = methodCall.values[0].asInt64();
          final double currentPosSec = getCalculatedPositionSeconds();
          final int targetPosSec = (currentPosSec + (offsetUs / 1000000)).toInt();
          
          notifier.seek(targetPosSec);
          return DBusMethodSuccessResponse([]);

        case 'SetPosition':
          final int positionUs = methodCall.values[1].asInt64();
          final int targetSeconds = (positionUs / 1000000).toInt();
          
          notifier.seek(targetSeconds);
          return DBusMethodSuccessResponse([]);
      }
    }

    return DBusMethodErrorResponse.unknownMethod();
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface == 'org.mpris.MediaPlayer2') {
      switch (name) {
        case 'Identity': return DBusGetPropertyResponse(DBusString('Sync OS Media Player'));
        case 'CanQuit': return DBusGetPropertyResponse(DBusBoolean(true));
        case 'DesktopEntry': return DBusGetPropertyResponse(DBusString('syncos-media-player'));
      }
    }

    if (interface == 'org.mpris.MediaPlayer2.Player') {
      switch (name) {
        case 'Position':
          final posUs = (getCalculatedPositionSeconds() * 1000000).toInt();
          return DBusGetPropertyResponse(DBusInt64(posUs));
          
        case 'PlaybackStatus':
          return DBusGetPropertyResponse(DBusString(_currentMetadata.status));
          
        case 'Metadata':
          return DBusGetPropertyResponse(DBusDict(
            DBusSignature('s'),
            DBusSignature('v'),
            {
              DBusString('xesam:title'): DBusVariant(DBusString(_currentMetadata.title)),
              DBusString('xesam:artist'): DBusVariant(DBusArray.string([_currentMetadata.artist])), // Artists are typically an array
              DBusString('mpris:trackid'): DBusVariant(DBusObjectPath('/org/mpris/MediaPlayer2/Track/0')),
              DBusString('mpris:length'): DBusVariant(DBusInt64(_currentMetadata.duration * 1000000)),
              if (_lastArtPath != null)
                DBusString('mpris:artUrl'): DBusVariant(DBusString(_lastArtPath!)),
            },
          ));
      }
    }

    return DBusMethodErrorResponse(
      'org.freedesktop.DBus.Error.InvalidArgs',
      [DBusString('Property $name does not exist')],
    );
  }

  Future<void> propertyChange(
    String interface, 
    String property, 
    DBusValue value
  ) async {
    await _client.emitSignal(
      path: DBusObjectPath('/org/mpris/MediaPlayer2'), 
      interface: 'org.freedesktop.DBus.Properties', 
      name: 'PropertiesChanged',
      values: [
        DBusString(interface),
        DBusDict(DBusSignature('s'), DBusSignature('v'), {
          DBusString(property): DBusVariant(value),
        }),

        DBusArray.string([]), // Properties that were removed (always empty for simple changes)
      ]
    );
  }

  @override
  Future<void> updateMetadata(MediaInfo meta) async {
    _currentMetadata = meta;
    final artUri = await _getArtUrl(meta.albumArtBase64);

    setPlaybackState(meta.status == 'Playing', meta.position.toDouble());

    // MediaMetadata stores position/duration in seconds (as used by the UI).
    // MPRIS requires microseconds, so we convert here
    final int durationUs = meta.duration * 1000000;

    final Map<DBusString, DBusVariant> dbusMetadata = {
      DBusString('xesam:title'): DBusVariant(DBusString(meta.title)),
      DBusString('xesam:artist'): DBusVariant(DBusArray.string([meta.artist])),
      DBusString('xesam:album'): DBusVariant(DBusString(meta.album)),
      DBusString('mpris:length'): DBusVariant(DBusInt64(durationUs)),
      DBusString('mpris:trackid'): DBusVariant(DBusObjectPath('/org/mpris/MediaPlayer2/Track/0')),
    };

    if (artUri != null) {
      dbusMetadata[DBusString('mpris:artUrl')] = DBusVariant(DBusString(artUri));
    }

    await _client.emitSignal(
      path: DBusObjectPath('/org/mpris/MediaPlayer2'),
      interface: 'org.freedesktop.DBus.Properties',
      name: 'PropertiesChanged',
      values: [
        DBusString('org.mpris.MediaPlayer2.Player'),
        DBusDict(DBusSignature('s'), DBusSignature('v'), {
          DBusString('Metadata'): DBusVariant(DBusDict(
            DBusSignature('s'), 
            DBusSignature('v'), 
            dbusMetadata
          )),
          DBusString('PlaybackStatus'): DBusVariant(DBusString(meta.status)),

          DBusString('CanGoNext'): DBusVariant(DBusBoolean(true)),
          DBusString('CanGoPrevious'): DBusVariant(DBusBoolean(true)),
          DBusString('CanPlay'): DBusVariant(DBusBoolean(true)),
          DBusString('CanPause'): DBusVariant(DBusBoolean(true)),
          DBusString('CanSeek'): DBusVariant(DBusBoolean(true)),
        }),
        DBusArray.string([]),
      ],
    );

    await emitSeeked(meta.position.toDouble());
  }

  Future<void> emitSeeked(double positionSeconds) async {
    final int positionUs = (positionSeconds * 1000000).toInt();
    
    await _client.emitSignal(
      path: DBusObjectPath('/org/mpris/MediaPlayer2'),
      interface: 'org.mpris.MediaPlayer2.Player',
      name: 'Seeked',
      values: [DBusInt64(positionUs)],
    );
  }


  Future<String?> _getArtUrl(String base64Art) async {
    if (base64Art.isEmpty) return null;

    try {
      final directory = Directory('/tmp/album_art');
      if (!await directory.exists()) await directory.create(recursive: true);

      final file = File('${directory.path}/current_art.jpg');

      // Sanitize base64 string directly (strip header and apply padding)
      String cleanBase64 = base64Art.contains(',') ? base64Art.split(',')[1] : base64Art;
      final remainder = cleanBase64.length % 4;
      if (remainder > 0) {
        cleanBase64 += '=' * (4 - remainder);
      }

      final bytes = base64Decode(cleanBase64);
      await file.writeAsBytes(bytes);

      _lastArtPath = 'file://${file.path}';
      return _lastArtPath;
    } catch (e) {
      debugPrint('[MPRIS] Error while decoding album art : $e');
      return null;
    }
  }

  void setPlaybackState(bool isPlaying, double positionSeconds) {
    if (isPlaying) {
      _playbackStartedAt = DateTime.now();
      _basePositionSeconds = positionSeconds;
    } else {
      // Calculate current position inline before resetting the timestamp
      if (_playbackStartedAt != null) {
        final elapsed = DateTime.now().difference(_playbackStartedAt!).inMicroseconds / 1000000;
        _basePositionSeconds += elapsed;
      } else {
        _basePositionSeconds = positionSeconds;
      }

      _playbackStartedAt = null;
    }
  }

  double getCalculatedPositionSeconds() {
    if (_playbackStartedAt == null) return _basePositionSeconds;
    final elapsed = DateTime.now().difference(_playbackStartedAt!).inMicroseconds / 1000000;
    return _basePositionSeconds + elapsed;
  }

  @override
  Future<void> reset() async {
    debugPrint("[MPRIS] Music stopped Clearing Notification");
    
    _currentMetadata = MediaInfo.empty;
    _lastArtPath = null;
    _playbackStartedAt = null;
    _basePositionSeconds = 0.0;

    try {
      if (_initialized) {
        await _client.releaseName(serviceName);
        await _client.unregisterObject(this);
        
        _initialized = false;
        _initFuture = null;
        debugPrint("[MPRIS] Service successfully unregistered and closed.");
      }
    } catch (e) {
      debugPrint("[MPRIS] Failed to cleanly unregister MPRIS service from D-Bus: $e");
    }
  }
}
