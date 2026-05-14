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

  // edit this to add or remove service handlers
  HandleRequest._internal() {
    _handlers = {
      "battery_info": _handleBattery,
      "music": _handleMusic,
      "controller" : _handleController,
      "file_transfer": _handleFTP,
    };
  }

  // Map of op to the handler functions
  late final Map<String, Function(Map<String, dynamic>)> _handlers;
  MediaPoller? _mediaPoller;

  /// Device Information
  final ValueNotifier<int> batteryLevel = ValueNotifier<int>(0);
  final ValueNotifier<String> deviceName = ValueNotifier<String>("Unknown");
  final ValueNotifier<bool> isCharging = ValueNotifier<bool>(false);
  
  final ValueNotifier<MediaMetadata> metadata = ValueNotifier(MediaMetadata.initial());

  void setMediaPoller(MediaPoller mediaPoller) {
    _mediaPoller = mediaPoller;
  }

  void handle(String rawJson) {
    try {
      // Handle plain text commands (PING, ACCEPTED, REJECTED, etc.)
      if (rawJson == "PING") {
        debugPrint("Received PING from client");
        return;
      }
      if (rawJson == "ACCEPTED" || rawJson == "REJECTED") {
        debugPrint("Received handshake response: $rawJson");
        return;
      }

      // Parse as JSON for regular commands
      final data = jsonDecode(rawJson);
      final op = data['op'];

      if (_handlers.containsKey(op)) {
        _handlers[op]!(data);
      } else {
        debugPrint("Unknown operation: $op");
      }
    } catch (e) {
      debugPrint("Error in handling Command $e");
    }
  }

  // ---------------------------     Individual Handler Logics      ---------------------------------

  void _handleBattery(Map<String, dynamic> data) {
    final args = data['args'];
    batteryLevel.value = args['level'] ?? 0;
    isCharging.value = args['status'] ?? false;
    deviceName.value = args['device'] ?? "Unknown";
  }


  void _handleMusic(Map<String, dynamic> data) {
    final action = data['action'];
    final args = data['args'];

    if(action == 'update_metadata') {
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
    if(action != null) {
      ControllerService().keyPress(action, args['button']);
    }
  }

  void _handleFTP(Map<String, dynamic> data) {
    final action = data['action'];
    final args = data['args'];

    if(action == 'send') {
      // file requested from other device
      // will add later
    } else if (action == 'recieve') {
      FileTransfer().recieveFile(args);
    } else {
      debugPrint('[Handler FTP] Invalid action');
    }
  }

}
