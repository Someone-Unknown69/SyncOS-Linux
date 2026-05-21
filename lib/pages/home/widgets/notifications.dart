import 'dart:async';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/notifications_service.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() => NotificationsState();
}

class NotificationsState extends State<Notifications> {
  final double borderRadius = AppTheme.borderRadius;
  final double spacing = AppTheme.spacing;
  final double padding = AppTheme.padding;

  final int animationSpeed = 400;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  late final ValueNotifier<bool> _isEmptyNotifier;
  late StreamSubscription<NotificationEvent> _subscription;

  @override
  void initState() {
    super.initState();
    final service = NotificationService();
    
    _isEmptyNotifier = ValueNotifier<bool>(service.notifications.isEmpty);

    _subscription = service.events.listen((event) {
      if (event is NotificationAddEvent) {
        if (_isEmptyNotifier.value) {
          _isEmptyNotifier.value = false;
        }
        _listKey.currentState?.insertItem(
          event.index,
          duration: Duration(milliseconds: animationSpeed),
        );
      } else if (event is NotificationClearEvent) {
        final cleared = event.clearedNotifications;
        for (int i = cleared.length - 1; i >= 0; i--) {
          final removedItem = cleared[i];
          _listKey.currentState?.removeItem(
            i,
            (context, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: Padding(
                  padding: EdgeInsets.only(bottom: spacing),
                  child: _notificationTemplate(
                    context, 
                    removedItem.app, 
                    removedItem.body,
                    removedItem.timestamp,
                    removedItem.colorValue
                  ),
                ),
              ),
            ),
            duration: Duration(milliseconds: animationSpeed),
          );
        }
        _isEmptyNotifier.value = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final service = NotificationService();

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
                    color: Colors.white,
                    size: 20.0,
                  ),
                  SizedBox(width: spacing),
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
                      initialItemCount: service.notifications.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index, animation) {
                        final item = service.notifications[index];
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
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
                                item.app, 
                                item.body,
                                item.timestamp,
                                item.colorValue
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    ValueListenableBuilder(
                      valueListenable: _isEmptyNotifier,
                      builder: (context, value, child) {
                        if(!value) return const SizedBox.shrink();
                        return Center(
                          child: Text(
                            "No Notifications", 
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }
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
                onPressed: () => {
                  NotificationService().clearNotifications()
                },
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

              FilledButton.icon(
                onPressed: () => {
                  NotificationService().addNotification(
                    "Phone", 
                    "Your Phone Linging..", 
                    DateTime.now(),
                    0xFF0A192F,
                  )
                },
                icon: const Icon(Icons.arrow_circle_right_rounded),
                label: const Text("See All"),
                style: FilledButton.styleFrom(
                  elevation: 0, 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
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

  // Notification template
  Widget _notificationTemplate(
    BuildContext context,
    String appName,
    String content,
    DateTime timestamp,
    int colorValue
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Color textColor = Color(colorValue).computeLuminance() > 0.1 ? Colors.black : Colors.white;

    final String formattedTime = _formatNotificationTime(timestamp);

    return Container(
      key: ValueKey(content + timestamp.toString()),
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

// to format datetime raw string
  String _formatNotificationTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    // If it happened less than a minute ago
    if (difference.inMinutes < 1) {
      return "Just now";
    }
    
    // If it happened within the last hour, show relative minutes (e.g., "5m ago")
    if (difference.inHours < 1) {
      return "${difference.inMinutes}m ago";
    }
    
    // Fallback to standard clock format (HH:MM)
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  @override
  void dispose() {
    _subscription.cancel();
    _isEmptyNotifier.dispose();
    super.dispose();
  }
}
