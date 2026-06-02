import 'package:laptop_controller/models/media_metadata.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remote_media_state.g.dart';

@Riverpod(keepAlive: true)
class MusicNotifier extends _$MusicNotifier {
  @override
  MediaInfo build() => MediaInfo.empty;

  void updateMetadata(Map<String, dynamic> data) {
    final newTitle = data['title'] ?? 'Unknown';
    final oldTitle = state.title;

    // Dirty cache
    if (newTitle == 'Unknown' && oldTitle != 'Unknown') {
      String newStatus = state.status;

      final int newPosition = (data['position'] ?? data['currentPosition'] ?? state.position) is int 
          ? (data['position'] ?? data['currentPosition'] ?? state.position) as int 
          : state.position;
          
      final int newDuration = (data['duration'] ?? state.duration) is int 
          ? (data['duration'] ?? state.duration) as int 
          : state.duration;

      state = state.copyWith(
        status: newStatus,
        position: newPosition,
        duration: newDuration,
        albumArtBase64: data['albumArt'] ?? data['albumArtBase64'] ?? state.albumArtBase64,
      );
      return;
    }

    var newInfo = MediaInfo.fromMap(data);
    
    // Retain previous album art if the new one is missing
    if (newInfo.albumArtBase64 == 'N/A' && state.albumArtBase64 != 'N/A' && state.albumArtBase64.isNotEmpty) {
      newInfo = newInfo.copyWith(albumArtBase64: state.albumArtBase64);
    }
    
    state = newInfo;
  }
}