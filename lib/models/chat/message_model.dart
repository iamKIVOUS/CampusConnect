import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'message_status.dart';
import 'user_model.dart';

@immutable
class Message extends Equatable {
  final int id;
  final String conversationId;
  final ChatUser? sender;
  final String? body;
  final DateTime createdAt;
  final String type;
  final String? clientMsgId;
  final String? attachmentUrl;
  final String? attachmentType;
  final MessageStatus status;
  // This field is kept for potential future features but is no longer central to status display.
  final Map<String, DateTime> readReceipts;

  const Message({
    required this.id,
    required this.conversationId,
    this.sender,
    this.body,
    required this.createdAt,
    required this.type,
    this.clientMsgId,
    this.attachmentUrl,
    this.attachmentType,
    this.status = MessageStatus.sent,
    this.readReceipts = const {},
  });

  @override
  List<Object?> get props => [
    id,
    conversationId,
    sender,
    body,
    createdAt,
    type,
    clientMsgId,
    attachmentUrl,
    attachmentType,
    status,
    readReceipts,
  ];

  static Message? fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final createdAtString =
        json['createdAt'] as String? ?? json['created_at'] as String?;
    final conversationId = json['conversationId'] as String?;

    if (idValue == null || createdAtString == null || conversationId == null) {
      debugPrint('Failed to parse Message: Missing essential fields.');
      return null;
    }

    final int id;
    if (idValue is String) {
      id = int.tryParse(idValue) ?? 0;
    } else if (idValue is int) {
      id = idValue;
    } else {
      return null;
    }

    // --- FIX ---
    // This is the critical fix. We now parse the 'status' string from the JSON
    // and map it to our MessageStatus enum.
    MessageStatus messageStatus = MessageStatus.sent; // Default value
    if (json['status'] is String) {
      messageStatus = MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      );
    }

    return Message(
      id: id,
      conversationId: conversationId,
      sender: json['sender'] != null
          ? ChatUser.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      body: json['body'] as String?,
      createdAt: DateTime.parse(createdAtString),
      type: json['type'] as String? ?? 'user',
      clientMsgId: json['clientMsgId'] as String?,
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentType: json['attachmentType'] as String?,
      status: messageStatus, // Assign the parsed status here.
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'sender': sender?.toJson(),
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'type': type,
      'clientMsgId': clientMsgId,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
      'status': status.name,
      'readReceipts': readReceipts.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    };
  }

  Message copyWith({
    int? id,
    String? conversationId,
    ChatUser? sender,
    String? body,
    DateTime? createdAt,
    String? type,
    String? clientMsgId,
    String? attachmentUrl,
    String? attachmentType,
    MessageStatus? status,
    Map<String, DateTime>? readReceipts,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      clientMsgId: clientMsgId ?? this.clientMsgId,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      status: status ?? this.status,
      readReceipts: readReceipts ?? this.readReceipts,
    );
  }
}
