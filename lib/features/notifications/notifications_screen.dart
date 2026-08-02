import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../auth/auth_provider.dart';
import '../../core/nav_helpers.dart';
import 'notification_provider.dart';
import 'notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().userId;
      if (userId != null) context.read<NotificationProvider>().fetchNotifications(userId);
    });
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'like': return Icons.favorite;
      case 'comment': return Icons.mode_comment;
      case 'reply': return Icons.reply;
      case 'repost': return Icons.repeat;
      case 'new_post': return Icons.article;
      case 'follow': return Icons.person_add;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;
    final notifProvider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifProvider.unreadCount > 0)
            TextButton(
              onPressed: () => context.read<NotificationProvider>().markAllAsRead(userId!),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notifProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifProvider.notifications.isEmpty
              ? Center(
                  child: Text('No notifications yet', style: TextStyle(color: Colors.grey.shade600)),
                )
              : ListView.separated(
                  itemCount: notifProvider.notifications.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final n = notifProvider.notifications[index];
                    return _NotificationTile(
                      notification: n,
                      icon: _iconFor(n.type),
                      onTap: () {
                        context.read<NotificationProvider>().markAsRead(n.id);
                        if (n.type == 'follow') {
                          goToUserProfile(context, n.actorId);
                        } else if (n.postId != null) {
                          pushIfNotCurrent(context, '/post/${n.postId}');
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final IconData icon;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: notification.isRead ? Colors.transparent : Colors.indigo.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: notification.actorAvatarUrl != null
                        ? CachedNetworkImageProvider(notification.actorAvatarUrl!)
                        : null,
                    child: notification.actorAvatarUrl == null ? const Icon(Icons.person) : null,
                  ),
                  Positioned(
                    bottom: -2, right: -2,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(icon, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.message),
                    const SizedBox(height: 2),
                    Text(timeago.format(notification.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}