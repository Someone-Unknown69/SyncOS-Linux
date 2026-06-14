// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:syncos_linux/features/notification/domain/model/notification_action.dart';

@immutable
class AppNotification {
  final int id;
  final String appName;
  final String title;
  final String body;
  final DateTime timestamp;
  final int colorValue;
  final String packageName;
  final DateTime expiresAt;
  
  // Inline button interactions
  final List<NotificationAction> actions;

  const AppNotification({
    required this.id,
    required this.appName,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.colorValue,
    required this.packageName,
    required this.expiresAt,
    this.actions = const [], // Defaults to empty, considering this for future additions
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Color get contentColor {
    return Color(colorValue).computeLuminance() > 0.5 
        ? Colors.black 
        : Colors.white;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appName': appName,
      'title': title,
      'body': body,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'colorValue': colorValue,
      'packageName': packageName,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      // Store actions as a JSON string block inside standard database text fields
      'actions': actions.map((a) => a.toMap()).toList(), 
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    var rawActions = map['actions'];
    List<NotificationAction> parsedActions = [];
    
    if (rawActions is List) {
      parsedActions = rawActions
          .map((a) => NotificationAction.fromMap(a as Map<String, dynamic>))
          .toList();
    }

    return AppNotification(
      id: map['id'] as int,
      appName: map['appName'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      colorValue: map['colorValue'] as int,
      packageName: map['packageName'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int),
      actions: parsedActions,
    );
  }

  AppNotification copyWith({
    int? id,
    String? appName,
    String? title,
    String? body,
    DateTime? timestamp,
    int? colorValue,
    String? packageName,
    DateTime? expiresAt,
    List<NotificationAction>? actions,
  }) {
    return AppNotification(
      id: id ?? this.id,
      appName: appName ?? this.appName,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      colorValue: colorValue ?? this.colorValue,
      packageName: packageName ?? this.packageName,
      expiresAt: expiresAt ?? this.expiresAt,
      actions: actions ?? this.actions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          body == other.body &&
          timestamp == other.timestamp &&
          colorValue == other.colorValue &&
          packageName == other.packageName &&
          expiresAt == other.expiresAt &&
          const ListEquality().equals(actions, other.actions);

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      body.hashCode ^
      timestamp.hashCode ^
      colorValue.hashCode ^
      packageName.hashCode ^
      expiresAt.hashCode ^
      actions.hashCode;
}

class ListEquality {
  const ListEquality();
  bool equals(List? a, List? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}