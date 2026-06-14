// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:syncos_linux/core/media/provider/media_notification_provider.dart';
import 'package:syncos_linux/core/network/provider/connection_provider.dart';
import 'package:syncos_linux/models/media_metadata.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart';

part 'remote_media_state.g.dart';

@Riverpod(keepAlive: true)
class MusicNotifier extends _$MusicNotifier {
  bool _isMediaNotificationInitialized = false;

  @override
  MediaInfo build() {
    ref.onDispose(() {
      _isMediaNotificationInitialized = false;
    });
    return MediaInfo.empty;
  }

  void updateMetadata(Map<String, dynamic> data) async {
    if (!_isMediaNotificationInitialized) {
      _isMediaNotificationInitialized = true;
      try {
        final mediaNotification = await ref.read(mediaNotificationProvider.future);
        await mediaNotification.init();
      } catch (e) {
        _isMediaNotificationInitialized = false;
        debugPrint('[MusicNotifier] Media notification Initialization failed: $e');
      }
    }

    final newTitle = data['title'] ?? 'Unknown';
    final oldTitle = state.title;
    final newStatus = data['status'] ?? 'Unknown';

    // If both the title and the playback status are unknown or stopped, reset
    if (newTitle == 'Unknown' && (newStatus == 'Stopped' || newStatus == 'Unknown' || oldTitle == 'Unknown')) {
      state = MediaInfo.empty;
      if (_isMediaNotificationInitialized) {
        ref.read(mediaNotificationProvider).value?.reset();
      }
      return;
    }

    if (newTitle == 'Unknown' && oldTitle != 'Unknown') {
      String currentStatus = data['status'] ?? state.status;

      final int newPosition = (data['position'] ?? data['currentPosition'] ?? state.position) is int 
          ? (data['position'] ?? data['currentPosition'] ?? state.position) as int 
          : state.position;
          
      final int newDuration = (data['duration'] ?? state.duration) is int 
          ? (data['duration'] ?? state.duration) as int 
          : state.duration;

      state = state.copyWith(
        status: currentStatus,
        position: newPosition,
        duration: newDuration,
        albumArtBase64: data['albumArt'] ?? data['albumArtBase64'] ?? state.albumArtBase64,
      );
    } else {
      var newInfo = MediaInfo.fromMap(data);
      
      if (newInfo.albumArtBase64 == 'N/A' && state.albumArtBase64 != 'N/A' && state.albumArtBase64.isNotEmpty) {
        newInfo = newInfo.copyWith(albumArtBase64: state.albumArtBase64);
      }
      
      state = newInfo;
    }

    if (_isMediaNotificationInitialized) {
      ref.read(mediaNotificationProvider).value?.updateMetadata(state);
    }
  }


  void sendControlCommand(Map<String, dynamic> args) {
    ref.read(connectionManagerProvider).send('music', 'control', args);
  }

  void togglePlayPause() => sendControlCommand({'method': 'play_pause'});
  void next() => sendControlCommand({'method': 'next'});
  void previous() => sendControlCommand({'method': 'previous'});
  void seek(int position) => sendControlCommand({'method': 'seek', 'position': position});
}