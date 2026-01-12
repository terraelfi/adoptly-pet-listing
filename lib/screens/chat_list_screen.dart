import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/chat_room.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'main_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _timedOut = false;
  Timer? _timeoutTimer;
  StreamSubscription? _chatRoomsSubscription;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    // Set a timeout for 5 seconds
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _timedOut = true;
          _isLoading = false;
        });
      }
    });

    // If user is logged in, subscribe to chat rooms
    if (_authService.isLoggedIn) {
      _subscribeToChatRooms();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _subscribeToChatRooms() {
    final userId = _authService.currentUserId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Close any existing subscription
    _chatRoomsSubscription?.cancel();

    // Subscribe to chat rooms
    _chatRoomsSubscription = _chatService
        .getChatRoomsForUser(userId)
        .listen(
          (chatRooms) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _timedOut = false;
              });
              _timeoutTimer?.cancel();
            }
          },
          onError: (error) {
            debugPrint('Error in chat rooms stream: $error');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _chatRoomsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authService.isLoggedIn) {
      return const _NotLoggedInView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Conversations',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _timedOut = false;
              });
              _startLoading();
            },
            tooltip: 'Refresh chats',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _timedOut
              ? _buildTimeoutView()
              : StreamBuilder<List<ChatRoom>>(
                stream: _chatService.getChatRoomsForUser(
                  _authService.currentUserId!,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !_timedOut) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading conversations',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed:
                                () => setState(() {
                                  _isLoading = true;
                                  _timedOut = false;
                                  _startLoading();
                                }),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '😺 Here are your conversations. \nStart a chat with others by adopting a pet.',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          // Removed extra hint; unified message above
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Navigate to map tab
                              MainScreen.navigateToTab(
                                context,
                                0,
                              ); // 0 is the index for Map
                            },
                            icon: const Icon(Icons.pets),
                            label: const Text('Find Pets to Connect With'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final chatRooms = snapshot.data!;
                  return ListView.builder(
                    itemCount: chatRooms.length,
                    itemBuilder: (context, index) {
                      return _buildChatRoomItem(chatRooms[index], index);
                    },
                  );
                },
              ),
    );
  }

  Widget _buildTimeoutView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 60, color: Colors.orange[300]),
          const SizedBox(height: 16),
          Text(
            '😺 Here are your conversations. \nStart a chat with others by adopting a pet.',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Removed secondary hint; unified message shown above
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _timedOut = false;
                  });
                  _startLoading();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 199, 167, 255),
                ),
                child: const Text('Retry'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to map tab
                  MainScreen.navigateToTab(
                    context,
                    0,
                  ); // 0 is the index for Map
                },
                icon: const Icon(Icons.pets),
                label: const Text('Find Pets'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple[300],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatRoomItem(ChatRoom chatRoom, int index) {
    // Get the other participant's ID
    final currentUserId = _authService.currentUserId!;
    final otherUserId = chatRoom.participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) return const SizedBox.shrink();

    final otherUserName =
        chatRoom.participantNames[otherUserId] ?? 'Unknown User';
    final otherUserAvatar = chatRoom.participantAvatars?[otherUserId];
    
    // Determine background color based on index (alternating pattern)
    final backgroundColor = index % 2 == 0 
        ? Colors.white 
        : Colors.deepPurple.shade50;

    return FutureBuilder<String?>(
      future: _getOtherUserAvatar(otherUserId, chatRoom),
      builder: (context, ownerAvatarSnap) {
        final fetchedOtherAvatar = ownerAvatarSnap.data;
        return StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('chatRooms')
                  .doc(chatRoom.id)
                  .collection('messages')
                  .where('isRead', isEqualTo: false)
                  .where('senderId', isNotEqualTo: currentUserId)
                  .snapshots(),
          builder: (context, unreadSnap) {
            final int unreadCount =
                unreadSnap.hasData ? unreadSnap.data!.docs.length : 0;
            final String? avatarUrl =
                (otherUserAvatar != null && otherUserAvatar.isNotEmpty)
                    ? otherUserAvatar
                    : fetchedOtherAvatar;
            final bool hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
            final bool hasUnread = unreadCount > 0;
            final String subtitleText =
                hasUnread
                    ? '@$otherUserName messaged you'
                    : (chatRoom.lastMessageContent ?? 'No messages yet');
            final String displayLastMessage = (chatRoom.lastMessageContent ??
                    'No messages yet')
                .replaceFirst('[ADOPTION_REQUEST]', 'Adoption request:')
                .replaceFirst('[ADOPTION_ACCEPTED]', 'Adoption accepted:')
                .replaceFirst('[ADOPTION_DECLINED]', 'Adoption declined:')
                .replaceFirst('[PET_ADOPTED]', 'Pet adopted:');

            return Container(
              color: backgroundColor,
              child: ListTile(
                leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                child:
                    !hasAvatar
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
              ),
              title: Text(
                otherUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (chatRoom.petName != null)
                    Row(
                      children: [
                        if (chatRoom.petImageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              chatRoom.petImageUrl!,
                              width: 22,
                              height: 22,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stack) => const Icon(
                                    Icons.pets,
                                    size: 18,
                                    color: Colors.deepPurple,
                                  ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.pets,
                            size: 18,
                            color: Colors.deepPurple,
                          ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            chatRoom.petName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  Text(
                    hasUnread ? subtitleText : displayLastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          hasUnread ? FontWeight.w600 : FontWeight.normal,
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              isThreeLine: chatRoom.petName != null,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTimestamp(chatRoom.lastMessageTime),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  if (hasUnread)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              onTap:
                  () => _openChatScreen(
                    chatRoom.id,
                    otherUserId,
                    otherUserName,
                    chatRoom.petId,
                    chatRoom.petName,
                    chatRoom.petImageUrl,
                  ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _getOtherUserAvatar(
    String otherUserId,
    ChatRoom chatRoom,
  ) async {
    try {
      // Prefer avatar embedded in chatRoom, if present
      final embedded = chatRoom.participantAvatars?[otherUserId];
      if (embedded != null && embedded.isNotEmpty) return embedded;

      // Fallback: fetch from users collection
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(otherUserId)
              .get();
      if (!userDoc.exists) return null;
      final userData = userDoc.data() as Map<String, dynamic>;
      final avatar = userData['profileImageUrl'] as String?;
      return avatar;
    } catch (_) {
      return null;
    }
  }

  void _openChatScreen(
    String chatRoomId,
    String otherUserId,
    String otherUserName,
    String? petId,
    String? petName,
    String? petImageUrl,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChatScreen(
              chatRoomId: chatRoomId,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
              petId: petId,
              petName: petName,
              petImageUrl: petImageUrl,
            ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageDate = timestamp.toDate();
    final diff = now.difference(messageDate);

    if (diff.inDays > 7) {
      return '${messageDate.day}/${messageDate.month}/${messageDate.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _checkFirestoreChats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Not logged in')));
        return;
      }

      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('chatRooms')
              .where('participantIds', arrayContains: userId)
              .get();

      final int chatCount = querySnapshot.docs.length;

      if (chatCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found $chatCount chat rooms in Firestore')),
        );

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          debugPrint('Chat room ID: ${doc.id}');
          debugPrint('Participants: ${data['participantIds']}');
          debugPrint('Last message: ${data['lastMessageContent']}');
          debugPrint('Last message time: ${data['lastMessageTime']}');
          debugPrint('-------------------');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No chat rooms found in Firestore')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error checking chats: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class _NotLoggedInView extends StatelessWidget {
  const _NotLoggedInView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Please sign in to view your messages',
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/auth');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
