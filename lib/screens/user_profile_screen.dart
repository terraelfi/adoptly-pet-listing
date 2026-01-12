import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/pet_listing.dart';
import '../models/chat_room.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import 'map/pet_details_sheet.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String username;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  List<PetListing> _userPets = [];
  List<PetListing> _adoptedPets = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load user data
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();

      if (userDoc.exists) {
        _userData = userDoc.data();
      }

      // Load user's pets
      await _loadUserPets();

      // Load adopted pets
      await _loadAdoptedPets();
    } catch (e) {
      print('Error loading user profile: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserPets() async {
    try {
      final userPetsSnapshot =
          await FirebaseFirestore.instance
              .collection('pets')
              .where('userId', isEqualTo: widget.userId)
              .get();

      final pets = <PetListing>[];
      for (final doc in userPetsSnapshot.docs) {
        final data = doc.data();

        // Skip pets that are pending review (not yet approved by admin)
        // These should not be visible to other users
        final adoptionStatus = data['adoptionStatus'] as String?;
        if (adoptionStatus == 'Pending Review') continue;

        pets.add(
          PetListing(
            id: doc.id,
            name: data['name'] ?? 'Unknown',
            type: data['petType'] ?? 'Unknown',
            username: widget.username,
            imageUrl: data['imageUrl'] ?? '',
            location:
                data['location'] != null
                    ? LatLng(
                      data['location']['latitude'] ?? 0.0,
                      data['location']['longitude'] ?? 0.0,
                    )
                    : LatLng(0.0, 0.0),
            userId: widget.userId,
            address: data['address'] ?? '',
            description: data['description'] as String?,
            adoptionStatus: adoptionStatus,
            adoptedAt:
                data['adoptedAt'] is Timestamp
                    ? (data['adoptedAt'] as Timestamp).toDate()
                    : null,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _userPets = pets;
        });
      }
    } catch (e) {
      print('Error loading user pets: $e');
    }
  }

  Future<void> _loadAdoptedPets() async {
    try {
      final adoptedSnapshot =
          await FirebaseFirestore.instance
              .collection('pets')
              .where('adoptedByUserId', isEqualTo: widget.userId)
              .where('adoptionStatus', isEqualTo: 'Adopted')
              .get();

      final pets =
          adoptedSnapshot.docs.map((doc) {
            final data = doc.data();
            return PetListing(
              id: doc.id,
              name: data['name'] ?? 'Unknown',
              type: data['petType'] ?? 'Unknown',
              username: widget.username,
              imageUrl: data['imageUrl'] ?? '',
              location:
                  data['location'] != null
                      ? LatLng(
                        data['location']['latitude'] ?? 0.0,
                        data['location']['longitude'] ?? 0.0,
                      )
                      : LatLng(0.0, 0.0),
              userId: widget.userId,
              address: data['address'] ?? '',
              description: data['description'] as String?,
              adoptionStatus: data['adoptionStatus'] as String?,
              adoptedAt:
                  data['adoptedAt'] is Timestamp
                      ? (data['adoptedAt'] as Timestamp).toDate()
                      : null,
            );
          }).toList();

      if (mounted) {
        setState(() {
          _adoptedPets = pets;
        });
      }
    } catch (e) {
      print('Error loading adopted pets: $e');
    }
  }

  Widget _buildProfileHeader() {
    final email = _userData?['email'] as String?;
    final profileImageUrl = _userData?['profileImageUrl'] as String?;
    final createdAt = _userData?['createdAt'] as Timestamp?;
    final memberSince =
        createdAt != null
            ? '${createdAt.toDate().year}-${createdAt.toDate().month.toString().padLeft(2, '0')}'
            : 'Unknown';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            backgroundImage:
                profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
            child:
                profileImageUrl == null
                    ? const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.deepPurple,
                    )
                    : null,
          ),
          const SizedBox(height: 16),
          Text(
            widget.username,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Member since $memberSince',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(
                  'Pets Listed',
                  _userPets
                      .where(
                        (pet) =>
                            pet.adoptionStatus != 'Adopted' &&
                            pet.adoptionStatus != 'Pending Review',
                      )
                      .length
                      .toString(),
                  Icons.pets,
                ),
                _buildVerticalDivider(),
                _buildStatCard(
                  'Adopted',
                  _adoptedPets.length.toString(),
                  Icons.favorite,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 40, width: 1, color: Colors.white24);
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetCard(PetListing pet) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            pet.imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.pets, color: Colors.grey),
              );
            },
          ),
        ),
        title: Text(
          pet.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pet.type),
            if ((pet.adoptionStatus ?? '').toLowerCase() == 'adopted')
              const Text(
                'Adopted',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          final isOwner = _authService.currentUserId == pet.userId;
          await PetDetailsSheet.show(
            context,
            pet,
            isOwner,
            _authService,
            (p) async {}, // Can't save from here
            (id) async => false, // Can't check saved status
            (p) async {}, // Can't delete
            readOnly: true,
          );
        },
      ),
    );
  }

  Widget _buildAdoptedPetCard(PetListing pet) {
    final adoptedAt = pet.adoptedAt;
    final adoptedSince =
        adoptedAt != null
            ? '${adoptedAt.year}-${adoptedAt.month.toString().padLeft(2, '0')}-${adoptedAt.day.toString().padLeft(2, '0')}'
            : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            pet.imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.pets, color: Colors.grey),
              );
            },
          ),
        ),
        title: Row(
          children: const [
            Text(
              'Adopted',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(pet.type),
            if (adoptedSince != null) Text('Adopted since $adoptedSince'),
          ],
        ),
      ),
    );
  }

  Future<void> _startConversation() async {
    if (!_authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to start a conversation')),
      );
      return;
    }

    // Check if trying to message self
    if (_authService.currentUserId == widget.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot message yourself')),
      );
      return;
    }

    try {
      // Get current user data
      final userData = await _authService.getUserData();
      if (userData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get user data. Please try again.'),
          ),
        );
        return;
      }

      final currentUserId = _authService.currentUserId!;
      final currentUsername = userData['username'] as String? ?? 'User';
      final currentUserAvatar = userData['profileImageUrl'] as String?;

      // Get other user's avatar
      String? otherUserAvatar;
      if (_userData != null && _userData!['profileImageUrl'] != null) {
        otherUserAvatar = _userData!['profileImageUrl'] as String;
      }

      // Create participant maps
      final participantIds = [currentUserId, widget.userId];
      final participantNames = {
        currentUserId: currentUsername,
        widget.userId: widget.username,
      };

      final participantAvatars = <String, String>{};
      if (currentUserAvatar != null) {
        participantAvatars[currentUserId] = currentUserAvatar;
      }
      if (otherUserAvatar != null) {
        participantAvatars[widget.userId] = otherUserAvatar;
      }

      // Create general chat room (no pet info)
      final chatRoom = ChatRoom(
        id: '',
        participantIds: participantIds,
        participants: {
          currentUserId: {'id': currentUserId, 'username': currentUsername},
          widget.userId: {'id': widget.userId, 'username': widget.username},
        },
        participantNames: participantNames,
        participantAvatars: participantAvatars,
        lastMessageTime: Timestamp.now(),
        lastMessageContent: 'Started a conversation',
        petId: null, // No pet context
        petName: null,
        petImageUrl: null,
      );

      final chatService = ChatService();
      final chatRoomId = await chatService.createChatRoom(chatRoom);

      if (!mounted) return;

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ChatScreen(
                chatRoomId: chatRoomId,
                otherUserId: widget.userId,
                otherUserName: widget.username,
                petId: null,
                petName: null,
                petImageUrl: null,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if viewing own profile
    final isOwnProfile = _authService.currentUserId == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.username}\'s Profile',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileHeader(),
                    if (!isOwnProfile) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton.icon(
                          onPressed: _startConversation,
                          icon: const Icon(Icons.message),
                          label: const Text('Contact Owner'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).primaryColor,
                      tabs: const [
                        Tab(text: 'Active Listings'),
                        Tab(text: 'Adopted Pets'),
                      ],
                    ),
                    SizedBox(
                      height: 400, // Fixed height for tab content
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildActivePetsTab(),
                          _buildAdoptedPetsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildActivePetsTab() {
    if (_userPets.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No active listings',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _userPets.length,
      itemBuilder: (context, index) => _buildPetCard(_userPets[index]),
    );
  }

  Widget _buildAdoptedPetsTab() {
    if (_adoptedPets.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No adopted pets yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _adoptedPets.length,
      itemBuilder:
          (context, index) => _buildAdoptedPetCard(_adoptedPets[index]),
    );
  }
}
