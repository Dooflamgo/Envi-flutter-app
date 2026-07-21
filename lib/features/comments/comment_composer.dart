import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CommentComposer extends StatefulWidget {
  final String? replyingToName;
  final VoidCallback? onCancelReply;
  final Future<void> Function(String content, List<File> images) onSubmit;

  const CommentComposer({
    super.key,
    this.replyingToName,
    this.onCancelReply,
    required this.onSubmit,
  });

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _controller = TextEditingController();
  final List<File> _images = [];
  bool _isSubmitting = false;

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked.map((x) => File(x.path))));
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty && _images.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(_controller.text.trim(), _images);
      _controller.clear();
      setState(() => _images.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.replyingToName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text('Replying to ${widget.replyingToName}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onCancelReply,
                  child: const Icon(Icons.close, size: 14),
                ),
              ],
            ),
          ),
        if (_images.isNotEmpty)
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_images[index], width: 60, height: 60, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(index)),
                        child: const CircleAvatar(
                          radius: 9,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 11, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.image_outlined), onPressed: _pickImages),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Write a comment...',
                  border: InputBorder.none,
                ),
              ),
            ),
            _isSubmitting
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(icon: const Icon(Icons.send), onPressed: _submit),
          ],
        ),
      ],
    );
  }
}