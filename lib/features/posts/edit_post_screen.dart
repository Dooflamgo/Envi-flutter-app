import 'dart:io';
import 'package:envi/core/error_helper.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'post_provider.dart';
import 'post_model.dart';

class EditPostScreen extends StatefulWidget {
  final PostModel post;
  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final TextEditingController _contentController;
  late List<String> _existingImageUrls;
  final List<String> _removedImageUrls = [];
  final List<File> _newImages = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.content);
    _existingImageUrls = List.from(widget.post.imageUrls);
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    setState(() => _newImages.addAll(picked.map((x) => File(x.path))));
  }

  void _removeExisting(String url) {
    setState(() {
      _existingImageUrls.remove(url);
      _removedImageUrls.add(url);
    });
  }

  void _removeNew(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await context.read<PostProvider>().updatePost(
            postId: widget.post.id,
            userId: widget.post.userId,
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
        title: const Text('Edit Post'),
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
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._existingImageUrls.map((url) => _ImageTile(
                      child: CachedNetworkImage(imageUrl: url, width: 90, height: 90, fit: BoxFit.cover),
                      onRemove: () => _removeExisting(url),
                    )),
                ..._newImages.asMap().entries.map((entry) => _ImageTile(
                      child: Image.file(entry.value, width: 90, height: 90, fit: BoxFit.cover),
                      onRemove: () => _removeNew(entry.key),
                    )),
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 90,
                    height: 90,
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
          top: 2,
          right: 2,
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