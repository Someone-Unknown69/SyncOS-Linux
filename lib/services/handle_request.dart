import 'dart:convert';
import 'package:flutter/material.dart';
import 'Music/music_sending.dart';
import 'usb_controller.dart';
import 'file_transfer.dart';
import 'notifications_service.dart';
import 'Music/mpris_service.dart';
import '../models/media_metadata.dart';


class HandleRequest {
  static final HandleRequest _instance = HandleRequest._internal();
  factory HandleRequest() => _instance;

  HandleRequest._internal() {
    _handlers = {
      "battery_info": _handleBattery,
      "music": _handleMusic,
      "controller" : _handleController,
      "file_transfer": _handleFTP,
      'device_info': _handleDeviceInfo,
      'notification': _handleNotification
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
      final newTitle = args['title'] ?? 'Unknown';
      final oldTitle = metadata.value.title;

      // Dirty cache — title is unknown but we had one before, keep old title
      if (newTitle == 'Unknown' && oldTitle != 'Unknown') {
        metadata.value = metadata.value.copyWith(
          status: args['status'],
          volume: args['volume'],
          duration: args['duration'],
          position: args['position'],
          albumArt: args['albumArt'] ?? metadata.value.albumArt,
        );
      } else {
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
      }

      MprisService.instance.updateMetadata(metadata.value);

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
      debugPrint('[Handle FTP]$args');
      FileTransfer().recieveFile(args);
    } else {
      debugPrint('[Handle FTP] Invalid action');
    }
  }
  
  void _handleNotification(Map<String, dynamic> data) {
    final action = data['action'];
    final args = data['args'];

    if(action == 'receive') {
      DateTime timestamp = DateTime.now();
      if (args['timestamp'] != null) {
        try {
          timestamp = DateTime.parse(args['timestamp'].toString());
        } catch (_) {}
      }

      NotificationService().addNotification(
        args['app'] ?? 'Unknown',
        args['body'] ?? 'No content',
        timestamp,
        args['color'] ?? 0xFF2196F3
      );
    } else {
      debugPrint('[Handle Notifications] Invalid action');
    }
  }

}
