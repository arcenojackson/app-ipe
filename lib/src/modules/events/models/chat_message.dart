import 'package:cloud_firestore/cloud_firestore.dart';

class QuotedMessage {
  const QuotedMessage({
    required this.messageId,
    required this.text,
    required this.userName,
  });

  final String messageId;
  final String text;
  final String userName;

  factory QuotedMessage.fromJson(Map<String, dynamic> json) {
    return QuotedMessage(
      messageId: json['messageId']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'text': text,
        'userName': userName,
      };
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.text,
    required this.userId,
    required this.userName,
    required this.timestamp,
    this.mentionedUserIds = const [],
    this.isDeleted = false,
    this.quotedMessage,
  });

  final String id;
  final String text;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final List<String> mentionedUserIds;
  final bool isDeleted;
  final QuotedMessage? quotedMessage;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    // Parse timestamp
    DateTime timestamp;
    if (json['timestamp'] is Timestamp) {
      timestamp = (json['timestamp'] as Timestamp).toDate();
    } else if (json['timestamp'] is DateTime) {
      timestamp = json['timestamp'] as DateTime;
    } else {
      timestamp = DateTime.now();
    }

    // Parse quoted message
    QuotedMessage? quotedMessage;
    if (json['quotedMessageId'] != null ||
        json['quotedMessageText'] != null) {
      quotedMessage = QuotedMessage(
        messageId: json['quotedMessageId']?.toString() ?? '',
        text: json['quotedMessageText']?.toString() ?? '',
        userName: json['quotedMessageUserName']?.toString() ?? '',
      );
    }

    // Parse mentioned user IDs
    List<String> mentionedUserIds = [];
    if (json['mentionedUserIds'] is List) {
      mentionedUserIds = (json['mentionedUserIds'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      timestamp: timestamp,
      mentionedUserIds: mentionedUserIds,
      isDeleted: json['isDeleted'] == true,
      quotedMessage: quotedMessage,
    );
  }

  Map<String, dynamic> toJson() {
    final data = {
      'text': text,
      'userId': userId,
      'userName': userName,
      'timestamp': Timestamp.fromDate(timestamp),
      'mentionedUserIds': mentionedUserIds,
      'isDeleted': isDeleted,
    };

    if (quotedMessage != null) {
      data['quotedMessageId'] = quotedMessage!.messageId;
      data['quotedMessageText'] = quotedMessage!.text;
      data['quotedMessageUserName'] = quotedMessage!.userName;
    }

    return data;
  }

  ChatMessageModel copyWith({
    String? id,
    String? text,
    String? userId,
    String? userName,
    DateTime? timestamp,
    List<String>? mentionedUserIds,
    bool? isDeleted,
    QuotedMessage? quotedMessage,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      timestamp: timestamp ?? this.timestamp,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
      isDeleted: isDeleted ?? this.isDeleted,
      quotedMessage: quotedMessage ?? this.quotedMessage,
    );
  }
}
