// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter/foundation.dart';
import 'package:syncos_linux/core/misc/app_logging.dart';
import 'package:syncos_linux/core/misc/base64_image_converter.dart';

@immutable
class MediaInfo {
  final bool isValid;
  final String? title;
  final String? artist;
  final String? album;
  final bool? status;
  final int? position;
  final int? duration;
  final Uri? albumArtUri;

  const MediaInfo({
    required this.isValid,
    this.title,
    this.artist,
    this.album,
    this.status,
    this.position,
    this.duration,
    this.albumArtUri,
  });

  String get identity {
    final trackTitle = (title ?? 'unknown').trim().toLowerCase();
    final trackArtist = (artist ?? 'unknown artist').trim().toLowerCase();

    return '$trackTitle :: $trackArtist';
  }

  bool get isEmpty =>
      !isValid &&
      (title == null || title!.isEmpty) &&
      (artist == null || artist!.isEmpty) &&
      (position == null || position == 0) &&
      (duration == null || duration == 0);

  static Future<MediaInfo> formPayload(Map<String, dynamic> map) async {
    final String? artData = map['albumArt'] as String?;

    return MediaInfo(
      isValid: (map['isValid'] as bool?) ?? false,
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      status: map['status'] as bool?,
      position: map['position'] as int?,
      duration: map['duration'] as int?,
      albumArtUri: artData != null ? await base64ToTmpFile(artData) : null,
    );
  }

  static MediaInfo fromMap(Map<String, dynamic> map) {
    int? toInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    Uri? parseUri(dynamic value) {
      if (value == null) return null;
      if (value is Uri) return value;
      if (value is String && value.isNotEmpty && value != 'N/A') {
        return Uri.tryParse(value);
      }
      return null;
    }

    return MediaInfo(
      isValid: map['isValid'] as bool,
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      status: map['status'] as bool?,
      position: toInt(map['position']),
      duration: toInt(map['duration']),
      albumArtUri: parseUri(map['albumArtUri']),
    );
  }

  Future<Map<String, dynamic>> toPayload() async {
    String? base64Result;
    if (albumArtUri != null) {
      try {
        base64Result = await fileToBase64(albumArtUri!);
      } catch (e) {
        logDebug('MediaInfo', 'Error encoding file to base64 in toMap: $e');
      }
    }

    return {
      'isValid': isValid,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (status != null) 'status': status,
      if (position != null) 'position': position,
      if (duration != null) 'duration': duration,
      'albumArt': ?base64Result,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (status != null) 'status': status,
      if (position != null) 'position': position,
      if (duration != null) 'duration': duration,
      if (albumArtUri != null) 'albumArtUri': albumArtUri,
    };
  }

  MediaInfo mergeWith(MediaInfo other) {
    if (other == MediaInfo.empty) return this;

    bool isStringValid(String? val) =>
        val != null &&
        val.trim().isNotEmpty &&
        val.toLowerCase() != 'unknown' &&
        val.toLowerCase() != 'unknown artist';

    return MediaInfo(
      isValid: other.isValid,
      title: isStringValid(other.title) ? other.title : title,
      artist: isStringValid(other.artist) ? other.artist : artist,
      album: isStringValid(other.album) ? other.album : album,

      status: other.status ?? status,
      position: other.position ?? position,

      duration: (other.duration != null && other.duration! > 0)
          ? other.duration
          : duration,

      albumArtUri: (other.albumArtUri != null)
          ? other.albumArtUri
          : albumArtUri,
    );
  }

  MediaInfo calculateDeltaObject(MediaInfo oldState) {
    if (identity != oldState.identity) {
      return this;
    }

    return MediaInfo(
      isValid: (isValid != oldState.isValid) ? isValid : true,
      title: (title != oldState.title) ? title : null,
      artist: (artist != oldState.artist) ? artist : null,
      album: (album != oldState.album) ? album : null,
      status: (status != oldState.status) ? status : null,
      position: (position != oldState.position) ? position : null,
      duration: (duration != oldState.duration) ? duration : null,
      albumArtUri: (albumArtUri != oldState.albumArtUri) ? albumArtUri : null,
    );
  }

  MediaInfo copyWith({
    required bool isValid,
    String? title,
    String? artist,
    String? album,
    bool? status,
    int? position,
    int? duration,
    Uri? albumArtUri,
  }) {
    return MediaInfo(
      isValid: isValid,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      albumArtUri: albumArtUri ?? this.albumArtUri,
    );
  }

  static const empty = MediaInfo(
    isValid: false,
    title: '',
    artist: '',
    album: '',
    status: false,
    position: 0,
    duration: 0,
    albumArtUri: null,
  );

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
          albumArtUri == other.albumArtUri;

  @override
  int get hashCode =>
      title.hashCode ^
      artist.hashCode ^
      album.hashCode ^
      status.hashCode ^
      position.hashCode ^
      duration.hashCode ^
      albumArtUri.hashCode;
}
