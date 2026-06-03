import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_controller/features/notification/domain/model/app_notification.dart';
import 'package:laptop_controller/features/notification/provider/remote_notification_service_provider.dart';
import '../../../theme/app_theme.dart';

class Notifications extends ConsumerStatefulWidget {
  const Notifications({super.key});

  @override
  ConsumerState<Notifications> createState() => NotificationsState();
}

class NotificationsState extends ConsumerState<Notifications> {
  final int animationSpeed = 400;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // Tracks items sequentially in memory to coordinate indices for AnimatedList transitions
  final List<AppNotification> _shadowList = [];
  
  late final ValueNotifier<bool> _isEmptyNotifier;
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _isEmptyNotifier = ValueNotifier<bool>(true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _listenToNotificationChanges());
  }

  Future<void> _listenToNotificationChanges() async {
    if (!mounted) return;

    final service = ref.read(remoteNotificationServiceProvider);

    final initialItems = await service.fetchAndSearchNotifications('');
    _shadowList.addAll(initialItems);
    _isEmptyNotifier.value = _shadowList.isEmpty;
    setState(() {});

    // Listen to changes emitted from our in memory storage event cycle
    _subscription = service.onNotificationChange.listen((_) async {
      if (!mounted) return;

      final updatedItems = await service.fetchAndSearchNotifications('');
      _syncAnimatedList(_shadowList, updatedItems);
    });
  }

  void _syncAnimatedList(List<AppNotification> current, List<AppNotification> incoming) {
    // Clear All Action
    if (incoming.isEmpty && current.isNotEmpty) {
      for (int i = current.length - 1; i >= 0; i--) {
        final removedItem = current[i];
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildAnimatedItem(removedItem, animation),
          duration: Duration(milliseconds: animationSpeed),
        );
      }
      current.clear();
      _isEmptyNotifier.value = true;
      return;
    }

    // Handle Single New Items or Deletions
    _isEmptyNotifier.value = incoming.isEmpty;

    // Detect and process removals
    for (int i = current.length - 1; i >= 0; i--) {
      final oldItem = current[i];
      if (!incoming.any((newItem) => newItem.id == oldItem.id)) {
        current.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildAnimatedItem(oldItem, animation),
          duration: Duration(milliseconds: animationSpeed),
        );
      }
    }

    // Detect and process additions
    for (int i = 0; i < incoming.length; i++) {
      final newItem = incoming[i];
      if (!current.any((oldItem) => oldItem.id == newItem.id)) {
        current.insert(i, newItem);
        _listKey.currentState?.insertItem(
          i,
          duration: Duration(milliseconds: animationSpeed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final service = ref.watch(remoteNotificationServiceProvider);

    return Container(
      padding: EdgeInsets.all(AppTheme.padding),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        children: [
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 20.0,
                ),
                SizedBox(width: AppTheme.spacing),
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                child: Stack(
                  children: [
                    AnimatedList(
                      key: _listKey,
                      initialItemCount: _shadowList.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index, animation) {
                        if (index >= _shadowList.length) return const SizedBox.shrink();
                        final item = _shadowList[index];
                        return SlideTransition(
                          position: animation.drive(
                            Tween<Offset>(
                              begin: const Offset(0.0, -0.2),
                              end: Offset.zero,
                            ).chain(CurveTween(curve: Curves.easeOutQuad)),
                          ),
                          child: _buildAnimatedItem(item, animation),
                        );
                      },
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isEmptyNotifier,
                      builder: (context, value, child) {
                        if (!value) return const SizedBox.shrink();
                        return const Center(
                          child: Text(
                            "No Notifications",
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing),
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
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                  backgroundColor: colorScheme.secondary,
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  // Simulating a payload insertion into our clean runtime architecture
                  service.saveNotification(
                    AppNotification(
                      id: DateTime.now().millisecondsSinceEpoch,
                      packageName: "com.android.phone",
                      appName: "Phone",
                      title: "Incoming Call",
                      body: "Your Phone Linging..",
                      timestamp: DateTime.now(),
                      expiresAt: DateTime.now().add(const Duration(hours: 1)),
                      colorValue: 0xFF0A192F,
                      actions: const [],
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_circle_right_rounded),
                label: const Text("See All"),
                style: FilledButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                  backgroundColor: colorScheme.primary,
                ),
              ),
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
          padding: const EdgeInsets.only(bottom: AppTheme.spacing),
          child: _notificationTemplate(
            context,
            item.appName,
            item.body,
            item.timestamp,
            item.colorValue,
            item.id,
          ),
        ),
      ),
    );
  }

  Widget _notificationTemplate(
    BuildContext context,
    String appName,
    String content,
    DateTime timestamp,
    int colorValue,
    int notificationId,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color textColor = Color(colorValue).computeLuminance() > 0.1 ? Colors.black : Colors.white;
    final String formattedTime = _formatNotificationTime(timestamp);

    return Container(
      key: ValueKey('${notificationId}_$content'),
      height: 80,
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
              children: [
                Text(
                  appName,
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

    if (difference.inMinutes < 1) return "Just now";
    if (difference.inHours < 1) return "${difference.inMinutes}m ago";

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