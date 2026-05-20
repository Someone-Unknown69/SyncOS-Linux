import 'dart:convert';
import 'package:flutter/material.dart';
import 'music.dart';
import 'usb_controller.dart';
import 'file_transfer.dart';

// Metadata class
class MediaMetadata {
  final String title;
  final String artist;
  final String album;
  final String albumArt;
  final String status;
  final int position;
  final int duration;
  final double volume;

  const MediaMetadata({
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArt,
    required this.status,
    required this.position,
    required this.duration,
    required this.volume,
  });

  factory MediaMetadata.initial() {
    return const MediaMetadata(
      title: "Unknown",
      artist: "Unknown",
      album: "Unknown",
      albumArt: "N/A",
      status: "Playing",
      volume: 0.0,
      position: 0,
      duration: 0,
    );
  }
  
  MediaMetadata copyWith({
    String? title, 
    String? artist, 
    String? album, 
    String? albumArt, 
    String? status,
    double? volume,
    int? position,
    int? duration,
    }) {
    return MediaMetadata(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArt: albumArt ?? this.albumArt,
      status: status ?? this.status,
      volume: volume ?? this.volume,
      duration: duration ?? this.duration,
      position: position ?? this.position
    );
  }
}


class HandleRequest {
  static final HandleRequest _instance = HandleRequest._internal();
  factory HandleRequest() => _instance;

  HandleRequest._internal() {
    _handlers = {
      "battery_info": _handleBattery,
      "music": _handleMusic,
      "controller" : _handleController,
      "file_transfer": _handleFTP,
      'device_info': _handleDeviceInfo
    };
  }

  // Map of op to the handler functions
  late final Map<String, Function(Map<String, dynamic>)> _handlers;
  MediaPoller? _mediaPoller;

  /// Device Information
  final ValueNotifier<double> batteryLevel = ValueNotifier<double>(0);
  final ValueNotifier<String> deviceName = ValueNotifier<String>("Unknown");
  final ValueNotifier<bool> isCharging = ValueNotifier<bool>(false);
  final ValueNotifier<double> volume = ValueNotifier<double>(0);
  
  final ValueNotifier<MediaMetadata> metadata = ValueNotifier(MediaMetadata.initial());

  // Optimistic update for UI responsiveness
  void updateStatus(String newStatus) {
    metadata.value = metadata.value.copyWith(status: newStatus);
  }

  void setMediaPoller(MediaPoller mediaPoller) {
    _mediaPoller = mediaPoller;
  }

  void handle(String rawJson) {
    try {
      final data = jsonDecode(rawJson);
      final op = data['op'];

      if (_handlers.containsKey(op)) {
        _handlers[op]!(data);
      } else {
        debugPrint("Unknown operation: $op");
      }
    } catch (e) {
      debugPrint("Routing error: $e");
    }
  }

  // ---------------------------     Individual Handler Logics      ---------------------------------

  void _handleBattery(Map<String, dynamic> data) {
    final args = data['args'];
    batteryLevel.value = ((args['level'] as num? ?? 0).toDouble() / 100.0);
    isCharging.value = args['status'] ?? false;
  }

  void _handleDeviceInfo(Map<String, dynamic> data) {
    final args = data['args'];
    deviceName.value = args['name'] ?? "Unknown";
  }

  void _handleMusic(Map<String, dynamic> data) {
    final action = data['action'];
    final args = data['args'];

    if(action == 'update_metadata') {
      debugPrint("Updated metadata recieved : $args");

      final newTitle = args['title'] ?? 'Unknown';
      final oldTitle = metadata.value.title;

      // Dirty cache
      if (newTitle == 'Unknown' && oldTitle != 'Unknown') {
        metadata.value = metadata.value.copyWith(
          status: args['status'],
          volume: args['volume'],
          duration: args['duration'],
          position: args['position'],
          albumArt: args['albumArt'] ?? metadata.value.albumArt,
        );
        return;
      }
      
      metadata.value = metadata.value.copyWith(
        title: newTitle,
        artist: args['artist'],
        album: args['album'],
        status: args['status'],
        volume: args['volume'],
        duration: args['duration'],
        position: args['position'],
        albumArt: args['albumArt'] ?? metadata.value.albumArt,
      );

    } else if (action == 'control') {
      if(_mediaPoller != null) {
        _mediaPoller!.control(args);
      } else {
        debugPrint('[Handle music] Error: MediaPoller not set in HandleRequest');
      }
    }
  }

  void _handleController(Map<String, dynamic> data) {
    final action = data['action'];
    final args = data['args'];
    if (action != null) {
      if (action == 'left_analog') {
        ControllerService().updateLeftStick(args['x'], args['y']);
      } else if (action == 'right_analog') {
        ControllerService().updateRightStick(args['x'], args['y']);
      } else if (action == 'triggers') {
        ControllerService().updateTriggers(args['l2'], args['r2']);
      } else if (action == 'dpad') {
        ControllerService().updateDpad(args['x'], args['y']);
      } else {
        ControllerService().keyPress(action, args['button']);
      }
    }
  }

  void _handleFTP(Map<String, dynamic> data) {
    final action = data['action'];
    final args = data['args'];

    if(action == 'send') {
      // file requested from other device
      // will add later
    } else if (action == 'recieve') {
      debugPrint('$args');
      FileTransfer().recieveFile(args);
    } else {
      debugPrint('[Handler FTP] Invalid action');
    }
  }

}
