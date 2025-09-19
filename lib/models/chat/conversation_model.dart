import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'user_model.dart';
import 'message_model.dart';

/// Represents a single, immutable conversation, either direct or group.
///
/// This class is designed to handle the optimized data structure from the
/// backend, including performance-critical fields like `unreadCount` and
/// `isArchived`, which are essential for a responsive UI.
@immutable
class Conversation extends Equatable {
  /// The UUID of the conversation.
  final String id;

  /// The type of conversation, either 'direct' or 'group'.
  final String type;

  /// The title of the conversation, typically for group chats.
  final String? title;

  /// The photo URL of the conversation, typically for group chats.
  final String? photoUrl;

  /// The list of all members in the conversation.
  final List<ChatUser> members;

  /// The last message sent in the conversation. Can be null for new conversations.
  final Message? lastMessage;

  /// The group setting for how new members can join (e.g., 'admin_approval').
  final String? joinPolicy;

  /// The group setting for who can send messages (e.g., 'admins_only').
  final String? messagingPolicy;

  /// [NEW] The number of unread messages for the current user in this conversation.
  /// Provided directly by the backend for high performance.
  final int unreadCount;

  /// [NEW] A flag indicating if the current user has archived this conversation.
  final bool isArchived;

  /// [NEW] A flag indicating if the current user is a member of this conversation.
  final bool isMember;

  const Conversation({
    required this.id,
    required this.type,
    this.title,
    this.photoUrl,
    required this.members,
    this.lastMessage,
    this.joinPolicy,
    this.messagingPolicy,
    required this.unreadCount,
    required this.isArchived,
    this.isMember = true,
  });

  @override
  List<Object?> get props => [
    id,
    type,
    title,
    photoUrl,
    members,
    lastMessage,
    joinPolicy,
    messagingPolicy,
    unreadCount,
    isArchived,
    isMember,
  ];

  /// Creates a Conversation instance from a JSON map returned by the backend.
  factory Conversation.fromJson(Map<String, dynamic> json) {
    var membersList = <ChatUser>[];
    if (json['Members'] != null) {
      membersList = (json['Members'] as List)
          .map(
            (memberJson) =>
                ChatUser.fromJson(memberJson as Map<String, dynamic>),
          )
          .toList();
    }

    return Conversation(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String?,
      photoUrl: json['photoUrl'] as String?,
      members: membersList,
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      joinPolicy: json['joinPolicy'] as String?,
      messagingPolicy: json['messagingPolicy'] as String?,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isArchived: json['isArchived'] as bool? ?? false,
      isMember: json['isMember'] as bool? ?? true,
    );
  }

  /// Converts the Conversation instance to a JSON map for local storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'photoUrl': photoUrl,
      'members': members.map((member) => member.toJson()).toList(),
      'lastMessage': lastMessage?.toJson(),
      'joinPolicy': joinPolicy,
      'messagingPolicy': messagingPolicy,
      'unreadCount': unreadCount,
      'isArchived': isArchived,
      'isMember': isMember,
    };
  }

  /// Gets the appropriate title for the UI based on the conversation type.
  /// For direct chats, it returns the name of the other user.
  String displayTitle(String currentUserId) {
    if (type == 'group') {
      return title ?? 'Group Chat';
    } else {
      final otherUser = members.firstWhere(
        (member) => member.enrollmentNumber != currentUserId,
        orElse: () =>
            const ChatUser(enrollmentNumber: '', name: 'Unknown User'),
      );
      return otherUser.name;
    }
  }

  /// Gets the appropriate photo URL for the UI based on the conversation type.
  /// For direct chats, it returns the photo of the other user.
  String? displayPhotoUrl(String currentUserId) {
    if (type == 'group') {
      return photoUrl;
    } else {
      final otherUser = members.firstWhere(
        (member) => member.enrollmentNumber != currentUserId,
        orElse: () => const ChatUser(enrollmentNumber: '', name: 'Unknown'),
      );
      return otherUser.photoUrl;
    }
  }

  /// Creates a copy of this Conversation with the given fields replaced
  /// with the new values.
  Conversation copyWith({
    String? id,
    String? type,
    String? title,
    String? photoUrl,
    List<ChatUser>? members,
    Message? lastMessage,
    String? joinPolicy,
    String? messagingPolicy,
    int? unreadCount,
    bool? isArchived,
    bool? isMember,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      photoUrl: photoUrl ?? this.photoUrl,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      joinPolicy: joinPolicy ?? this.joinPolicy,
      messagingPolicy: messagingPolicy ?? this.messagingPolicy,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      isMember: isMember ?? this.isMember,
    );
  }
}
