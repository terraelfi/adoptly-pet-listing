import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ChatRoom {
  final String id;
  final List<String> participantIds;
  final Map<String, dynamic> participants;
  final Map<String, String> participantNames;
  final Map<String, String>? participantAvatars;
  final String? lastMessageContent;
  final Timestamp lastMessageTime;
  final String? petId;
  final String? petName;
  final String? petImageUrl;

  ChatRoom({
    required this.id,
    required this.participantIds,
    required this.participants,
    required this.participantNames,
    this.participantAvatars,
    this.lastMessageContent,
    required this.lastMessageTime,
    this.petId,
    this.petName,
    this.petImageUrl,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Extract participant names
    Map<String, String> participantNames = {};
    if (data['participantNames'] != null) {
      try {
        final rawNames = data['participantNames'] as Map<String, dynamic>;
        participantNames = Map<String, String>.from(
          rawNames.map(
            (key, value) => MapEntry(key, value?.toString() ?? 'Unknown'),
          ),
        );
      } catch (e) {
        print('Error parsing participantNames: $e');
      }
    }

    // Extract participant avatars
    Map<String, String>? participantAvatars;
    if (data['participantAvatars'] != null) {
      try {
        final rawAvatars = data['participantAvatars'] as Map<String, dynamic>;
        participantAvatars = Map<String, String>.from(
          rawAvatars.map(
            (key, value) => MapEntry(key, value?.toString() ?? ''),
          ),
        );
      } catch (e) {
        print('Error parsing participantAvatars: $e');
      }
    }

    return ChatRoom(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participants: Map<String, dynamic>.from(data['participants'] ?? {}),
      participantNames: participantNames,
      participantAvatars: participantAvatars,
      lastMessageContent: data['lastMessageContent'],
      lastMessageTime: data['lastMessageTime'] ?? Timestamp.now(),
      petId: data['petId'],
      petName: data['petName'],
      petImageUrl: data['petImageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      'participants': participants,
      'participantNames': participantNames,
      'participantAvatars': participantAvatars,
      'lastMessageContent': lastMessageContent,
      'lastMessageTime': lastMessageTime,
      'petId': petId,
      'petName': petName,
      'petImageUrl': petImageUrl,
    };
  }
}
