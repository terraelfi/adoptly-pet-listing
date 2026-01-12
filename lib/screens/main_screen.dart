import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'saved_pets_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';
import 'admin_screen.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final String? initialPetId;

  const MainScreen({super.key, this.initialIndex = 0, this.initialPetId});

  // Static method to navigate to a specific tab
  static void navigateToTab(BuildContext context, int tabIndex) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => MainScreen(initialIndex: tabIndex),
      ),
      (route) => false,
    );
  }

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  late List<Widget> _screens;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  bool _isAdmin = false;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _isAdmin = _authService.isAdmin;

    _rebuildScreens();

    WidgetsBinding.instance.addObserver(this);
    _checkAndStartNotifications();

    // Listen for auth changes to update admin tab visibility dynamically
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      final bool adminNow = user?.uid == AuthService.adminUid;
      if (adminNow != _isAdmin) {
        setState(() {
          _isAdmin = adminNow;
          _rebuildScreens();
        });
      }
      // Stop/start notifications based on auth state
      _checkAndStartNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _checkAndStartNotifications();
    } else if (state == AppLifecycleState.paused) {
      // App went to background
      _notificationService.stopListeningForMessages();
    }
  }

  void _checkAndStartNotifications() {
    if (_authService.isLoggedIn) {
      _notificationService.startListeningForMessages();
    } else {
      _notificationService.stopListeningForMessages();
    }
  }

  void _rebuildScreens() {
    _screens = [
      const HomeScreen(),
      MapScreen(initialPetId: widget.initialPetId),
      const SavedPetsScreen(),
      const ChatListScreen(),
      const ProfileScreen(),
      if (_isAdmin) const AdminScreen(),
    ];
    if (_currentIndex >= _screens.length) {
      _currentIndex = _screens.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            label: 'Saved',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
          if (_isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings),
              label: 'Admin',
            ),
        ],
      ),
    );
  }
}
