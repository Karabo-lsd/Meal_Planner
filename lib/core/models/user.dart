class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  String get displayName {
    final parts = [firstName, lastName].where((s) => s != null && s.isNotEmpty).toList();
    return parts.isEmpty ? email : parts.join(' ');
  }

  /// Backward-compat alias — screens use user.name still.
  String? get name {
    final dn = displayName;
    return dn == email ? null : dn;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    String? firstName = json['first_name'] as String?;
    String? lastName = json['last_name'] as String?;

    // Fall back to legacy 'name' field
    if (firstName == null || firstName.isEmpty) {
      firstName = json['name'] as String?;
    }

    // Split 'full_name' (Supabase user metadata) into first/last
    if (firstName == null || firstName.isEmpty) {
      final full = json['full_name'] as String?;
      if (full != null && full.trim().isNotEmpty) {
        final parts = full.trim().split(' ');
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }
    }

    return User(
      id: json['id'].toString(),
      email: json['email'] as String,
      firstName: firstName,
      lastName: lastName,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }
}
