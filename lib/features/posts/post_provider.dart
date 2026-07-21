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
        .select('*, profiles!posts_user_id_fkey(name, avatar_url)')
        .order('created_at', ascending: false)
        .range(from, to);

    final newPosts = (data as List).map((e) => PostModel.fromMap(e)).toList();

    if (newPosts.length < _pageSize) hasMore = false;
    posts.addAll(newPosts);
    _page++;
  }

  Future<PostModel> fetchSinglePost(String postId) async {
    final data = await supabase
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(name, avatar_url)')
        .eq('id', postId)
        .single();
    return PostModel.fromMap(data);
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
}