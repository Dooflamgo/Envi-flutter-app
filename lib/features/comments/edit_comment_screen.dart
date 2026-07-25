import 'dart:io';
import 'package:envi/core/error_helper.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'comment_provider.dart';
import 'comment_model.dart';

class EditCommentScreen extends StatefulWidget {
  final CommentModel comment;
  const EditCommentScreen({super.key, required this.comment});

  @override
  State<EditCommentScreen> createState() => _EditCommentScreenState();
}

class _EditCommentScreenState extends State<EditCommentScreen> {
  late final TextEditingController _contentController;
  late List<String> _existingImageUrls;
  final List<String> _removedImageUrls = [];
  final List<File> _newImages = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.comment.content);
    _existingImageUrls = List.from(widget.comment.imageUrls);
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    setState(() => _newImages.addAll(picked.map((x) => File(x.path))));
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await context.read<CommentProvider>().updateComment(
            commentId: widget.comment.id,
            postId: widget.comment.postId,
            userId: widget.comment.userId,
            content: _contentController.text.trim(),
            existingImageUrls: _existingImageUrls,
            removedImageUrls: _removedImageUrls,
            newImages: _newImages,
          );
    if (mounted) {
      context.pop(true);
    }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Comment'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._existingImageUrls.map((url) => _ImageTile(
                      child: CachedNetworkImage(imageUrl: url, width: 80, height: 80, fit: BoxFit.cover),
                      onRemove: () => setState(() {
                        _existingImageUrls.remove(url);
                        _removedImageUrls.add(url);
                      }),
                    )),
                ..._newImages.asMap().entries.map((entry) => _ImageTile(
                      child: Image.file(entry.value, width: 80, height: 80, fit: BoxFit.cover),
                      onRemove: () => setState(() => _newImages.removeAt(entry.key)),
                    )),
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _ImageTile({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
        Positioned(
          top: 2, right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}