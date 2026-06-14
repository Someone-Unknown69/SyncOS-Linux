// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import 'package:syncos_linux/features/notification/domain/model/app_notification.dart';
import 'package:syncos_linux/features/notification/provider/remote_notification_service_provider.dart';

class Notifications extends ConsumerStatefulWidget {
  const Notifications({super.key});

  @override
  ConsumerState<Notifications> createState() => NotificationsState();
}

class NotificationsState extends ConsumerState<Notifications> {
  final double borderRadius = AppTheme.borderRadius;
  final double spacing = AppTheme.spacing;
  final double padding = AppTheme.padding;

  final int animationSpeed = 400;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  final List<AppNotification> _displayedList = [];
  late final ValueNotifier<bool> _isEmptyNotifier;
  StreamSubscription<void>? _subscription;

  bool _isFetching = false;
  bool _queuedFetch = false;

  @override
  void initState() {
    super.initState();
    _isEmptyNotifier = ValueNotifier<bool>(true);

    // Initial database load and stream configuration
    WidgetsBinding.instance.addPostFrameCallback((_) => _initNotificationSync());
  }

  Future<void> _initNotificationSync() async {
    if (!mounted) return;
    final service = ref.read(remoteNotificationServiceProvider);

    // Perform initial load from Database
    final initialNotifications = await service.fetchAndSearchNotifications('');
    if (!mounted) return;

    // This forces the AnimatedList to register and animate the items into view
    // when the widget is recreated during a window resize.
    _syncLists(initialNotifications);

    // Listen to Database change notifications
    _subscription = service.onNotificationChange.listen((_) {
      _handleDatabaseSignal();
    });
  }

  // Serializes overlapping stream ticks to guarantee order-of-execution
  Future<void> _handleDatabaseSignal() async {
    if (!mounted) return;

    if (_isFetching) {
      _queuedFetch = true;
      return;
    }

    _isFetching = true;

    while (mounted) {
      _queuedFetch = false;
      final service = ref.read(remoteNotificationServiceProvider);
      
      final latestNotifications = await service.fetchAndSearchNotifications('');
      if (!mounted) break;

      _syncLists(latestNotifications);

      if (!_queuedFetch) break;
    }

    _isFetching = false;
  }

  void _syncLists(List<AppNotification> targetList) {
    // 1. Handle Clear-All Actions instantly
    if (targetList.isEmpty && _displayedList.isNotEmpty) {
      for (int i = _displayedList.length - 1; i >= 0; i--) {
        final removedItem = _displayedList[i];
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildAnimatedItem(removedItem, animation),
          duration: Duration(milliseconds: animationSpeed),
        );
      }
      _displayedList.clear();
      _isEmptyNotifier.value = true;
      return;
    }

    for (int i = _displayedList.length - 1; i >= 0; i--) {
      final oldItem = _displayedList[i];
      if (!targetList.any((newItem) => newItem.id == oldItem.id)) {
        final removedItem = _displayedList.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildAnimatedItem(removedItem, animation),
          duration: Duration(milliseconds: animationSpeed),
        );
      }
    }

    for (int i = 0; i < targetList.length; i++) {
      final newItem = targetList[i];
      if (!_displayedList.any((oldItem) => oldItem.id == newItem.id)) {
        _displayedList.insert(i, newItem);
        _listKey.currentState?.insertItem(
          i,
          duration: Duration(milliseconds: animationSpeed),
        );
      }
    }

    _isEmptyNotifier.value = _displayedList.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final service = ref.watch(remoteNotificationServiceProvider);

    return Container(
      padding: EdgeInsets.all(padding),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20.0,
                ),
                SizedBox(width: spacing),
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: spacing),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Stack(
                  children: [
                    AnimatedList(
                      key: _listKey,
                      initialItemCount: _displayedList.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index, animation) {
                        if (index < 0 || index >= _displayedList.length) {
                          return const SizedBox.shrink();
                        }
                        final item = _displayedList[index];
                        return SlideTransition(
                          position: animation.drive(
                            Tween<Offset>(
                              begin: const Offset(0.0, -0.2),
                              end: Offset.zero,
                            ).chain(CurveTween(curve: Curves.easeOutQuad)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(bottom: spacing),
                            child: _notificationTemplate(
                              context,
                              item.appName,
                              item.body,
                              item.timestamp,
                              item.colorValue,
                            ),
                          ),
                        );
                      },
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isEmptyNotifier,
                      builder: (context, value, child) {
                        if (!value) return const SizedBox.shrink();
                        return Center(
                          child: Text(
                            "No Notifications",
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: spacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FilledButton.icon(
                onPressed: () => service.clearAllNotifications(),
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text("Clear all"),
                style: FilledButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  backgroundColor: colorScheme.secondary,
                ),
              ),

              // TODO : Implement see all button in future with notification page
              // FilledButton.icon(
              //   onPressed: () {},
              //   icon: const Icon(Icons.arrow_circle_right_rounded),
              //   label: const Text("See All"),
              //   style: FilledButton.styleFrom(
              //     elevation: 0,
              //     shape: RoundedRectangleBorder(
              //       borderRadius: BorderRadius.circular(borderRadius),
              //     ),
              //     backgroundColor: colorScheme.primary,
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedItem(AppNotification item, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1.0,
        child: Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: _notificationTemplate(
            context,
            item.appName,
            item.body,
            item.timestamp,
            item.colorValue,
          ),
        ),
      ),
    );
  }

  Widget _notificationTemplate(
    BuildContext context,
    String title,
    String content,
    DateTime timestamp,
    int colorValue,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Color textColor = Color(colorValue).computeLuminance() > 0.1 ? Colors.black : Colors.white;

    final String formattedTime = _formatNotificationTime(timestamp);

    return Container(
      key: ValueKey(content + timestamp.toString()),
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: Color(colorValue),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      padding: const EdgeInsets.all(AppTheme.padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.borderRadius * 0.7),
            ),
            child: Icon(
              Icons.phone,
              size: 24,
              color: textColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                formattedTime,
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNotificationTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return "Just now";
    }
    if (difference.inHours < 1) {
      return "${difference.inMinutes}m ago";
    }
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _isEmptyNotifier.dispose();
    super.dispose();
  }
}