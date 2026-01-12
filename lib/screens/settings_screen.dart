import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  double _notificationRadius = 10.0; // Default notification radius
  bool _notificationsEnabled = true;
  bool _chatNotificationsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load notification radius
      final radius = prefs.getDouble('notification_radius') ?? 10.0;

      // Load notification toggle state
      final notificationsEnabled =
          prefs.getBool('notifications_enabled') ?? true;

      // Load chat notification toggle state
      final chatNotificationsEnabled =
          prefs.getBool('chat_notifications_enabled') ?? true;

      if (mounted) {
        setState(() {
          _notificationRadius = radius;
          _notificationsEnabled = notificationsEnabled;
          _chatNotificationsEnabled = chatNotificationsEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load settings')),
        );
      }
    }
  }

  Future<void> _saveNotificationRadius(double radius) async {
    try {
      await _notificationService.saveNotificationRadius(radius);
      if (mounted) {
        setState(() {
          _notificationRadius = radius;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification radius updated'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error saving notification radius: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings')),
        );
      }
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // If enabling notifications on Android, ensure permissions are granted
      if (enabled && Platform.isAndroid) {
        // Request permission through the notification service
        // This will only actually request on Android 13+
        final granted = await _requestNotificationPermission();

        // If permission was denied, don't enable notifications
        if (granted == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission denied by system'),
              duration: Duration(seconds: 3),
            ),
          );

          // Update toggle state but don't enable notifications
          setState(() {
            _notificationsEnabled = false;
          });

          // Save the disabled state
          await prefs.setBool('notifications_enabled', false);
          return;
        }
      }

      // Save user preference
      await prefs.setBool('notifications_enabled', enabled);

      // Start or stop notification service based on preference
      if (enabled) {
        _notificationService.startListeningForMessages();
      } else {
        _notificationService.stopListeningForMessages();
      }

      if (mounted) {
        setState(() {
          _notificationsEnabled = enabled;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled ? 'Notifications enabled' : 'Notifications disabled',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error toggling notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update notification settings'),
          ),
        );
      }
    }
  }

  // Helper method to request notification permission
  Future<bool?> _requestNotificationPermission() async {
    try {
      final androidImplementation =
          _notificationService.flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      return await androidImplementation?.requestNotificationsPermission();
    } catch (e) {
      print('Error requesting notification permission: $e');
      return null;
    }
  }

  Future<void> _toggleChatNotifications(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save user preference
      await prefs.setBool('chat_notifications_enabled', enabled);

      if (mounted) {
        setState(() {
          _chatNotificationsEnabled = enabled;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Chat notifications enabled'
                  : 'Chat notifications disabled',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error toggling chat notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update chat notification settings'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        elevation: 1,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                children: [
                  // Notifications Section
                  _buildSectionHeader('Notifications'),

                  // Toggle for enabling/disabling notifications
                  SwitchListTile(
                    title: const Text('Enable Notifications'),
                    subtitle: const Text(
                      'Get alerts about new pet listings nearby',
                    ),
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    secondary: const Icon(
                      Icons.notifications,
                      color: Colors.deepPurple,
                    ),
                  ),

                  // Only show radius setting if notifications are enabled
                  if (_notificationsEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Notification Radius',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${_notificationRadius.round()} km',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: _notificationRadius,
                            min: 1.0,
                            max: 50.0,
                            divisions: 49,
                            label: '${_notificationRadius.round()} km',
                            activeColor: Colors.deepPurple,
                            onChanged: (value) {
                              setState(() {
                                _notificationRadius = value;
                              });
                            },
                            onChangeEnd: (value) {
                              _saveNotificationRadius(value);
                            },
                          ),
                          const Text(
                            'You will be notified about new pets within this distance from your location.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(),

                  // Chat Notifications Section
                  _buildSectionHeader('Chat'),

                  // Toggle for enabling/disabling chat notifications
                  SwitchListTile(
                    title: const Text('Chat Message Notifications'),
                    subtitle: const Text(
                      'Get notified when you receive new chat messages',
                    ),
                    value: _chatNotificationsEnabled,
                    onChanged: _toggleChatNotifications,
                    secondary: const Icon(
                      Icons.chat_bubble,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }
}
