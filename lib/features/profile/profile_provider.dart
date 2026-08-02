import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/supabase_client.dart';
import 'profile_model.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileModel? profile;
  bool isLoading = false;

  Future<void> fetchProfile(String userId) async {
    isLoading = true;
    notifyListeners();

    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    profile = ProfileModel.fromMap(data);
    isLoading = false;
    notifyListeners();
  }

  Future<void> updateName(String userId, String newName) async {
    await supabase.from('profiles').update({'name': newName}).eq('id', userId);
    await fetchProfile(userId);
  }

  Future<void> uploadAvatar(String userId, XFile file) async {
    if (profile?.avatarUrl != null) {
      await _deleteAvatarFile(userId, profile!.avatarUrl!);
    }

    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    final fileName = '${const Uuid().v4()}.$ext';
    final path = '$userId/$fileName';
    final bytes = await file.readAsBytes();

    await supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: file.mimeType ?? 'image/jpeg'),
        );
    final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);

    await supabase
        .from('profiles')
        .update({'avatar_url': publicUrl})
        .eq('id', userId);

    await fetchProfile(userId);
  }

  Future<void> deleteAvatar(String userId) async {
    if (profile?.avatarUrl == null) return;
    await _deleteAvatarFile(userId, profile!.avatarUrl!);
    await supabase.from('profiles').update({'avatar_url': null}).eq('id', userId);
    await fetchProfile(userId);
  }

  Future<void> _deleteAvatarFile(String userId, String url) async {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    final index = segments.indexOf('avatars');
    final path = segments.sublist(index + 1).join('/');
    await supabase.storage.from('avatars').remove([path]);
  }
}