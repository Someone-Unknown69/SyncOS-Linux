// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter/material.dart';

/// Represents an interactive option or button attached to a notification.

@immutable
class NotificationAction {
  final String id;          // identifier for the action (e.g., "reply", "dismiss")
  final String label;       // Text displayed on the button (e.g., "Reply", "Mute")
  final String? iconKey;    // String key to map a custom icon in Flutter later
  final bool requiresInput; // True if clicking this opens a text input field (like a chat reply)

  const NotificationAction({
    required this.id,
    required this.label,
    this.iconKey,
    this.requiresInput = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'iconKey': iconKey,
      'requiresInput': requiresInput ? 1 : 0, 
    };
  }

  factory NotificationAction.fromMap(Map<String, dynamic> map) {
    return NotificationAction(
      id: map['id'] as String,
      label: map['label'] as String,
      iconKey: map['iconKey'] as String?,
      requiresInput: (map['requiresInput'] as int? ?? 0) == 1,
    );
  }
}