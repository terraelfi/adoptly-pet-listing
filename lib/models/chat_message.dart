import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final Timestamp timestamp;
  final bool isRead;
  final String? mediaUrl;
  final String? mediaType;
  final double? locationLat;
  final double? locationLng;
  final String? locationLabel;

  ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.timestamp,
    required this.isRead,
    this.mediaUrl,
    this.mediaType,
    this.locationLat,
    this.locationLng,
    this.locationLabel,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderAvatar: data['senderAvatar'],
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
      mediaUrl: data['mediaUrl'],
      mediaType: data['mediaType'],
      locationLat:
          (data['locationLat'] is num)
              ? (data['locationLat'] as num).toDouble()
              : null,
      locationLng:
          (data['locationLng'] is num)
              ? (data['locationLng'] as num).toDouble()
              : null,
      locationLabel: data['locationLabel'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'timestamp': timestamp,
      'isRead': isRead,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'locationLabel': locationLabel,
    };
  }
}
