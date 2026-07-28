import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/supabase_client.dart';
import '../auth/auth_provider.dart';
import '../follows/follow_provider.dart';
import '../feed/feed_screen.dart';
import 'profile_provider.dart';
import 'profile_feed_item.dart';
import '../../core/error_helper.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _targetUserId;
  bool _isOwnProfile = false;

  String? _otherName;
  String? _otherAvatarUrl;
  bool _isLoadingOther = true;

  int _followerCount = 0;
  int _followingCount = 0;

  List<ProfileFeedItem> _feedItems = [];
  bool _isLoadingFeed = true;

  final _nameController = TextEditingController();
  bool _isEditingName = false;

  @override
  void initState() {
    super.initState();
    final myUserId = context.read<AuthProvider>().userId;
    _targetUserId = widget.userId ?? myUserId;
    _isOwnProfile = _targetUserId != null && _targetUserId == myUserId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    if (_targetUserId == null) return;

    if (_isOwnProfile) {
      await context.read<ProfileProvider>().fetchProfile(_targetUserId!);
    } else {
      final data =
          await supabase.from('profiles').select('name, avatar_url').eq('id', _targetUserId!).single();
      if (mounted) {
        setState(() {
          _otherName = data['name'];
          _otherAvatarUrl = data['avatar_url'];
          _isLoadingOther = false;
        });
      }
    }

    await _loadFollowStats();
    await _loadFeed();
  }

  Future<void> _loadFollowStats() async {
    final followers = await supabase.from('follows').select('follower_id').eq('following_id', _targetUserId!);
    final following = await supabase.from('follows').select('following_id').eq('follower_id', _targetUserId!);
    if (mounted) {
      setState(() {
        _followerCount = (followers as List).length;
        _followingCount = (following as List).length;
      });
    }
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoadingFeed = true);
    final items = await fetchProfileFeed(_targetUserId!);
    if (mounted) setState(() { _feedItems = items; _isLoadingFeed = false; });
  }

  Future<void> _pickAndUploadAvatar() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    try {
      // ignore: use_build_context_synchronously
      await context.read<ProfileProvider>().uploadAvatar(userId, File(picked.path));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _deleteAvatar(String userId) async {
    try {
      await context.read<ProfileProvider>().deleteAvatar(userId);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _updateName(String userId, String newName) async {
    try {
      await context.read<ProfileProvider>().updateName(userId, newName);
      if (mounted) setState(() => _isEditingName = false);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targetUserId == null) {
      return const Scaffold(body: Center(child: Text('No profile to show')));
    }

    return Scaffold(
      appBar: AppBar(
        leading: _isOwnProfile
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/feed'),
              ),
        title: Text(_isOwnProfile ? 'Profile' : (_otherName ?? '')),
        actions: [
          if (_isOwnProfile)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Log out?'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                );

                if (shouldLogout != true) return;

                // ignore: use_build_context_synchronously
                await context.read<AuthProvider>().logout();
                if (mounted && context.mounted) context.go('/login');
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            if (_isLoadingFeed)
              const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
              )
            else if (_feedItems.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('No posts yet', style: TextStyle(color: Colors.grey.shade600))),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildFeedTile(_feedItems[index]),
                  childCount: _feedItems.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedTile(ProfileFeedItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.isRepost)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 10, bottom: 2),
            child: Row(
              children: [
                Icon(Icons.repeat, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text('${item.reposterName} reposted', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        PostCard(post: item.post),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final myUserId = context.read<AuthProvider>().userId;

    final avatarUrl = _isOwnProfile ? profileProvider.profile?.avatarUrl : _otherAvatarUrl;
    final name = _isOwnProfile ? profileProvider.profile?.name : _otherName;
    final isLoadingHeader = _isOwnProfile ? profileProvider.isLoading : _isLoadingOther;

    if (isLoadingHeader || name == null) {
      return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                  child: avatarUrl == null ? const Icon(Icons.person, size: 48, color: Colors.grey) : null,
                ),
                if (_isOwnProfile)
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isOwnProfile && avatarUrl != null)
            TextButton(
              onPressed: () => _deleteAvatar(myUserId!),
              child: const Text('Remove photo', style: TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 8),
          _isOwnProfile
              ? (_isEditingName
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController..text = name,
                            decoration: const InputDecoration(labelText: 'Name'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () => _updateName(myUserId!, _nameController.text.trim()),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name, style: Theme.of(context).textTheme.titleLarge),
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => setState(() => _isEditingName = true)),
                      ],
                    ))
              : Text(name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(children: [
                Text('$_followerCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Followers', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
              const SizedBox(width: 40),
              Column(children: [
                Text('$_followingCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Following', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
            ],
          ),
          if (!_isOwnProfile) ...[
            const SizedBox(height: 16),
            _buildFollowButton(context),
          ],
        ],
      ),
    );
  }

  Widget _buildFollowButton(BuildContext context) {
    final followProvider = context.watch<FollowProvider>();
    final isFollowing = followProvider.isFollowing(_targetUserId!);

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: isFollowing
            ? FilledButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87)
            : null,
        onPressed: () async {
          final myUserId = context.read<AuthProvider>().userId;
          if (myUserId == null) {
            context.push('/login');
            return;
          }
          await followProvider.toggleFollow(_targetUserId!, myUserId);
          _loadFollowStats();
        },
        child: Text(isFollowing ? 'Following' : 'Follow'),
      ),
    );
  }
}