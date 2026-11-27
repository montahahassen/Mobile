/// Authenticated user session returned by `POST /auth`.
class AuthSession {
  final String token;
  final int userId;
  final String email;
  final String? firstName;
  final String? lastName;

  /// Creates an immutable [AuthSession].
  const AuthSession({
    required this.token,
    required this.userId,
    required this.email,
    this.firstName,
    this.lastName,
  });

  /// API Platform IRI identifying this user (`/api/users/{id}`).
  String get userIri => '/api/users/$userId';

  /// Friendly display name falling back to [email] when names are absent.
  String get displayName {
    final parts = [firstName, lastName]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? email : parts.join(' ');
  }

  /// Parses the payload returned by `POST /auth` or local storage.
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      userId: (json['id'] as num).toInt(),
      email: (json['email'] as String?) ?? '',
      firstName: (json['firstname'] ?? json['firstName']) as String?,
      lastName: (json['lastname'] ?? json['lastName']) as String?,
    );
  }

  /// Serializes this session for local persistence.
  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'id': userId,
      'email': email,
      'firstname': firstName,
      'lastname': lastName,
    };
  }
}
