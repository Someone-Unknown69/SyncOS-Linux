// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:syncos_linux/features/notification/domain/model/app_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

abstract class IRemoteNotificationService {
  // Streams the notification changes for ui to listen and update
  Stream<void> get onNotificationChange;

  Future<void> saveNotification(Map<String, dynamic> args);
  Future<void> removeNotification(String notificationId);

  // retrives current cache of notifications from query
  FutureOr<List<AppNotification>> fetchAndSearchNotifications(String query);

  // Designed to be driven by an independent background worker 
  // (like a periodic Timer or an Isolate task) so that data cleans itself up over time
  Future<void> purgeExpiredNotifications();

  // Carries the action back to client and optionally carries a text if responses were text based
  Future<void> executeNotificationAction({
    required int notificationId,
    required String actionId,
    String? optionalInput,
  });

  Future<void> clearAllNotifications();

  Future<void> dispose();
}
