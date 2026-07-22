import '../posts/post_model.dart';
import '../../core/supabase_client.dart';

class ProfileFeedItem {
  final PostModel post;
  final bool isRepost;
  final String? reposterName;
  final String? reposterAvatarUrl;
  final DateTime activityAt;

  ProfileFeedItem({
    required this.post,
    required this.isRepost,
    this.reposterName,
    this.reposterAvatarUrl,
    required this.activityAt,
  });

  ProfileFeedItem copyWith({PostModel? post}) => ProfileFeedItem(
        post: post ?? this.post,
        isRepost: isRepost,
        reposterName: reposterName,
        reposterAvatarUrl: reposterAvatarUrl,
        activityAt: activityAt,
      );
}

Future<List<ProfileFeedItem>> fetchProfileFeed(String userId) async {
  final postsData = await supabase
      .from('posts')
      .select('*, profiles!posts_user_id_fkey(name, avatar_url), likes(count), reposts(count)')
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  final repostsData = await supabase
      .from('reposts')
      .select('id, created_at, posts!inner(*, profiles!posts_user_id_fkey(name, avatar_url), likes(count), reposts(count))')
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  final items = <ProfileFeedItem>[
    for (final row in postsData as List)
      ProfileFeedItem(
        post: PostModel.fromMap(row),
        isRepost: false,
        activityAt: DateTime.parse(row['created_at']),
      ),
  ];

  if ((repostsData as List).isNotEmpty) {
    final reposterProfile =
        await supabase.from('profiles').select('name, avatar_url').eq('id', userId).single();

    for (final row in repostsData) {
      final postMap = row['posts'] as Map<String, dynamic>;
      items.add(ProfileFeedItem(
        post: PostModel.fromMap(postMap),
        isRepost: true,
        reposterName: reposterProfile['name'],
        reposterAvatarUrl: reposterProfile['avatar_url'],
        activityAt: DateTime.parse(row['created_at']),
      ));
    }
  }

  items.sort((a, b) => b.activityAt.compareTo(a.activityAt));

  final myUserId = supabase.auth.currentUser?.id;
  if (myUserId != null && items.isNotEmpty) {
    final ids = items.map((i) => i.post.id).toSet().toList();
    final myLikes = await supabase.from('likes').select('post_id').eq('user_id', myUserId).inFilter('post_id', ids);
    final myReposts = await supabase.from('reposts').select('post_id').eq('user_id', myUserId).inFilter('post_id', ids);
    final likedIds = (myLikes as List).map((r) => r['post_id'] as String).toSet();
    final repostedIds = (myReposts as List).map((r) => r['post_id'] as String).toSet();

    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(
        post: items[i].post.copyWith(
              isLikedByMe: likedIds.contains(items[i].post.id),
              isRepostedByMe: repostedIds.contains(items[i].post.id),
            ),
      );
    }
  }

  return items;
}