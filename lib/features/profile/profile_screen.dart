import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../auth/auth_provider.dart';
import 'profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isEditingName = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().userId;
      if (userId != null) {
        context.read<ProfileProvider>().fetchProfile(userId);
      }
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    // ignore: use_build_context_synchronously
    await context.read<ProfileProvider>().uploadAvatar(userId, File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;
    final userId = context.read<AuthProvider>().userId;

    if (profileProvider.isLoading || profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
        body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: profile.avatarUrl != null
                      ? CachedNetworkImageProvider(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null
                      ? const Icon(Icons.person, size: 56, color: Colors.grey)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (profile.avatarUrl != null)
            Center(
              child: TextButton(
                onPressed: () => profileProvider.deleteAvatar(userId!),
                child: const Text('Remove photo', style: TextStyle(color: Colors.red)),
              ),
            ),
          const SizedBox(height: 24),
          _isEditingName
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController..text = profile.name,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () async {
                        await profileProvider.updateName(userId!, _nameController.text.trim());
                        setState(() => _isEditingName = false);
                      },
                    ),
                  ],
                )
              : ListTile(
                  title: Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _isEditingName = true),
                  ),
                ),
        ],
      ),
    );
  }
}