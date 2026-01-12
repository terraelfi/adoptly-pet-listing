import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'location_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:math' as math;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

  // Store the navigation callback that will be used when a notification is tapped
  Function(String)? _onNotificationTap;

  // Streaming subscription for pet listings
  StreamSubscription<QuerySnapshot>? _petListingsSubscription;
  // Streaming subscription for chat rooms
  StreamSubscription<QuerySnapshot>? _chatRoomsSubscription;
  // Streaming subscriptions for messages per chat room
  final Map<String, StreamSubscription<QuerySnapshot>>
  _chatMessageSubscriptions = {};

  // Last timestamp we checked for new pets
  DateTime? _lastCheckTimestamp;
  // Last timestamp we checked for new chat messages
  DateTime? _lastChatCheckTimestamp;

  // User's location
  LatLng? _userLocation;

  // User's preferred notification radius (in km)
  double _notificationRadius = 10.0; // Default 10km

  // Set of already processed listing IDs to avoid duplicate notifications
  final Set<String> _processedListingIds = {};
  // Set of already processed message IDs to avoid duplicate notifications
  final Set<String> _processedMessageIds = {};
  // Track unread counts and recent notification times per chat for grouping
  final Map<String, int> _chatUnreadCount = {};
  final Map<String, DateTime> _chatLastNotifAt = {};

  // Register a function to handle notification taps
  void setNotificationTapHandler(Function(String) onNotificationTap) {
    _onNotificationTap = onNotificationTap;
  }

  // Initialize notification services
  Future<void> initialize() async {
    try {
      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestSoundPermission: true,
            requestBadgePermission: true,
            requestAlertPermission: true,
          );
      final InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && _onNotificationTap != null) {
            _onNotificationTap!(payload);
          }
        },
      );

      // Request notification permissions for Android 13+ (API level 33+)
      if (Platform.isAndroid) {
        try {
          // Get Android SDK version
          final androidInfo = await deviceInfoPlugin.androidInfo;
          final sdkInt = androidInfo.version.sdkInt;

          // Android 13 is API level 33
          if (sdkInt >= 33) {
            debugPrint('Requesting notification permission for Android 13+');
            final androidImplementation =
                flutterLocalNotificationsPlugin
                    .resolvePlatformSpecificImplementation<
                      AndroidFlutterLocalNotificationsPlugin
                    >();

            final bool? granted =
                await androidImplementation?.requestNotificationsPermission();
            debugPrint('Notification permission granted: $granted');
          }
        } catch (e) {
          debugPrint('Error requesting notification permission: $e');
        }
      }

      // Load saved notification radius if available
      await _loadNotificationSettings();

      // Get user location
      await _updateUserLocation();

      // Set initial timestamp
      _lastCheckTimestamp = DateTime.now();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
      // Continue even if there's an error
    }
  }

  // Load user notification settings from SharedPreferences
  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationRadius = prefs.getDouble('notification_radius') ?? 10.0;
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
  }

  // Save user notification settings to SharedPreferences
  Future<void> saveNotificationRadius(double radius) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('notification_radius', radius);
      _notificationRadius = radius;
    } catch (e) {
      debugPrint('Error saving notification radius: $e');
    }
  }

  // Update user's current location
  Future<void> _updateUserLocation() async {
    try {
      final locationMap = await LocationService.getCurrentLocation();
      _userLocation = LatLng(
        locationMap['latitude']!,
        locationMap['longitude']!,
      );
      debugPrint('Updated user location for notifications');
    } catch (e) {
      debugPrint('Error updating user location: $e');
    }
  }

  // Start listening for new pet listings
  void startListeningForMessages() {
    // Close any existing subscription
    stopListeningForMessages();

    // Check if notifications are enabled
    _checkNotificationsEnabled().then((enabled) {
      if (!enabled) {
        debugPrint('Notifications are disabled in settings');
        return;
      }

      // Update location immediately
      _updateUserLocation().then((_) {
        // Start listening for new pet listings
        _startListeningForPetListings();
        // Start listening for chat messages
        _startListeningForChatMessages();

        // Set up periodic location updates (every 15 minutes)
        Timer.periodic(const Duration(minutes: 15), (_) {
          _updateUserLocation();
          debugPrint('Updated user location for notification service');
        });
      });

      debugPrint('Notification listening started for nearby pet listings');
    });
  }

  // Check if notifications are enabled in settings
  Future<bool> _checkNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notifications_enabled') ?? true;
    } catch (e) {
      debugPrint('Error checking notification settings: $e');
      return true; // Default to enabled if there's an error
    }
  }

  void stopListeningForMessages() {
    _petListingsSubscription?.cancel();
    _petListingsSubscription = null;
    _chatRoomsSubscription?.cancel();
    _chatRoomsSubscription = null;
    // Cancel all per-room message subscriptions
    for (final sub in _chatMessageSubscriptions.values) {
      sub.cancel();
    }
    _chatMessageSubscriptions.clear();
    debugPrint('Notification listening stopped');
  }

  // Listen for new pet listings in Firestore
  void _startListeningForPetListings() {
    // Save the current timestamp to filter only newer listings
    _lastCheckTimestamp = DateTime.now();

    // Listen for updates to the pets collection
    _petListingsSubscription = FirebaseFirestore.instance
        .collection('pets')
        .orderBy(
          'createdAt',
          descending: true,
        ) // Sort by creation time to get newest first
        .limit(50) // Limit to the 50 most recent to optimize performance
        .snapshots()
        .listen((snapshot) {
          _processNewPetListings(snapshot);
        });

    debugPrint('Started listening for new pet listings (with optimizations)');
  }

  // Listen for new chat messages for the current user
  void _startListeningForChatMessages() {
    _lastChatCheckTimestamp = DateTime.now();
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint('Cannot start chat notifications, user not logged in');
      return;
    }

    _chatRoomsSubscription = FirebaseFirestore.instance
        .collection('chatRooms')
        .where('participantIds', arrayContains: currentUserId)
        .snapshots()
        .listen(
          (roomsSnapshot) {
            final currentRoomIds =
                roomsSnapshot.docs.map((doc) => doc.id).toSet();

            // Cancel subscriptions for rooms that no longer exist
            final toRemove =
                _chatMessageSubscriptions.keys
                    .where((id) => !currentRoomIds.contains(id))
                    .toList();
            for (final roomId in toRemove) {
              _chatMessageSubscriptions.remove(roomId)?.cancel();
            }

            // Ensure a message listener per room
            for (final roomDoc in roomsSnapshot.docs) {
            final roomId = roomDoc.id;
            if (_chatMessageSubscriptions.containsKey(roomId)) continue;

            final sub = roomDoc.reference
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(10)
                .snapshots()
                .listen((messagesSnapshot) async {
                  for (final change in messagesSnapshot.docChanges) {
                    if (change.type != DocumentChangeType.added) continue;
                    final doc = change.doc;
                    if (_processedMessageIds.contains(doc.id)) continue;

                    final dataRaw = doc.data();
                    if (dataRaw == null) continue;
                    final Map<String, dynamic> data = Map<String, dynamic>.from(
                      dataRaw as Map,
                    );

                    final String senderId = data['senderId'] ?? '';
                    if (senderId.isEmpty || senderId == currentUserId) {
                      // Don't notify for own messages
                      continue;
                    }

                    // Ensure we only notify for genuinely new messages
                    final Timestamp ts = data['timestamp'] ?? Timestamp.now();
                    final DateTime sentAt = ts.toDate();
                    if (_lastChatCheckTimestamp != null &&
                        sentAt.isBefore(_lastChatCheckTimestamp!)) {
                      continue;
                    }

                    _processedMessageIds.add(doc.id);

                    final String senderName = data['senderName'] ?? 'User';
                    final String? senderAvatarUrl = data['senderAvatar'];
                    final String content = data['content'] ?? '';
                    final String? petName =
                        (roomDoc.data() as Map<String, dynamic>?)?['petName']
                            as String?;

                    // Update per-chat unread count within a short window
                    final DateTime now = DateTime.now();
                    final lastAt = _chatLastNotifAt[roomId];
                    if (lastAt != null &&
                        now.difference(lastAt) <= const Duration(seconds: 10)) {
                      _chatUnreadCount[roomId] =
                          (_chatUnreadCount[roomId] ?? 1) + 1;
                    } else {
                      _chatUnreadCount[roomId] = 1;
                    }
                    _chatLastNotifAt[roomId] = now;
                    final int unreadCount = _chatUnreadCount[roomId] ?? 1;

                    // Determine the other user id (sender)
                    final String otherUserId = senderId;

                    // Show chat notification
                    await showChatMessageNotification(
                      chatRoomId: roomId,
                      senderId: senderId,
                      senderName: senderName,
                      senderAvatarUrl: senderAvatarUrl,
                      messageContent: content,
                      otherUserId: otherUserId,
                      petName: petName,
                      unreadCount: unreadCount,
                    );
                  }
                });

            _chatMessageSubscriptions[roomId] = sub;
          }
        },
        onError: (error) {
          debugPrint('Error listening to chat rooms: $error');
          // If we get a permission error, it likely means the user logged out
          // Stop listening to prevent further errors
          if (error.toString().contains('PERMISSION_DENIED')) {
            debugPrint('Permission denied - stopping chat notifications');
            stopListeningForMessages();
          }
        },
        cancelOnError: false,
      );

    debugPrint('Started listening for chat messages for user: $currentUserId');
  }

  // Download image bytes for large icon (Android)
  Future<AndroidBitmap<Object>?> _largeIconFromUrl(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        // Decode and fix orientation, crop to square, and resize for better appearance
        final bytes = response.bodyBytes;
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          return ByteArrayAndroidBitmap(bytes);
        }

        // Bake EXIF orientation if present
        final oriented = img.bakeOrientation(decoded);

        // Center-crop to square
        final int size = math.min(oriented.width, oriented.height);
        final int cropX = (oriented.width - size) ~/ 2;
        final int cropY = (oriented.height - size) ~/ 2;
        final img.Image square = img.copyCrop(
          oriented,
          x: cropX,
          y: cropY,
          width: size,
          height: size,
        );

        // Resize to reasonable notification icon size
        final img.Image resized = img.copyResize(
          square,
          width: 128,
          height: 128,
          interpolation: img.Interpolation.average,
        );

        final processedBytes = img.encodePng(resized);
        return ByteArrayAndroidBitmap(processedBytes);
      }
    } catch (e) {
      debugPrint('Failed to download large icon: $e');
    }
    return null;
  }

  // Show chat message style notification with grouping and sender image
  Future<void> showChatMessageNotification({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    String? senderAvatarUrl,
    required String messageContent,
    required String otherUserId, // the user to open chat with
    String? petName,
    int unreadCount = 1,
  }) async {
    try {
      bool enabled = await _checkNotificationsEnabled();
      if (!enabled) {
        debugPrint('Chat notification suppressed: notifications are disabled');
        return;
      }

      final groupKey = 'chat_$chatRoomId';
      final androidLargeIcon = await _largeIconFromUrl(senderAvatarUrl);

      // Android: Messaging style with large icon
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'chat_channel',
            'Chat Messages',
            channelDescription: 'Notifications for chat messages',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            groupKey: groupKey,
            largeIcon: androidLargeIcon,
            category: AndroidNotificationCategory.message,
            onlyAlertOnce: true,
            subText:
                petName != null && petName.isNotEmpty ? 'About $petName' : null,
            ticker: 'New message from $senderName',
            styleInformation: MessagingStyleInformation(
              Person(name: senderName, key: senderId),
              conversationTitle: senderName,
              groupConversation: false,
              messages: [
                Message(
                  messageContent,
                  DateTime.now(),
                  Person(name: senderName, key: senderId),
                ),
              ],
            ),
          );

      // iOS: threadIdentifier to group by conversation
      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: groupKey,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Build payload as JSON string so we can deep-link to the exact chat
      final payload = jsonEncode({
        'type': 'chat',
        'chatRoomId': chatRoomId,
        'otherUserId': otherUserId,
        'otherUserName': senderName,
        'petName': petName,
        'otherUserAvatarUrl': senderAvatarUrl,
      });

      // Use a stable ID per conversation for replacement/stacking behavior
      final int notificationId = chatRoomId.hashCode;

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        senderName,
        unreadCount > 1 ? '$unreadCount new messages' : messageContent,
        platformDetails,
        payload: payload,
      );

      // Android group summary (optional): show a summary when multiple messages arrive
      if (unreadCount > 1) {
        final AndroidNotificationDetails summaryAndroidDetails =
            AndroidNotificationDetails(
              'chat_channel',
              'Chat Messages',
              channelDescription: 'Notifications for chat messages',
              styleInformation: const InboxStyleInformation([]),
              groupKey: groupKey,
              setAsGroupSummary: true,
              category: AndroidNotificationCategory.message,
              onlyAlertOnce: true,
            );
        final NotificationDetails summaryPlatformDetails = NotificationDetails(
          android: summaryAndroidDetails,
          iOS: iosDetails,
        );
        await flutterLocalNotificationsPlugin.show(
          notificationId + 1,
          senderName,
          '$unreadCount new messages from $senderName',
          summaryPlatformDetails,
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('Error showing chat notification: $e');
    }
  }

  // Process pet listings and notify if there are new ones nearby
  Future<void> _processNewPetListings(QuerySnapshot snapshot) async {
    if (_userLocation == null) {
      await _updateUserLocation();
      if (_userLocation == null) return; // Still null, can't proceed
    }

    // Get current time to update the timestamp after processing
    final now = DateTime.now();

    // Find pet listings that were added after our last check (and are Available)
    final newPetListings =
        snapshot.docChanges
            .where((change) {
              // Only process new documents
              if (change.type != DocumentChangeType.added) return false;

              final data = change.doc.data() as Map<String, dynamic>;

              // Skip if we've already processed this listing
              if (_processedListingIds.contains(change.doc.id)) return false;

              // Skip if no timestamp
              if (data['createdAt'] == null) return false;
              
              // Skip pets that are pending review (not yet approved by admin)
              final adoptionStatus = data['adoptionStatus'] as String?;
              if (adoptionStatus == 'Pending Review') return false;

              // Check if it's a recent listing
              final createdAt = data['createdAt'].toDate();
              return createdAt.isAfter(_lastCheckTimestamp!);
            })
            .map((change) => change.doc)
            .toList();
    
    // Also check for pets that were just approved (modified from Pending Review to Available)
    final approvedPetListings =
        snapshot.docChanges
            .where((change) {
              // Only process modified documents
              if (change.type != DocumentChangeType.modified) return false;

              final data = change.doc.data() as Map<String, dynamic>;
              
              // Check if this pet was just approved (status is now Available)
              final adoptionStatus = data['adoptionStatus'] as String?;
              if (adoptionStatus != 'Available') return false;
              
              // Check if it has an approvedAt timestamp (set by admin when approving)
              final approvedAt = data['approvedAt'];
              if (approvedAt == null) return false;
              
              // Skip if we've already notified for this approval
              final approvalKey = '${change.doc.id}_approved';
              if (_processedListingIds.contains(approvalKey)) return false;
              
              // Check if approved recently (within last 2 minutes)
              final approvedTime = (approvedAt as Timestamp).toDate();
              final timeSinceApproval = now.difference(approvedTime);
              return timeSinceApproval.inMinutes < 2;
            })
            .map((change) => change.doc)
            .toList();

    // Combine both lists
    final allPetsToNotify = [...newPetListings, ...approvedPetListings];

    if (allPetsToNotify.isEmpty) return;

    debugPrint('Found ${newPetListings.length} new pet listings, ${approvedPetListings.length} newly approved');

    // Check each listing to see if it's within the notification radius
    for (final doc in allPetsToNotify) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Mark as processed (use different key for approved pets)
      final isApproved = approvedPetListings.contains(doc);
      final processKey = isApproved ? '${doc.id}_approved' : doc.id;
      _processedListingIds.add(processKey);

      final location = data['location'];

      if (location == null) continue;

      // Create LatLng object for the pet's location
      LatLng petLocation = LatLng(location['latitude'], location['longitude']);

      // Calculate distance from user
      final distance = LocationService.calculateDistance(
        _userLocation!.latitude,
        _userLocation!.longitude,
        petLocation.latitude,
        petLocation.longitude,
      );

      // If within notification radius, send a notification
      if (distance <= _notificationRadius) {
        final petName = data['name'] ?? 'A pet';
        final petType = data['breed'] ?? 'pet';

        // Create and send the notification
        final title = 'New Pet Nearby! 🐾';
        final String proximity =
            distance <= 7.0 ? 'very close to you' : 'nearby';
        final body =
            '$petName, a $petType, was just listed $proximity (${distance.toStringAsFixed(1)}km away)';

        await showSimpleNotification(
          title,
          body,
          payload: doc.id, // Use the pet listing ID as the payload
        );

        debugPrint(
          'Sent notification for nearby pet: $petName ($distance km away)${isApproved ? ' (newly approved)' : ''}',
        );
      }
    }

    // Limit the size of processed IDs to prevent memory issues
    if (_processedListingIds.length > 500) {
      // Keep only the most recent 300 entries
      final recentIds = _processedListingIds.toList().sublist(
        _processedListingIds.length - 300,
      );
      _processedListingIds.clear();
      _processedListingIds.addAll(recentIds);
    }

    // Update the timestamp for the next check
    _lastCheckTimestamp = now;
  }

  // Show a local notification
  Future<void> showSimpleNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    try {
      // First check if notifications are enabled
      bool enabled = await _checkNotificationsEnabled();
      if (!enabled) {
        debugPrint('Notification suppressed: notifications are disabled');
        return;
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'basic_channel',
            'Basic Notifications',
            channelDescription: 'Basic notifications channel',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }
}
