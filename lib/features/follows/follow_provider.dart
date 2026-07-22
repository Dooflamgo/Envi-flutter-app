import 'package:flutter/foundation.dart';
import '../../core/supabase_client.dart';

class FollowProvider extends ChangeNotifier {
  final Set<String> followingIds = {};

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
    if (followingIds.contains(targetUserId)) {
      await supabase.from('follows').delete().eq('follower_id', myUserId).eq('following_id', targetUserId);
      followingIds.remove(targetUserId);
    } else {
      await supabase.from('follows').insert({'follower_id': myUserId, 'following_id': targetUserId});
      followingIds.add(targetUserId);
    }
    notifyListeners();
  }
}