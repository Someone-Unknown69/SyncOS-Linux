import 'package:flutter/material.dart';

@immutable
class MediaInfo {
  final String title;
  final String artist;
  final String album;
  final String status;
  final int position;
  final int duration;
  final String albumArtBase64;

  const MediaInfo({
    required this.title,
    required this.artist,
    required this.album,
    required this.status,
    required this.position,
    required this.duration,
    required this.albumArtBase64,
  });

  static const empty = MediaInfo(
    title: '',
    artist: '',
    album: '',
    status: 'Stopped',
    position: 0,
    duration: 0,
    albumArtBase64: '',
  );

  factory MediaInfo.fromMap(Map<String, dynamic> map) {
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return MediaInfo(
      title: map['title'] ?? 'Unknown',
      artist: map['artist'] ?? 'Unknown Artist',
      album: map['album'] ?? 'Unknown',
      status: map['status'],
      position: toInt(map['position'] ?? map['currentPosition']),
      duration: toInt(map['duration']),
      albumArtBase64: map['albumArt'] ?? map['albumArtBase64'] ?? 'N/A',
    );
  }

  bool get isValid => title != 'Unknown' && title.isNotEmpty;

  Map<String, dynamic> toMap({bool includeArt = true}) => {
    'title': title,
    'artist': artist,
    'album': album,
    'status': status,
    'position': position,
    'duration': duration,
    if (includeArt)'albumArt': albumArtBase64.isNotEmpty ? albumArtBase64 : null,
  };

  MediaInfo copyWith({
    String? title,
    String? artist,
    String? album,
    String? status,
    int? position,
    int? duration,
    String? albumArtBase64,
  }) => MediaInfo(
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    status: status ?? this.status,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    albumArtBase64: albumArtBase64 ?? this.albumArtBase64,
  );

  // Used for Dirty Cache Check (ignores the album art url)
  bool isSameAs(MediaInfo? other) {
    if (other == null) return false;
    return title == other.title &&
           artist == other.artist &&
           status == other.status &&
           position == other.position;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaInfo &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          artist == other.artist &&
          album == other.album &&
          status == other.status &&
          position == other.position &&
          duration == other.duration &&
          albumArtBase64 == other.albumArtBase64;

  @override
  int get hashCode => Object.hash(
      title, artist, album, status, position, duration, albumArtBase64);

  @override
  String toString() => 'MediaInfo(title: $title, status: $status)';
}
