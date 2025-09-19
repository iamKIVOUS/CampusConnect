import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class ChatUser extends Equatable {
  final String enrollmentNumber;
  final String name;
  final String? photoUrl;
  final String? role;

  const ChatUser({
    required this.enrollmentNumber,
    required this.name,
    this.photoUrl,
    this.role,
  });

  @override
  // --- DEFINITIVE FIX: CORRECT EQUALITY ---
  // Two ChatUser objects are now considered equal if and only if their
  // enrollmentNumber is the same. This fixes the Set.remove issue.
  List<Object?> get props => [enrollmentNumber];

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    String? groupRole;
    if (json['Member'] != null && json['Member'] is Map) {
      groupRole = json['Member']['role'] as String?;
    } else {
      groupRole = json['role'] as String?;
    }

    return ChatUser(
      enrollmentNumber: json['enrollment_number'] as String? ?? 'unknown_user',
      name: json['name'] as String? ?? 'Unnamed User',
      photoUrl: json['photo_url'] as String?,
      role: groupRole,
    );
  }

  // toJson and copyWith methods remain unchanged.
  Map<String, dynamic> toJson() {
    return {
      'enrollment_number': enrollmentNumber,
      'name': name,
      'photo_url': photoUrl,
      'role': role,
    };
  }

  ChatUser copyWith({
    String? enrollmentNumber,
    String? name,
    String? photoUrl,
    String? role,
  }) {
    return ChatUser(
      enrollmentNumber: enrollmentNumber ?? this.enrollmentNumber,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
    );
  }
}
