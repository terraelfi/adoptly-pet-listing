import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'main_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String otherUserId;
  final String otherUserName;
  final String? petId;
  final String? petName;
  final String? petImageUrl;

  const ChatScreen({
    Key? key,
    required this.chatRoomId,
    required this.otherUserId,
    required this.otherUserName,
    this.petId,
    this.petName,
    this.petImageUrl,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  bool _isAttaching = false;
  bool _isLoading = true;
  bool _timedOut = false;
  Timer? _timeoutTimer;
  StreamSubscription? _messagesSubscription;
  String? _petOwnerId;
  String? _adoptionStatus; // Available / Adopted / Pending
  String? _petType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Mark messages as read when entering the chat
    _markMessagesAsRead();
    // Set a timeout for loading
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _timedOut = true;
          _isLoading = false;
        });
      }
    });
    // Subscribe to messages
    _subscribeToMessages();
    _loadPetInfoIfAny();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Mark messages as read when app is resumed
      _markMessagesAsRead();
    }
  }

  void _subscribeToMessages() {
    _messagesSubscription = _chatService
        .getMessages(widget.chatRoomId)
        .listen(
          (messages) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _timedOut = false;
              });
              _timeoutTimer?.cancel();

              // Mark messages as read whenever new messages arrive
              _markMessagesAsRead();
            }
          },
          onError: (error) {
            debugPrint('Error in messages stream: $error');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
  }

  Future<void> _loadPetInfoIfAny() async {
    if (widget.petId == null) return;
    try {
      final petDoc =
          await FirebaseFirestore.instance
              .collection('pets')
              .doc(widget.petId)
              .get();
      if (!petDoc.exists) return;
      final data = petDoc.data() as Map<String, dynamic>;
      final dynamic rawType =
          data['type'] ?? data['species'] ?? data['category'];
      final String? petType = rawType is String ? rawType : null;
      if (mounted) {
        setState(() {
          _petOwnerId = data['userId'] as String?;
          _adoptionStatus = data['adoptionStatus'] as String?;
          _petType = petType;
        });
      }
    } catch (e) {
      debugPrint('Failed to load pet info: $e');
    }
  }

  void _markMessagesAsRead() async {
    try {
      if (_authService.currentUserId == null) {
        debugPrint('Cannot mark messages as read: User not logged in');
        return;
      }

      await _chatService.markMessagesAsRead(
        widget.chatRoomId,
        _authService.currentUserId!,
      );
    } catch (e) {
      // Just log the error, don't show to user
      debugPrint('Error in _markMessagesAsRead: $e');
      // The chat will still be usable even if marking messages fails
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageContent = _messageController.text.trim();
    _messageController.clear();

    final userData = await _authService.getUserData();
    final senderName = userData!['username'];
    final senderAvatar = userData['profileImageUrl'];

    final message = ChatMessage(
      id: '',
      chatRoomId: widget.chatRoomId,
      senderId: _authService.currentUserId!,
      senderName: senderName,
      senderAvatar: senderAvatar,
      content: messageContent,
      timestamp: Timestamp.now(),
      isRead: false,
    );

    try {
      await _chatService.sendMessage(message);
      _scrollToBottom();

      // If this was the first message, we need to refresh to show messages
      if (_timedOut) {
        setState(() {
          _isLoading = true;
          _timedOut = false;
        });
        _timeoutTimer?.cancel();
        _timeoutTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _timedOut = true;
              _isLoading = false;
            });
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  void _sendMedia(ImageSource source) async {
    setState(() {
      _isAttaching = false;
      _isLoading = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        final bytes = await imageFile.readAsBytes();
        final userData = await _authService.getUserData();

        await _chatService.sendMediaMessage(
          chatRoomId: widget.chatRoomId,
          senderId: _authService.currentUserId!,
          senderName: userData!['username'],
          senderAvatar: userData['profileImageUrl'],
          mediaType: 'image',
          mediaBytes: bytes,
          fileName: pickedFile.name,
        );

        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending image: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _timeoutTimer?.cancel();
    _messagesSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(color: Colors.white),
                ),
                if (widget.petName != null)
                  Text(
                    'About: ${widget.petName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // Chat header with pet info if available
          if (widget.petImageUrl != null && widget.petName != null)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.grey[100],
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.petImageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) =>
                              const Icon(Icons.pets, size: 50),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.petName!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text('Discussing this pet'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Adoption request banner for pet owner
          if (widget.petId != null &&
              _petOwnerId == _authService.currentUserId &&
              (_adoptionStatus == null ||
                  _adoptionStatus!.toLowerCase() != 'adopted'))
            StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessages(widget.chatRoomId),
              builder: (context, snapshot) {
                final hasRequest = (snapshot.data ?? []).any(
                  (m) =>
                      m.content.startsWith('[ADOPTION_REQUEST]') &&
                      m.senderId == widget.otherUserId,
                );
                if (!hasRequest) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  color: Colors.amber[50],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adopt this pet to ${widget.otherUserName}?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _handleAdoptionDecision(true),
                            icon: const Icon(Icons.check),
                            label: const Text('Yes, adopt to this user'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _handleAdoptionDecision(false),
                            icon: const Icon(Icons.close),
                            label: const Text('No'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

          // Messages
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _timedOut
                    ? _buildTimeoutView()
                    : StreamBuilder<List<ChatMessage>>(
                      stream: _chatService.getMessages(widget.chatRoomId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !_timedOut) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                                const Text(
                                  'Error loading messages',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isLoading = true;
                                      _timedOut = false;
                                    });
                                    _timeoutTimer?.cancel();
                                    _timeoutTimer = Timer(
                                      const Duration(seconds: 5),
                                      () {
                                        if (mounted) {
                                          setState(() {
                                            _timedOut = true;
                                            _isLoading = false;
                                          });
                                        }
                                      },
                                    );
                                    _subscribeToMessages();
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 70,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No messages yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start the conversation with ${widget.otherUserName}' +
                                        (widget.petName != null
                                            ? ' about ${widget.petName}!'
                                            : '!'),
                                    style: TextStyle(color: Colors.grey[600]),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSuggestedMessages(),
                                ],
                              ),
                            ),
                          );
                        }

                        final messages = snapshot.data!;

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.all(10),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMyMessage =
                                message.senderId == _authService.currentUserId;

                            return _buildMessageItem(message, isMyMessage);
                          },
                        );
                      },
                    ),
          ),

          // Media attachment indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),

          // Input area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed:
                      _isLoading
                          ? null
                          : () {
                            setState(() {
                              _isAttaching = !_isAttaching;
                            });
                          },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.deepPurple,
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),

          // Attachment options
          if (_isAttaching)
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentButton(
                    icon: Icons.photo_camera,
                    label: 'Camera',
                    onTap: () => _sendMedia(ImageSource.camera),
                  ),
                  _buildAttachmentButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => _sendMedia(ImageSource.gallery),
                  ),
                  _buildAttachmentButton(
                    icon: Icons.my_location,
                    label: 'Location',
                    onTap: _sendLocation,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleAdoptionDecision(bool accept) async {
    if (widget.petId == null) return;
    try {
      if (accept) {
        await FirebaseFirestore.instance
            .collection('pets')
            .doc(widget.petId)
            .set({
              'adoptionStatus': 'Adopted',
              'adoptedAt': FieldValue.serverTimestamp(),
              'adoptedByUserId': widget.otherUserId,
              'adoptedByUsername': widget.otherUserName,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        setState(() {
          _adoptionStatus = 'Adopted';
        });
        // Notify in chat
        final userData = await _authService.getUserData();
        await _chatService.sendMessage(
          ChatMessage(
            id: '',
            chatRoomId: widget.chatRoomId,
            senderId: _authService.currentUserId!,
            senderName: userData?['username'] ?? 'Owner',
            senderAvatar: userData?['profileImageUrl'],
            content:
                '[ADOPTION_ACCEPTED] 🎉 ${(userData?['username'] ?? 'Owner')} has accepted your adoption request! '
                '${(widget.petName != null && widget.petName!.isNotEmpty) ? widget.petName! : 'This pet'} is now yours.',
            timestamp: Timestamp.now(),
            isRead: false,
          ),
        );
        // Also notify all other interested users for this pet
        try {
          final roomsSnap =
              await FirebaseFirestore.instance
                  .collection('chatRooms')
                  .where('petId', isEqualTo: widget.petId)
                  .get();
          for (final doc in roomsSnap.docs) {
            if (doc.id == widget.chatRoomId) continue;
            final data = doc.data();
            final bool hasRequest = (data['hasAdoptionRequest'] == true);
            if (!hasRequest) continue;
            final String petNameForRoom =
                (data['petName'] is String &&
                        (data['petName'] as String).isNotEmpty)
                    ? data['petName'] as String
                    : (widget.petName ?? 'This pet');
            await _chatService.sendMessage(
              ChatMessage(
                id: '',
                chatRoomId: doc.id,
                senderId: _authService.currentUserId!,
                senderName: userData?['username'] ?? 'Owner',
                senderAvatar: userData?['profileImageUrl'],
                content:
                    '[PET_ADOPTED] 😢 $petNameForRoom has already been adopted by another user.',
                timestamp: Timestamp.now(),
                isRead: false,
              ),
            );
          }
        } catch (e) {
          debugPrint('Failed to notify other interested users: $e');
        }
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Marked as adopted')));
      } else {
        final userData = await _authService.getUserData();
        await _chatService.sendMessage(
          ChatMessage(
            id: '',
            chatRoomId: widget.chatRoomId,
            senderId: _authService.currentUserId!,
            senderName: userData?['username'] ?? 'Owner',
            senderAvatar: userData?['profileImageUrl'],
            content: '[ADOPTION_DECLINED] Adoption request declined',
            timestamp: Timestamp.now(),
            isRead: false,
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request declined')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Widget _buildTimeoutView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 60, color: Colors.orange[300]),
            const SizedBox(height: 16),
            Text(
              'Taking too long to load messages',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'This might be a new conversation with no messages yet',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
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
                    _timeoutTimer?.cancel();
                    _timeoutTimer = Timer(const Duration(seconds: 5), () {
                      if (mounted) {
                        setState(() {
                          _timedOut = true;
                          _isLoading = false;
                        });
                      }
                    });
                    _subscribeToMessages();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
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
            const SizedBox(height: 16),
            const Text(
              'Or start a new conversation below:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildSuggestedMessages(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message, bool isMyMessage) {
    final bool isSystemMessage =
        message.content.startsWith('[ADOPTION_REQUEST]') ||
        message.content.startsWith('[ADOPTION_ACCEPTED]') ||
        message.content.startsWith('[PET_ADOPTED]');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage:
                  message.senderAvatar != null &&
                          message.senderAvatar!.isNotEmpty
                      ? NetworkImage(message.senderAvatar!)
                      : null,
              child:
                  message.senderAvatar == null || message.senderAvatar!.isEmpty
                      ? const Icon(Icons.person, size: 20)
                      : null,
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isSystemMessage
                        ? Colors.deepPurple[50]
                        : (isMyMessage
                            ? Colors.deepPurple[100]
                            : Colors.grey[200]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment:
                    isMyMessage
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                children: [
                  if (!isMyMessage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  if (isSystemMessage)
                    _buildAdoptionSystemMessage(message)
                  else ...[
                    // Media message
                    if (message.mediaUrl != null &&
                        message.mediaUrl!.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          // Show full image
                          showDialog(
                            context: context,
                            builder:
                                (context) => Dialog(
                                  child: Image.network(message.mediaUrl!),
                                ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            message.mediaUrl!,
                            width: 200,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    const Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),

                    // Text message
                    if (message.mediaType == 'location' &&
                        message.locationLat != null &&
                        message.locationLng != null)
                      _buildLocationMessage(message)
                    else if (message.content.isNotEmpty &&
                        (message.mediaUrl == null ||
                            message.mediaType != 'image'))
                      Text(message.content),
                  ],

                  // Timestamp and read status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimestamp(message.timestamp),
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      if (isMyMessage) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color:
                              message.isRead ? Colors.blue : Colors.grey[600],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMyMessage) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAdoptionSystemMessage(ChatMessage message) {
    final bool isRequest = message.content.startsWith('[ADOPTION_REQUEST]');
    final bool isAccepted = message.content.startsWith('[ADOPTION_ACCEPTED]');
    final bool isAdoptedNotice = message.content.startsWith('[PET_ADOPTED]');

    final String title =
        isRequest
            ? '🐾💌 Adoption Request'
            : isAccepted
            ? '🎉🐶🐱 Adoption Accepted'
            : '😿 Pet Adopted';

    final String? petName = widget.petName;
    final String? petType = _petType;
    final String? imageUrl = widget.petImageUrl;

    final List<Widget> children = [];

    children.add(
      Text(
        petName != null && (isRequest || isAccepted)
            ? '$title for $petName'
            : title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple[900],
        ),
      ),
    );

    if ((isAccepted || isAdoptedNotice) &&
        (petName != null || petType != null || imageUrl != null)) {
      children.add(const SizedBox(height: 8));
      children.add(
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple.shade100),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stack) => const Icon(
                          Icons.pets,
                          size: 40,
                          color: Colors.deepPurple,
                        ),
                  ),
                )
              else
                const Icon(Icons.pets, size: 40, color: Colors.deepPurple),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (petName != null)
                      Text(
                        petName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (petType != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          petType,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    if (isAdoptedNotice)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'This pet has been adopted.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isRequest && imageUrl != null && imageUrl.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            imageUrl,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stack) =>
                    const Icon(Icons.pets, size: 48, color: Colors.deepPurple),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildLocationMessage(ChatMessage message) {
    final lat = message.locationLat!;
    final lng = message.locationLng!;
    final label = message.locationLabel ?? 'Shared location';
    return InkWell(
      onTap: () => _openInMaps(lat: lat, lng: lng, label: label),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, color: Colors.redAccent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label — Tap to open in Maps',
              style: const TextStyle(decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendLocation() async {
    try {
      setState(() {
        _isAttaching = false;
        _isLoading = true;
      });

      final userData = await _authService.getUserData();
      final loc = await LocationService.getCurrentLocation();
      final lat = loc['latitude']!;
      final lng = loc['longitude']!;

      await _chatService.sendLocationMessage(
        chatRoomId: widget.chatRoomId,
        senderId: _authService.currentUserId!,
        senderName: userData?['username'] ?? 'User',
        senderAvatar: userData?['profileImageUrl'],
        latitude: lat,
        longitude: lng,
        label: 'My location',
      );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending location: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openInMaps({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final encodedLabel = Uri.encodeComponent(label ?? 'Location');
    final Uri mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng($encodedLabel)',
    );
    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
      return;
    }
    final Uri fallback = Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedLabel)');
    await launchUrl(fallback, mode: LaunchMode.externalApplication);
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.deepPurple),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageDate = timestamp.toDate();
    final diff = now.difference(messageDate);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildSuggestedMessages() {
    List<String> suggestions = [
      'Hi, is this pet still available?',
      'I\'m interested in learning more about this pet',
      'What\'s the pet\'s temperament like?',
    ];

    if (widget.petName != null) {
      suggestions = [
        'Hi, is ${widget.petName} still available?',
        'I\'m interested in learning more about ${widget.petName}',
        'What\'s ${widget.petName}\'s temperament like?',
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Suggested messages:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        ...suggestions
            .map(
              (suggestion) => Card(
                color: Colors.deepPurple[50],
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    _messageController.text = suggestion;
                    // Focus the text field
                    FocusScope.of(context).requestFocus(FocusNode());
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      suggestion,
                      style: const TextStyle(color: Colors.deepPurple),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  // Static method to navigate to this screen from a notification
  static void openFromNotification(
    BuildContext context,
    String chatRoomId,
  ) async {
    try {
      // Fetch chat room details
      final chatRoomDoc =
          await FirebaseFirestore.instance
              .collection('chatRooms')
              .doc(chatRoomId)
              .get();

      if (!chatRoomDoc.exists) {
        debugPrint('Chat room does not exist: $chatRoomId');
        return;
      }

      final chatRoom = ChatRoom.fromFirestore(chatRoomDoc);
      final authService = AuthService();

      // Get the other user's ID
      final currentUserId = authService.currentUserId;
      if (currentUserId == null) {
        debugPrint('User not logged in');
        return;
      }

      final otherUserId = chatRoom.participantIds.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );

      if (otherUserId.isEmpty) {
        debugPrint('Could not find other user');
        return;
      }

      final otherUserName = chatRoom.participantNames[otherUserId] ?? 'User';

      // Navigate to chat screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => ChatScreen(
                chatRoomId: chatRoomId,
                otherUserId: otherUserId,
                otherUserName: otherUserName,
                petId: chatRoom.petId,
                petName: chatRoom.petName,
                petImageUrl: chatRoom.petImageUrl,
              ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening chat from notification: $e');
    }
  }
}
