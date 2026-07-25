import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/supabase_client.dart';
import 'post_model.dart';

class PostProvider extends ChangeNotifier {
  static const int _pageSize = 10;

  final List<PostModel> posts = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  int _page = 0;

  Future<void> fetchInitial() async {
    isLoading = true;
    posts.clear();
    _page = 0;
    hasMore = true;
    notifyListeners();

    await _fetchPage();
    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchMore() async {
    if (isLoadingMore || !hasMore) return;
    isLoadingMore = true;
    notifyListeners();

    await _fetchPage();
    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> _fetchPage() async {
    final from = _page * _pageSize;
    final to = from + _pageSize - 1;

    final data = await supabase
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(name, avatar_url), likes(count), reposts(count)')
        .order('created_at', ascending: false)
        .range(from, to);

    final newPosts = (data as List).map((e) => PostModel.fromMap(e)).toList();
    await _hydrateMyReactions(newPosts);

    if (newPosts.length < _pageSize) hasMore = false;
    posts.addAll(newPosts);
    _page++;
  }

  Future<PostModel> fetchSinglePost(String postId) async {
    final data = await supabase
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(name, avatar_url), likes(count), reposts(count)')
        .eq('id', postId)
        .single();
    var post = PostModel.fromMap(data);
    final hydrated = [post];
    await _hydrateMyReactions(hydrated);
    return hydrated[0];
  }

  Future<void> createPost({
    required String userId,
    required String content,
    required List<File> images,
  }) async {
    final postId = const Uuid().v4();
    final imageUrls = await _uploadImages(userId, postId, images);

    await supabase.from('posts').insert({
      'id': postId,
      'user_id': userId,
      'content': content,
      'image_urls': imageUrls,
    });

    await fetchInitial();
  }

  Future<void> updatePost({
    required String postId,
    required String userId,
    required String content,
    required List<String> existingImageUrls,
    required List<String> removedImageUrls,
    required List<File> newImages,
  }) async {
    if (removedImageUrls.isNotEmpty) {
      await _deleteImagesByUrl(removedImageUrls);
    }

    final newUrls = await _uploadImages(userId, postId, newImages);
    final finalUrls = [...existingImageUrls, ...newUrls];

    await supabase.from('posts').update({
      'content': content,
      'image_urls': finalUrls,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', postId);

    await fetchInitial();
  }

  Future<void> deletePost(String postId, String userId) async {
    final folderPath = '$userId/$postId';
    final files = await supabase.storage.from('post-images').list(path: folderPath);
    if (files.isNotEmpty) {
      final paths = files.map((f) => '$folderPath/${f.name}').toList();
      await supabase.storage.from('post-images').remove(paths);
    }

    final relatedComments = await supabase
        .from('comments')
        .select('id, user_id')
        .eq('post_id', postId);

    for (final comment in relatedComments as List) {
      final commentFolder = '${comment['user_id']}/${comment['id']}';
      final commentFiles = await supabase.storage.from('comment-images').list(path: commentFolder);
      if (commentFiles.isNotEmpty) {
        final commentPaths = commentFiles.map((f) => '$commentFolder/${f.name}').toList();
        await supabase.storage.from('comment-images').remove(commentPaths);
      }
    }

    await supabase.from('posts').delete().eq('id', postId);
    posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  Future<List<String>> _uploadImages(String userId, String postId, List<File> images) async {
    final urls = <String>[];
    for (final image in images) {
      final ext = image.path.split('.').last;
      final fileName = '${const Uuid().v4()}.$ext';
      final path = '$userId/$postId/$fileName';
      await supabase.storage.from('post-images').upload(path, image);
      urls.add(supabase.storage.from('post-images').getPublicUrl(path));
    }
    return urls;
  }

  Future<void> _deleteImagesByUrl(List<String> urls) async {
    final paths = urls.map((url) {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final index = segments.indexOf('post-images');
      return segments.sublist(index + 1).join('/');
    }).toList();
    await supabase.storage.from('post-images').remove(paths);
  }

  Future<void> _hydrateMyReactions(List<PostModel> targetPosts) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || targetPosts.isEmpty) return;

    final ids = targetPosts.map((p) => p.id).toList();

    final myLikes = await supabase
        .from('likes')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', ids);
    final myReposts = await supabase
        .from('reposts')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', ids);

    final likedIds = (myLikes as List).map((r) => r['post_id'] as String).toSet();
    final repostedIds = (myReposts as List).map((r) => r['post_id'] as String).toSet();

    for (var i = 0; i < targetPosts.length; i++) {
      targetPosts[i] = targetPosts[i].copyWith(
        isLikedByMe: likedIds.contains(targetPosts[i].id),
        isRepostedByMe: repostedIds.contains(targetPosts[i].id),
      );
    }
  }

  final Set<String> _pendingLikeToggles = {};
  final Set<String> _pendingRepostToggles = {};

  Future<void> toggleLike(String postId, String userId) async {
    if (_pendingLikeToggles.contains(postId)) return;
    final index = posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final original = posts[index];
    final wasLiked = original.isLikedByMe;

    _pendingLikeToggles.add(postId);
    posts[index] = original.copyWith(
      isLikedByMe: !wasLiked,
      likeCount: wasLiked ? original.likeCount - 1 : original.likeCount + 1,
    );
    notifyListeners();

    try {
      if (wasLiked) {
        await supabase.from('likes').delete().eq('post_id', postId).eq('user_id', userId);
      } else {
        await supabase.from('likes').insert({'post_id': postId, 'user_id': userId});
      }
    } catch (e) {
      debugPrint('toggleLike failed, reverting: $e');
      final revertIndex = posts.indexWhere((p) => p.id == postId);
      if (revertIndex != -1) posts[revertIndex] = original;
      notifyListeners();
    } finally {
      _pendingLikeToggles.remove(postId);
    }
  }

  Future<void> toggleRepost(String postId, String userId) async {
    if (_pendingRepostToggles.contains(postId)) return;
    final index = posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final original = posts[index];
    final wasReposted = original.isRepostedByMe;

    _pendingRepostToggles.add(postId);
    posts[index] = original.copyWith(
      isRepostedByMe: !wasReposted,
      repostCount: wasReposted ? original.repostCount - 1 : original.repostCount + 1,
    );
    notifyListeners();

    try {
      if (wasReposted) {
        await supabase.from('reposts').delete().eq('post_id', postId).eq('user_id', userId);
      } else {
        await supabase.from('reposts').insert({'post_id': postId, 'user_id': userId});
      }
    } catch (e) {
      debugPrint('toggleRepost failed, reverting: $e');
      final revertIndex = posts.indexWhere((p) => p.id == postId);
      if (revertIndex != -1) posts[revertIndex] = original;
      notifyListeners();
    } finally {
      _pendingRepostToggles.remove(postId);
    }
  }
}