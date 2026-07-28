import 'package:envi/features/posts/post_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/nav_helpers.dart';
import '../auth/auth_provider.dart';
import '../posts/post_model.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostProvider>().fetchInitial();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<PostProvider>().fetchMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postProvider = context.watch<PostProvider>();
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Envi'),
        actions: [
          if (!isLoggedIn)
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Log in'),
            ),
        ],
      ),
      floatingActionButton: isLoggedIn
          ? FloatingActionButton(
              onPressed: () => context.push('/create-post'),
              child: const Icon(Icons.add),
            )
          : null,
      body: postProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<PostProvider>().fetchInitial(),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: postProvider.posts.length + (postProvider.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= postProvider.posts.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return PostCard(post: postProvider.posts[index]);
                },
              ),
            ),
    );
  }
}

class PostCard extends StatelessWidget {
  final PostModel post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => pushIfNotCurrent(context, '/post/${post.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => goToUserProfile(context, post.userId),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: post.authorAvatarUrl != null
                        ? CachedNetworkImageProvider(post.authorAvatarUrl!)
                        : null,
                    child: post.authorAvatarUrl == null ? const Icon(Icons.person, size: 18) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          timeago.format(post.createdAt),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(post.content, maxLines: 5, overflow: TextOverflow.ellipsis),
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ImagePreviewGrid(imageUrls: post.imageUrls),
            ],
            Row(
              children: [
                _ReactionButton(
                  icon: post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                  color: post.isLikedByMe ? Colors.red : Colors.grey.shade700,
                  count: post.likeCount,
                  onTap: () {
                    final userId = context.read<AuthProvider>().userId;
                    if (userId == null) {
                      context.push('/login');
                    } else {
                      context.read<PostProvider>().toggleLike(post.id, userId);
                    }
                  },
                ),
                const SizedBox(width: 20),
                _ReactionButton(
                  icon: Icons.repeat,
                  color: post.isRepostedByMe ? Colors.green : Colors.grey.shade700,
                  count: post.repostCount,
                  onTap: () {
                    final userId = context.read<AuthProvider>().userId;
                    if (userId == null) {
                      context.push('/login');
                    } else {
                      context.read<PostProvider>().toggleRepost(post.id, userId);
                    }
                  },
                ),
                const SizedBox(width: 20),
                Icon(Icons.mode_comment_outlined, size: 18, color: Colors.grey.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviewGrid extends StatelessWidget {
  final List<String> imageUrls;
  const _ImagePreviewGrid({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    final count = imageUrls.length;

    if (count == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: CachedNetworkImage(imageUrl: imageUrls[0], fit: BoxFit.cover),
        ),
      );
    }

    final visibleCount = count > 4 ? 4 : count;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final isLastVisible = index == visibleCount - 1 && count > 4;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(imageUrl: imageUrls[index], fit: BoxFit.cover),
              if (isLastVisible)
                Container(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.5),
                  alignment: Alignment.center,
                  child: Text(
                    '+${count - 4}',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;
  const _ReactionButton({required this.icon, required this.color, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text('$count', style: TextStyle(fontSize: 13, color: color)),
          ],
        ],
      ),
    );
  }
}