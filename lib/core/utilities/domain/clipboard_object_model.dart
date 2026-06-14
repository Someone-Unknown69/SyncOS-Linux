// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

class ClipboardObject {
  final String content;
  final DateTime timestamp;

  ClipboardObject({
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ClipboardObject.fromMap(Map<String, dynamic> map) {
    return ClipboardObject(
      content: map['content'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}