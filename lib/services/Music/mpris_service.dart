import 'package:dbus/dbus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/media_metadata.dart';

class MprisService extends DBusObject{
  MprisService._internal() : super(DBusObjectPath('/org/mpris/MediaPlayer2'));
  static final MprisService instance = MprisService._internal();


  final String serviceName = 'org.mpris.MediaPlayer2.SyncOSPlayer';
  late DBusClient _client;
  MediaMetadata _currentMetadata = MediaMetadata.initial();

  Future<void> init() async {
    _client = DBusClient.session();

    try {
      await _client.releaseName(serviceName);
    } catch (e) {
      debugPrint("[MPRIS] service release failed : $e");
    }

    await _client.registerObject(this);
    await _client.requestName(serviceName);
    debugPrint("[MPRIS] Service initialized at $serviceName");
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
    switch (methodCall.name) {
      case 'Play':
        debugPrint("[MPRIS] Action: Play");
        // call the logic
        return DBusMethodSuccessResponse([]);
        
      case 'Pause':
        debugPrint("[MPRIS] Action: Pause");
        // call tha logic
        return DBusMethodSuccessResponse([]);
        
      case 'PlayPause':
        debugPrint("[MPRIS] Action: PlayPause toggle");
        return DBusMethodSuccessResponse([]);
      }
    }

    return DBusMethodErrorResponse.unknownMethod();
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    
    /// properties for the main MediaPlayer2 interface
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

    /// properties for the Player interface (Where music data lives)
    if (interface == 'org.mpris.MediaPlayer2.Player') {
      switch (name) {
        case 'Position':
          if (_currentMetadata.title == "Unknown") {
            // Return 0 instead of throwing an error if the track is not loaded
            return DBusGetPropertyResponse(DBusInt64(0));
          }
          return DBusGetPropertyResponse(DBusInt64(_currentMetadata.position));
        case 'PlaybackStatus':
          return DBusGetPropertyResponse(DBusString('Playing'));
        case 'Volume':
          return DBusGetPropertyResponse(DBusDouble(0.5));
        case 'Metadata':
          // Metadata is a Dictionary (Map)
          return DBusGetPropertyResponse(DBusDict(
            DBusSignature('s'), // Key signature (String)
            DBusSignature('v'), // Value signature (Variant)
            {
              DBusString('xesam:title'): DBusVariant(DBusString('Song Name')),
              DBusString('xesam:artist'): DBusVariant(DBusArray.string(['Artist Name'])),
              DBusString('mpris:trackid'): DBusVariant(DBusObjectPath('/org/mpris/MediaPlayer2/Track/0')),
              DBusString('mpris:length'): DBusVariant(DBusInt64(240000000)),
              DBusString('mpris:artUrl'): DBusVariant(DBusString('file:///tmp/album-art.jpg')),
              DBusString('mpris:position'): DBusVariant(DBusInt64(100000000)),
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

  Future<void> updateMetadata(MediaMetadata meta) async {
    _currentMetadata = meta;

    // MediaMetadata stores position/duration in seconds (as used by the UI).
    // MPRIS requires microseconds, so we convert here
    final int positionUs = meta.position * 1000000;
    final int durationUs = meta.duration * 1000000;

    final Map<DBusString, DBusVariant> dbusMetadata = {
      DBusString('xesam:title'): DBusVariant(DBusString(meta.title)),
      DBusString('xesam:artist'): DBusVariant(DBusArray.string([meta.artist])),
      DBusString('xesam:album'): DBusVariant(DBusString(meta.album)),
      DBusString('mpris:length'): DBusVariant(DBusInt64(durationUs)),
      DBusString('mpris:position'): DBusVariant(DBusInt64(positionUs)),
      DBusString('mpris:trackid'): DBusVariant(DBusObjectPath('/org/mpris/MediaPlayer2/Track/0')),
      // Only add artUrl if it exists
      if (meta.albumArt.isNotEmpty) 
        DBusString('mpris:artUrl'): DBusVariant(DBusString(meta.albumArt)),
    };

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
        }),
        DBusArray.string([]),
      ],
    );
  }

  Future<void> dispose() async {
    try {
      await _client.releaseName(serviceName);
      await _client.unregisterObject(this);
      _client.close();
    } catch (e) {
      debugPrint("[MPRIS] Error during disposal: $e");
    }
  }
}
