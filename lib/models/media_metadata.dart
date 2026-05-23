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