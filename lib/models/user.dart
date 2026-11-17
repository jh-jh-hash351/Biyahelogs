class User {
  final int id;
  final String username;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.username,
    required this.createdAt,
  });

  factory User.fromMap(Map<String, Object?> map) {
    return User(
      id: map['id'] as int,
      username: map['username'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
