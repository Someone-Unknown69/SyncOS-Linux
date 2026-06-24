// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:dbus/dbus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:syncos_linux/core/media/domain/i_media_notification.dart';
import 'package:syncos_linux/core/misc/app_logging.dart';
import 'package:syncos_linux/features/media/data/remote_media_service.dart';
import 'package:syncos_linux/features/media/domain/models/media_info.dart';

class MprisService extends DBusObject implements IMediaNotification {
  final DBusClient _client;
  final RemoteMediaService _remoteMediaService;

  StreamSubscription? _subscription;

  MprisService(this._client, this._remoteMediaService)
    : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  final String serviceName = 'org.mpris.MediaPlayer2.SyncOSPlayer';
  MediaInfo _currentMetadata = MediaInfo.empty;

  bool isActiveNotif = false;
  Future<void>? _initFuture;

  // cache and pooling for time
  DateTime? _playbackStartedAt;
  double _basePositionSeconds = 0.0;

  @override
  Future<void> start() async {
    _subscription = _remoteMediaService.mediaUpdates.listen((info) async {
      if (info.isValid && !isActiveNotif) {
        await _displayNotif();
        isActiveNotif = true;
      } else if (!info.isValid && isActiveNotif) {
        await _removeNotif();
        isActiveNotif = false;
      }

      if (isActiveNotif) {
        _updateMetadata(info);
      }
    });
    logDebug('Media Notification', 'Initialized');
  }

  Future<void> _displayNotif() async {
    if (_initFuture != null) return _initFuture!;

    _initFuture = () async {
      try {
        await _client.releaseName(serviceName);
      } catch (e) {
        debugPrint("[MPRIS] service release failed : $e");
      }

      await _client.registerObject(this);
      await _client.requestName(serviceName);
      isActiveNotif = true;
      debugPrint("[MPRIS] Service initialized at $serviceName");
    }();

    try {
      await _initFuture;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<void> _updateMetadata(MediaInfo meta) async {
    _currentMetadata = meta;
    final artUri = meta.albumArtUri.toString();
    setPlaybackState(meta.status ?? false, (meta.position ?? 0) / 1000.0);

    // MediaMetadata stores position/duration in seconds (as used by the UI).
    // MPRIS requires microseconds, so we convert here
    final int durationUs = (meta.duration ?? 0) * 1000;

    final Map<DBusString, DBusVariant> dbusMetadata = {
      DBusString('xesam:title'): DBusVariant(
        DBusString(meta.title ?? 'Unknown Title'),
      ),
      DBusString('xesam:artist'): DBusVariant(
        DBusArray.string([meta.artist ?? 'Unknown Artist']),
      ),
      DBusString('xesam:album'): DBusVariant(
        DBusString(meta.album ?? 'Unknown Album'),
      ),
      DBusString('mpris:length'): DBusVariant(DBusInt64(durationUs)),
      DBusString('mpris:trackid'): DBusVariant(
        DBusObjectPath('/org/mpris/MediaPlayer2/Track/0'),
      ),
    };

    if (artUri.isNotEmpty) {
      dbusMetadata[DBusString('mpris:artUrl')] = DBusVariant(
        DBusString(artUri),
      );
    }

    await _client.emitSignal(
      path: DBusObjectPath('/org/mpris/MediaPlayer2'),
      interface: 'org.freedesktop.DBus.Properties',
      name: 'PropertiesChanged',
      values: [
        DBusString('org.mpris.MediaPlayer2.Player'),
        DBusDict(DBusSignature('s'), DBusSignature('v'), {
          DBusString('Metadata'): DBusVariant(
            DBusDict(DBusSignature('s'), DBusSignature('v'), dbusMetadata),
          ),
          DBusString('PlaybackStatus'): DBusVariant(
            DBusString((meta.status == true) ? 'Playing' : 'Paused'),
          ),

          DBusString('CanGoNext'): DBusVariant(DBusBoolean(true)),
          DBusString('CanGoPrevious'): DBusVariant(DBusBoolean(true)),
          DBusString('CanPlay'): DBusVariant(DBusBoolean(true)),
          DBusString('CanPause'): DBusVariant(DBusBoolean(true)),
          DBusString('CanSeek'): DBusVariant(DBusBoolean(true)),
        }),
        DBusArray.string([]),
      ],
    );

    await emitSeeked(meta.position?.toDouble() ?? 0.0);
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface == 'org.mpris.MediaPlayer2' &&
        methodCall.name == 'Raise') {
      debugPrint("[MPRIS] Raise Requested");
      return DBusMethodSuccessResponse([]);
    }

    if (methodCall.interface == 'org.freedesktop.DBus.Properties' &&
        methodCall.name == 'Get') {
      String interface = methodCall.values[0].asString();
      String property = methodCall.values[1].asString();
      return await getProperty(interface, property);
    }

    if (methodCall.interface == 'org.mpris.MediaPlayer2.Player') {
      switch (methodCall.name) {
        case 'Play':
          _remoteMediaService.playPauseToggle();
          return DBusMethodSuccessResponse([]);

        case 'Pause':
          _remoteMediaService.playPauseToggle();
          return DBusMethodSuccessResponse([]);

        case 'PlayPause':
          _remoteMediaService.playPauseToggle();
          return DBusMethodSuccessResponse([]);

        case 'Next':
          _remoteMediaService.next();
          return DBusMethodSuccessResponse([]);

        case 'Previous':
          _remoteMediaService.previous();
          return DBusMethodSuccessResponse([]);

        case 'Seek':
          final int offsetUs = methodCall.values[0].asInt64();
          final double currentPosSec = getCalculatedPositionSeconds();
          final int targetPosSec = (currentPosSec + (offsetUs / 1000000))
              .toInt();

          _remoteMediaService.sendSeek(targetPosSec);
          return DBusMethodSuccessResponse([]);

        case 'SetPosition':
          final int positionUs = methodCall.values[1].asInt64();
          final int targetSeconds = (positionUs / 1000000).toInt();

          _remoteMediaService.sendSeek(targetSeconds);
          return DBusMethodSuccessResponse([]);
      }
    }

    return DBusMethodErrorResponse.unknownMethod();
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface == 'org.mpris.MediaPlayer2') {
      switch (name) {
        case 'Identity':
          return DBusGetPropertyResponse(DBusString('Sync OS Media Player'));
        case 'CanQuit':
          return DBusGetPropertyResponse(DBusBoolean(true));
        case 'DesktopEntry':
          return DBusGetPropertyResponse(DBusString('syncos-media-player'));
      }
    }

    if (interface == 'org.mpris.MediaPlayer2.Player') {
      switch (name) {
        case 'Position':
          final posUs = (getCalculatedPositionSeconds() * 1000000).toInt();
          return DBusGetPropertyResponse(DBusInt64(posUs));

        case 'PlaybackStatus':
          return DBusGetPropertyResponse(
            DBusString(
              ((_currentMetadata.status ?? false) ? 'Playing' : 'Paused'),
            ),
          );

        case 'Metadata':
          return DBusGetPropertyResponse(
            DBusDict(DBusSignature('s'), DBusSignature('v'), {
              DBusString('xesam:title'): DBusVariant(
                DBusString(_currentMetadata.title ?? 'Unknown Title'),
              ),
              DBusString('xesam:artist'): DBusVariant(
                DBusArray.string([_currentMetadata.artist ?? 'Unknown Artist']),
              ),
              DBusString('mpris:trackid'): DBusVariant(
                DBusObjectPath('/org/mpris/MediaPlayer2/Track/0'),
              ),
              DBusString('mpris:length'): DBusVariant(
                DBusInt64((_currentMetadata.duration ?? 0) * 1000000),
              ),
              if (_currentMetadata.albumArtUri != null)
                DBusString('mpris:artUrl'): DBusVariant(
                  DBusString(_currentMetadata.albumArtUri.toString()),
                ),
            }),
          );
      }
    }

    return DBusMethodErrorResponse('org.freedesktop.DBus.Error.InvalidArgs', [
      DBusString('Property $name does not exist'),
    ]);
  }

  Future<void> propertyChange(
    String interface,
    String property,
    DBusValue value,
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

        DBusArray.string(
          [],
        ), // Properties that were removed (always empty for simple changes)
      ],
    );
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

  void setPlaybackState(bool isPlaying, double positionSeconds) {
    if (isPlaying) {
      _playbackStartedAt = DateTime.now();
      _basePositionSeconds = positionSeconds;
    } else {
      // Calculate current position inline before resetting the timestamp
      if (_playbackStartedAt != null) {
        final elapsed =
            DateTime.now().difference(_playbackStartedAt!).inMicroseconds /
            1000000;
        _basePositionSeconds += elapsed;
      } else {
        _basePositionSeconds = positionSeconds;
      }

      _playbackStartedAt = null;
    }
  }

  double getCalculatedPositionSeconds() {
    if (_playbackStartedAt == null) return _basePositionSeconds;
    final elapsed =
        DateTime.now().difference(_playbackStartedAt!).inMicroseconds / 1000000;
    return _basePositionSeconds + elapsed;
  }

  @override
  void stop() {}

  Future<void> _removeNotif() async {
    debugPrint("[MPRIS] Music stopped Clearing Notification");

    _currentMetadata = MediaInfo.empty;
    _subscription?.cancel();
    _subscription = null;
    _playbackStartedAt = null;
    _basePositionSeconds = 0.0;

    try {
      if (isActiveNotif) {
        await _client.releaseName(serviceName);
        await _client.unregisterObject(this);

        isActiveNotif = false;
        _initFuture = null;
        debugPrint("[MPRIS] Service successfully unregistered and closed.");
      }
    } catch (e) {
      debugPrint(
        "[MPRIS] Failed to cleanly unregister MPRIS service from D-Bus: $e",
      );
    }
  }
}
