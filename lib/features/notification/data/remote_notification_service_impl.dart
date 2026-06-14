// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'package:syncos_linux/core/network/domain/i_connection_manager.dart';
import 'package:syncos_linux/core/storage/data/storage_service.dart';
import 'package:syncos_linux/features/notification/domain/i_remote_notification_service.dart';
import 'package:syncos_linux/features/notification/domain/model/app_notification.dart';

class RemoteNotificationServiceImpl implements IRemoteNotificationService {
  final IConnectionManager _connectionManager;
  final StorageService _storageService;

  RemoteNotificationServiceImpl(
    this._connectionManager,
    this._storageService,
  );

  static const String _storageKey = 'notifications';

  final StreamController<void> _notificationController = StreamController<void>.broadcast();

  @override
  Stream<void> get onNotificationChange => _notificationController.stream;

  // Helper method to internalize fetching and conversion of list from StorageService
  Future<List<AppNotification>> _getStoredList() async {
    final List<dynamic>? rawList = await _storageService.readDatabase<List<dynamic>>(_storageKey);
    if (rawList == null) return [];
    
    return rawList
        .map((item) => AppNotification.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // Helper method to push the raw structure list down to storage
  Future<void> _saveStoredList(List<AppNotification> list) async {
    final payload = list.map((n) => n.toMap()).toList();
    await _storageService.writeDatabase<List<dynamic>>(_storageKey, payload);
  }

  @override
  Future<void> saveNotification(Map<String, dynamic> args) async {
    final notification = AppNotification.fromMap(args);
    final currentList = await _getStoredList();

    // Prevent duplicate entries if the exact notification payload arrives twice
    currentList.removeWhere((item) => item.id == notification.id);
    
    // Always insert at index 0 so newest notifications show up at the top
    currentList.insert(0, notification);

    await _saveStoredList(currentList);
    _notificationController.add(null);
  }

  @override
  Future<void> removeNotification(String notificationId) async {
    final targetId = int.tryParse(notificationId);
    if (targetId != null) {
      final currentList = await _getStoredList();
      currentList.removeWhere((item) => item.id == targetId);
      
      await _saveStoredList(currentList);
      _notificationController.add(null);
    }
  }

  @override
  FutureOr<List<AppNotification>> fetchAndSearchNotifications(String query) async {
    final currentList = await _getStoredList();
    
    final now = DateTime.now();
    final initialLength = currentList.length;
    currentList.removeWhere((item) => item.expiresAt.isBefore(now));
    
    if (currentList.length < initialLength) {
      await _saveStoredList(currentList);
    }

    if (query.isEmpty) {
      return currentList;
    }

    final lowercaseQuery = query.toLowerCase();
    return currentList.where((item) {
      return item.title.toLowerCase().contains(lowercaseQuery) ||
             item.body.toLowerCase().contains(lowercaseQuery) ||
             item.packageName.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  @override
  Future<void> purgeExpiredNotifications() async {
    final currentList = await _getStoredList();
    final now = DateTime.now();
    final initialLength = currentList.length;
    
    currentList.removeWhere((item) => item.expiresAt.isBefore(now));
    
    if (currentList.length < initialLength) {
      await _saveStoredList(currentList);
      _notificationController.add(null);
    }
  }

  @override
  Future<void> executeNotificationAction({
    required int notificationId,
    required String actionId,
    String? optionalInput,
  }) async {
    _connectionManager.send('notification', 'reply', {});
  }

  @override
  Future<void> clearAllNotifications() async {
    await _storageService.deleteDatabase(_storageKey);
    _notificationController.add(null);
  }

  @override
  Future<void> dispose() async {
    await _notificationController.close();
  }
}