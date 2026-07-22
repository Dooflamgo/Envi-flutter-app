import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import 'notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final List<NotificationModel> notifications = [];
  bool isLoading = false;
  RealtimeChannel? _channel;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications(String userId) async {
    isLoading = true;
    notifyListeners();

    final data = await supabase
        .from('notifications')
        .select('*, profiles!notifications_actor_id_fkey(name, avatar_url)')
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    notifications
      ..clear()
      ..addAll((data as List).map((e) => NotificationModel.fromMap(e)));

    isLoading = false;
    notifyListeners();
  }

  /// Subscribes to new notification rows for this user in real time.
  /// Call once after login; call `unsubscribe()` on logout.
  void subscribeToRealtime(String userId) {
    _channel?.unsubscribe();
    _channel = supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) async {
            // The realtime payload doesn't include the joined profile, so
            // re-fetch that single row with the join before inserting it.
            final data = await supabase
                .from('notifications')
                .select('*, profiles!notifications_actor_id_fkey(name, avatar_url)')
                .eq('id', payload.newRecord['id'])
                .single();
            notifications.insert(0, NotificationModel.fromMap(data));
            notifyListeners();
          },
        )
        .subscribe();
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  Future<void> markAsRead(String id) async {
    await supabase.from('notifications').update({'is_read': true}).eq('id', id);
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead(String userId) async {
    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false);
    for (var i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}