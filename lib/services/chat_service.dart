import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final cloudinary = CloudinaryPublic('dhzjdkye9', 'nmorlr7k', cache: false);

  // Collection references
  final CollectionReference _chatRoomsCollection = FirebaseFirestore.instance
      .collection('chatRooms');

  // Create a new chat room
  Future<String> createChatRoom(ChatRoom chatRoom) async {
    try {
      // Sort participant IDs to ensure consistent ordering
      final sortedParticipantIds = List<String>.from(chatRoom.participantIds)
        ..sort();

      // Different query logic for pet-specific vs general chats
      if (chatRoom.petId != null && chatRoom.petId!.isNotEmpty) {
        // Pet-specific chat: look for existing chat with same participants AND same petId
        debugPrint('Looking for pet-specific chat for pet: ${chatRoom.petId}');
        
        var existingPetChat =
            await _chatRoomsCollection
                .where('participantIds', isEqualTo: sortedParticipantIds)
                .where('petId', isEqualTo: chatRoom.petId)
                .get();

        if (existingPetChat.docs.isNotEmpty) {
          debugPrint(
            'Using existing pet-specific chat room: ${existingPetChat.docs.first.id}',
          );
          return existingPetChat.docs.first.id;
        }
      } else {
        // General user-to-user chat: look for existing chat with same participants but NO petId
        debugPrint('Looking for general chat between users');
        
        // Query for chats with these participants
        final existingChats =
            await _chatRoomsCollection
                .where('participantIds', isEqualTo: sortedParticipantIds)
                .get();

        // Filter client-side to find chats where petId is null or empty
        for (var doc in existingChats.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final petId = data['petId'];
          
          // Check if this is a general chat (no pet associated)
          if (petId == null || (petId is String && petId.isEmpty)) {
            debugPrint(
              'Using existing general chat room: ${doc.id}',
            );
            return doc.id;
          }
        }
      }

      // Create new chat room with sorted participant IDs
      final chatRoomMap = chatRoom.toMap();
      chatRoomMap['participantIds'] = sortedParticipantIds;

      final docRef = await _chatRoomsCollection.add(chatRoomMap);
      final chatType = chatRoom.petId != null ? 'pet-specific' : 'general';
      debugPrint('Created new $chatType chat room: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating chat room: $e');
      throw Exception('Failed to create chat room');
    }
  }

  // Get all chat rooms for a user
  Stream<List<ChatRoom>> getChatRoomsForUser(String userId) {
    debugPrint('Fetching chat rooms for user: $userId');

    try {
      // Avoid composite index requirement by not ordering in Firestore.
      // We'll sort client-side by lastMessageTime desc.
      return _chatRoomsCollection
          .where('participantIds', arrayContains: userId)
          .snapshots()
          .map((snapshot) {
            debugPrint('Got ${snapshot.docs.length} chat rooms from Firestore');

            final chatRooms =
                snapshot.docs
                    .map((doc) {
                      try {
                        return ChatRoom.fromFirestore(doc);
                      } catch (e) {
                        debugPrint('Error parsing chat room ${doc.id}: $e');
                        return null;
                      }
                    })
                    .where((room) => room != null)
                    .cast<ChatRoom>()
                    .toList();

            // Sort by lastMessageTime descending on client
            chatRooms.sort(
              (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
            );

            return chatRooms;
          })
          .handleError((error) {
            debugPrint('Error in chat rooms stream: $error');
            return <ChatRoom>[];
          });
    } catch (e) {
      debugPrint('Error setting up chat rooms stream: $e');
      return Stream.value(<ChatRoom>[]);
    }
  }

  // Send a text message
  Future<void> sendMessage(ChatMessage message) async {
    try {
      final chatRoomRef = _chatRoomsCollection.doc(message.chatRoomId);
      final messagesCollection = chatRoomRef.collection('messages');

      // Add message to subcollection
      await messagesCollection.add(message.toMap());

      // Update last message in chat room
      await chatRoomRef.update({
        'lastMessageContent': message.content,
        'lastMessageTime': message.timestamp,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      throw Exception('Failed to send message');
    }
  }

  // Send a media message (image or file)
  Future<void> sendMediaMessage({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String mediaType,
    required List<int> mediaBytes,
    required String fileName,
  }) async {
    try {
      // First write bytes to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );
      await tempFile.writeAsBytes(mediaBytes);

      // Upload media to Cloudinary using file
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          tempFile.path,
          resourceType:
              mediaType == 'image'
                  ? CloudinaryResourceType.Image
                  : CloudinaryResourceType.Auto,
          folder: 'chat_media/$chatRoomId',
        ),
      );

      // Delete temp file after upload
      await tempFile.delete();

      final mediaUrl = response.secureUrl;

      // Create and send message with media
      final message = ChatMessage(
        id: '',
        chatRoomId: chatRoomId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        content: mediaType == 'image' ? '📷 Image' : '📎 File',
        timestamp: Timestamp.now(),
        isRead: false,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );

      await sendMessage(message);
    } catch (e) {
      debugPrint('Error sending media message: $e');
      throw Exception('Failed to send media message');
    }
  }

  // Send a location message
  Future<void> sendLocationMessage({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    try {
      final message = ChatMessage(
        id: '',
        chatRoomId: chatRoomId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        content: 'Shared a location',
        timestamp: Timestamp.now(),
        isRead: false,
        mediaUrl: null,
        mediaType: 'location',
        locationLat: latitude,
        locationLng: longitude,
        locationLabel: label,
      );
      await sendMessage(message);
    } catch (e) {
      debugPrint('Error sending location message: $e');
      throw Exception('Failed to send location');
    }
  }

  // Get messages for a chat room
  Stream<List<ChatMessage>> getMessages(String chatRoomId) {
    return _chatRoomsCollection
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList();
        });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(
    String chatRoomId,
    String currentUserId,
  ) async {
    try {
      // Check if the chat room document exists
      final chatRoomDoc = await _chatRoomsCollection.doc(chatRoomId).get();
      if (!chatRoomDoc.exists) {
        debugPrint('Chat room does not exist: $chatRoomId');
        return; // Return silently instead of throwing
      }

      final messagesCollection = _chatRoomsCollection
          .doc(chatRoomId)
          .collection('messages');

      final unreadMessages =
          await messagesCollection
              .where('isRead', isEqualTo: false)
              .where('senderId', isNotEqualTo: currentUserId)
              .get();

      // If there are no unread messages, simply return
      if (unreadMessages.docs.isEmpty) {
        debugPrint('No unread messages to mark as read');
        return;
      }

      final batch = _firestore.batch();

      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      debugPrint(
        'Successfully marked ${unreadMessages.docs.length} messages as read',
      );
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
      // Don't throw the exception, just log it
      // This prevents the chat functionality from breaking
    }
  }

  // Delete a chat room
  Future<void> deleteChatRoom(String chatRoomId) async {
    try {
      // Delete all messages in the chat room
      final messagesCollection = _chatRoomsCollection
          .doc(chatRoomId)
          .collection('messages');

      final messages = await messagesCollection.get();
      final batch = _firestore.batch();

      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Delete the chat room document
      await _chatRoomsCollection.doc(chatRoomId).delete();
    } catch (e) {
      debugPrint('Error deleting chat room: $e');
      throw Exception('Failed to delete chat room');
    }
  }
}
