class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.companyId,
    this.companyName,
    this.isVerified = false,
    this.lastLoginAt,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? companyId;
  final String? companyName;
  final bool isVerified;
  final DateTime? lastLoginAt;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final company = json['company'];
    final companyJson = company is Map<String, dynamic> ? company : null;
    return AppUser(
      id: json['id'].toString(),
      name: (json['name'] ?? json['full_name'] ?? json['email']).toString(),
      email: json['email'].toString(),
      role: json['role'].toString(),
      companyId: (json['company_id'] ?? companyJson?['id'])?.toString(),
      companyName:
          (json['company_name'] ??
                  companyJson?['name'] ??
                  companyJson?['legal_name'])
              ?.toString(),
      isVerified:
          json['is_verified'] as bool? ??
          json['verified'] as bool? ??
          json['email_verified'] as bool? ??
          json['email_verified_at'] != null,
      lastLoginAt: _dateFromJson(
        json['last_login_at'] ?? json['last_login'] ?? json['last_sign_in_at'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'company_id': companyId,
    'company_name': companyName,
    'is_verified': isVerified,
    'last_login_at': lastLoginAt?.toIso8601String(),
  };

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? companyId,
    String? companyName,
    bool? isVerified,
    DateTime? lastLoginAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      isVerified: isVerified ?? this.isVerified,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  static DateTime? _dateFromJson(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
