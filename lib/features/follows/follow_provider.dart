import 'package:flutter/foundation.dart';
import '../../core/supabase_client.dart';

class FollowProvider extends ChangeNotifier {
  final Set<String> followingIds = {};
  final Set<String> _pendingToggles = {};

  bool isFollowing(String userId) => followingIds.contains(userId);

  Future<void> loadMyFollowing(String myUserId) async {
    final data = await supabase.from('follows').select('following_id').eq('follower_id', myUserId);
    followingIds
      ..clear()
      ..addAll((data as List).map((r) => r['following_id'] as String));
    notifyListeners();
  }

  void clear() {
    followingIds.clear();
  }

  Future<void> toggleFollow(String targetUserId, String myUserId) async {
    if (_pendingToggles.contains(targetUserId)) return;
    final wasFollowing = followingIds.contains(targetUserId);

    _pendingToggles.add(targetUserId);
    if (wasFollowing) {
      followingIds.remove(targetUserId);
    } else {
      followingIds.add(targetUserId);
    }
    notifyListeners();

    try {
      if (wasFollowing) {
        await supabase.from('follows').delete().eq('follower_id', myUserId).eq('following_id', targetUserId);
      } else {
        await supabase.from('follows').insert({'follower_id': myUserId, 'following_id': targetUserId});
      }
    } catch (e) {
      debugPrint('toggleFollow failed, reverting: $e');
      if (wasFollowing) {
        followingIds.add(targetUserId);
      } else {
        followingIds.remove(targetUserId);
      }
      notifyListeners();
    } finally {
      _pendingToggles.remove(targetUserId);
    }
  }
}