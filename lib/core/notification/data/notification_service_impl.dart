import 'dart:async';
import 'package:dbus/dbus.dart';
import 'package:laptop_controller/core/notification/domain/i_notification_service.dart';

// IMPORTANT : This entirely works on DBUS interface
// init() and dismissNotification() are "No-Op" implementation. In Linux there's no such thing as dissmis or init a notification
//
// Gnome and Dunst/Mako doesn't render a progress bar in notifications, KDE plasma does so if in future it's requred we can 
// modify the implementation to add in hints field 
//
// using the 'x-canonical-private-synchronous' hint ensures that subsequent updates replace 
// the existing bubble rather than spamming the notification history
//
// To prevent DBus latency from blocking file transfer loops, this implementation uses a Producer and Consumer pattern. 
// The file transfer loop queues progress events in a StreamController, and a background worker handles the 
// asynchronous D-Bus I/O.

class NotificationServiceImpl implements INotificationService{
  int? _lastNotificationId;
  final DBusClient _client = DBusClient.session();

  final _notificationController = StreamController<Map<String, dynamic>>();

  NotificationServiceImpl() {
    // The Consumer: Listens for progress updates and handles them one by one
    _notificationController.stream.listen((data) async {
      await _executeDbusNotify(data['title'], data['progress']);
    });
  }



  /// Displays a standard, non-progress notification.
  /// 
  /// [title]: The main header for the notification.
  /// [body]: The descriptive text (optional).
  /// [urgency]: 0 = Low, 1 = Normal, 2 = Critical (e.g., used for errors).
  /// [icon]: System icon name (e.g., 'dialog-information', 'dialog-error').
  @override
  Future<void> showNotification({
    required int id,
    required String title,
    String? body,
    int urgency = 1,
    String icon = 'dialog-information',
  }) async {
    final object = DBusRemoteObject(
      _client,
      name: 'org.freedesktop.Notifications',
      path: DBusObjectPath('/org/freedesktop/Notifications'),
    );

    // Using 0 as the replaces_id ensures this is always treated as a new notification, not an update.
    await object.callMethod(
      'org.freedesktop.Notifications',
      'Notify',
      [
        DBusString('SyncOS'),              // app_name
        DBusUint32(0),                     // replaces_id
        DBusString(icon),                  // app_icon
        DBusString(title),                 // summary
        DBusString(body ?? ''),            // body
        DBusArray.string([]),              // actions
        DBusDict.stringVariant({
          'urgency': DBusByte(urgency),    // Maps to Low/Normal/Critical
        }),
        DBusInt32(5000),                  // expire_timeout
      ],
    );
  }

  @override
  void showTransferProgress({
    required int id,
    required String title,
    required String body,
    required int progress
  }) {
    _notificationController.add({'title': title, 'progress': progress});
  }


  @override
  Future<void> showErrorNotification({
    required int id,
    required String title, 
    required String error
  }) async {
    await showNotification(
      id: id,
      title: title,
      body: error,
      urgency: 2,
      icon: 'dialog-error'
    );
  }

  @override
  Future<void> showTestNotification() async {
    await showNotification(
      id: 0,
      title: "Ladis",
      body: "Ladis Washerum",
    );
  }
  
  
  // Asyncronously shows the progress notification curerntly in queue
  Future<void> _executeDbusNotify(
    String title, 
    int progress
  ) async {

    final object = DBusRemoteObject(
      _client,
      name: 'org.freedesktop.Notifications',
      path: DBusObjectPath('/org/freedesktop/Notifications'),
    );

    final barLength = 10;
    final filled = (progress / 100 * barLength).round();
    final bar = "[" + ("█" * filled) + ("░" * (barLength - filled)) + "]";
    final displayBody = "$bar $progress%";

    final hints = {
      'x-canonical-private-synchronous': DBusString('SyncOS'),
    };

    final response = await object.callMethod(
      'org.freedesktop.Notifications',
      'Notify',
      [
        DBusString('SyncOS'),                   // app_name
        DBusUint32(_lastNotificationId ?? 0),   // <--- PASS THE PREVIOUS ID HERE
        DBusString(''),                         // app_icon
        DBusString(title),                      // summary
        DBusString(displayBody),                // body
        DBusArray.string([]),                   // actions
        DBusDict.stringVariant(hints),          // hints
        DBusInt32(5000),                        // expire_timeout
      ],
    );

    if (response.values.isNotEmpty) {
    _lastNotificationId = response.values[0].asUint32();
    } else {
      // If no ID is returned, we have to reset to 0 to prevent 
      // sending an invalid/outdated ID in the next call.
      _lastNotificationId = 0; 
    }
  }

  @override
  void dispose() {
    _client.close();
  }

  @override
  Future<void> dismissNotification(int id) async {
    return Future.value();
  }
}
