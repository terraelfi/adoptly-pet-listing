import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloudinary_flutter/cloudinary_context.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'services/cloudinary_service.dart';
import 'services/notification_service.dart';
import 'services/env_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/chat_screen.dart';
import 'dart:convert';

// Global navigation key for handling notifications when app is in background
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler for Firebase Cloud Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Need to ensure Firebase is initialized
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Handling a background message: ${message.messageId}");
  } catch (e) {
    print("Error handling background message: $e");
  }
}

void main() async {
  // This ensures Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration
  try {
    await EnvConfig.initialize();
    print('Environment configuration loaded');
  } catch (e) {
    print('Warning: Could not load .env file: $e');
    // Continue even if .env fails to load
  }

  // Initialize Firebase before anything else
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
    // Continue even if Firebase fails to initialize
  }

  // Run app immediately
  runApp(const PetListingApp());

  // Initialize other services in the background after app is running
  _initializeServices();
}

Future<void> _initializeServices() async {
  try {
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize Cloudinary with more detailed logging
    print('Initializing Cloudinary...');
    try {
      CloudinaryContext.cloudinary = Cloudinary.fromCloudName(
        cloudName: EnvConfig.cloudinaryCloudName,
      );
      print('Cloudinary context initialized');

      // Check if Cloudinary configuration is valid
      print('Verifying Cloudinary configuration...');
      bool isCloudinaryConfigValid = await CloudinaryService.isConfigValid();
      print('Cloudinary configuration is valid: $isCloudinaryConfigValid');

      if (!isCloudinaryConfigValid) {
        print(
          'WARNING: Cloudinary configuration verification failed. Image uploads may not work properly.',
        );

        // Validate both upload presets specifically
        print('Attempting to validate Cloudinary upload presets...');
        final presetResults = await CloudinaryService.validateUploadPresets();
        print('Cloudinary validation results: $presetResults');

        if (!presetResults['cloudName']!) {
          print(
            'Cloud name is invalid. Please check your Cloudinary configuration.',
          );
        }

        if (!presetResults['petUploadPreset']!) {
          print(
            'Pet upload preset (zmzzt6zj) is invalid. Please check your Cloudinary configuration.',
          );
        }

        if (!presetResults['userProfileUploadPreset']!) {
          print(
            'User profile upload preset (nmorlr7k) is invalid. Please check your Cloudinary configuration.',
          );
        }
      }
    } catch (cloudinaryError) {
      print('Error initializing Cloudinary: $cloudinaryError');
      // Continue with app even if Cloudinary fails to initialize
    }

    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Set the notification tap handler
    notificationService.setNotificationTapHandler((payload) {
      // Navigate to the appropriate screen when a notification is tapped
      if (navigatorKey.currentState != null && payload.isNotEmpty) {
        try {
          // Handle cases where payload may be double-encoded or wrapped in quotes
          String raw = payload;
          if (raw.startsWith('"') && raw.endsWith('"')) {
            raw = raw.substring(1, raw.length - 1).replaceAll(r'\"', '"');
          }
          dynamic parsed = jsonDecode(raw);
          if (parsed is String) {
            parsed = jsonDecode(parsed);
          }
          if (parsed is Map<String, dynamic> && parsed['type'] == 'chat') {
            final String chatRoomId = parsed['chatRoomId'] ?? '';
            final String otherUserId = parsed['otherUserId'] ?? '';
            final String otherUserName = parsed['otherUserName'] ?? 'User';
            Navigator.push(
              navigatorKey.currentState!.context,
              MaterialPageRoute(
                builder:
                    (context) => ChatScreen(
                      chatRoomId: chatRoomId,
                      otherUserId: otherUserId,
                      otherUserName: otherUserName,
                      petId: null,
                      petName: null,
                      petImageUrl: null,
                    ),
              ),
            );
            return;
          }
        } catch (_) {
          // Not JSON; fall through to legacy handlers
        }

        // Legacy behavior
        if (payload.startsWith('chat_')) {
          Navigator.push(
            navigatorKey.currentState!.context,
            MaterialPageRoute(
              builder: (context) => MainScreen(initialIndex: 3),
            ),
          );
          return;
        }

        // Assume pet ID and navigate to map with highlighted pet
        Navigator.push(
          navigatorKey.currentState!.context,
          MaterialPageRoute(
            builder:
                (context) => MainScreen(initialIndex: 1, initialPetId: payload),
          ),
        );
      }
    });

    // Start listening for notifications
    notificationService.startListeningForMessages();
  } catch (e) {
    print('Error during initialization: $e');
    // Continue with app regardless of initialization errors
  }
}

class PetListingApp extends StatelessWidget {
  const PetListingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Set the navigator key for global navigation
      title: 'Pet Listings Near You',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainScreen(),
    );
  }
}
