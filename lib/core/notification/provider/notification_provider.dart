import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/i_notification_service.dart';
import '../data/notification_service_impl.dart';

/// Notification service used throughout the app
final notificationServiceProvider = Provider<INotificationService>((ref) {
  return NotificationServiceImpl();
});