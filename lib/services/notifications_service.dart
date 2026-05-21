import 'dart:async';
import 'package:flutter/foundation.dart';

class AppNotification {
  final String app;
  final String body;
  final DateTime timestamp;
  final int colorValue;

  AppNotification({
    required this.app,
    required this.body,
    required this.timestamp,
    required this.colorValue,
  });
}

abstract class NotificationEvent {}

class NotificationAddEvent extends NotificationEvent {
  final int index;
  final AppNotification notification;
  NotificationAddEvent(this.index, this.notification);
}

class NotificationClearEvent extends NotificationEvent {
  final List<AppNotification> clearedNotifications;
  NotificationClearEvent(this.clearedNotifications);
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;

  final _eventController = StreamController<NotificationEvent>.broadcast(sync: true);
  Stream<NotificationEvent> get events => _eventController.stream;

  void addNotification(
    String app, 
    String body, 
    DateTime timestamp,
    int colorValue
  ) {
    final notification = AppNotification(
      app: app, 
      body: body, 
      timestamp: timestamp, 
      colorValue: colorValue
    );
    _notifications.insert(0, notification);
    _eventController.add(NotificationAddEvent(0, notification));
    notifyListeners();
  }

  void clearNotifications() {
    if (_notifications.isEmpty) return;
    
    final cleared = List<AppNotification>.from(_notifications);
    _notifications.clear();
    _eventController.add(NotificationClearEvent(cleared));
    notifyListeners();
  }

}