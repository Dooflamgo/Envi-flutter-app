import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/supabase_client.dart';
import 'comment_model.dart';

class CommentProvider extends ChangeNotifier {
  final List<CommentModel> comments = [];
  bool isLoading = false;

  Future<void> fetchComments(String postId) async {
    isLoading = true;
    notifyListeners();

    try {
      final data = await supabase
          .from('comments')
          .select('*, profiles(name, avatar_url)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      comments
        ..clear()
        ..addAll((data as List).map((e) => CommentModel.fromMap(e)));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addComment({
    required String postId,
    required String userId,
    required String content,
    String? parentCommentId,
    required List<XFile> images,
  }) async {
    final commentId = const Uuid().v4();
    final imageUrls = await _uploadImages(userId, commentId, images);

    await supabase.from('comments').insert({
      'id': commentId,
      'post_id': postId,
      'user_id': userId,
      'parent_comment_id': parentCommentId,
      'content': content,
      'image_urls': imageUrls,
    });

    await fetchComments(postId);
  }

  Future<void> updateComment({
    required String commentId,
    required String postId,
    required String userId,
    required String content,
    required List<String> existingImageUrls,
    required List<String> removedImageUrls,
    required List<XFile> newImages,
  }) async {
    if (removedImageUrls.isNotEmpty) {
      await _deleteImagesByUrl(removedImageUrls);
    }

    final newUrls = await _uploadImages(userId, commentId, newImages);
    final finalUrls = [...existingImageUrls, ...newUrls];

    await supabase.from('comments').update({
      'content': content,
      'image_urls': finalUrls,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', commentId);

    await fetchComments(postId);
  }

  Future<void> deleteComment(String commentId, String postId, String userId) async {
    final folderPath = '$userId/$commentId';
    final files = await supabase.storage.from('comment-images').list(path: folderPath);
    if (files.isNotEmpty) {
      final paths = files.map((f) => '$folderPath/${f.name}').toList();
      await supabase.storage.from('comment-images').remove(paths);
    }

    await supabase.from('comments').delete().eq('id', commentId);
    comments.removeWhere((c) => c.id == commentId || c.parentCommentId == commentId);
    notifyListeners();
  }

  Future<List<String>> _uploadImages(String userId, String commentId, List<XFile> images) async {
    final urls = <String>[];
    for (final image in images) {
      final ext = image.name.contains('.') ? image.name.split('.').last : 'jpg';
      final fileName = '${const Uuid().v4()}.$ext';
      final path = '$userId/$commentId/$fileName';
      final bytes = await image.readAsBytes();
      await supabase.storage.from('comment-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: image.mimeType ?? 'image/jpeg'),
          );
      urls.add(supabase.storage.from('comment-images').getPublicUrl(path));
    }
    return urls;
  }

  Future<void> _deleteImagesByUrl(List<String> urls) async {
    final paths = urls.map((url) {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final index = segments.indexOf('comment-images');
      return segments.sublist(index + 1).join('/');
    }).toList();
    await supabase.storage.from('comment-images').remove(paths);
  }

  List<CommentModel> topLevel() => comments.where((c) => c.parentCommentId == null).toList();

  List<CommentModel> repliesTo(String commentId) =>
      comments.where((c) => c.parentCommentId == commentId).toList();
}