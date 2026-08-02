class ProfileModel {
  final String id;
  final String name;
  final String? avatarUrl;

  ProfileModel({required this.id, required this.name, this.avatarUrl});

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'],
      name: map['name'] ?? 'New User',
      avatarUrl: map['avatar_url'],
    );
  }
}