import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../models/pet_listing.dart';
import 'map_screen.dart';
import 'add_pet_screen.dart';
import 'map/pet_details_sheet.dart';
import 'donation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedCategory = 'All';
  LatLng? _currentLocation;
  bool _showAdoptedPets = false; // Hide adopted pets by default
  bool _isGridView = true; // true = 2 columns, false = 1 column (list)

  final List<String> _categories = [
    'All',
    'Cat',
    'Dog',
    'Bird',
    'Fish',
    'Rabbit',
    'Hamster',
    'Guinea Pig',
    'Turtle',
    'Other',
  ];

  final Map<String, IconData> _categoryIcons = {
    'All': Icons.pets,
    'Cat': Icons.pets,
    'Dog': Icons.pets,
    'Bird': Icons.flutter_dash,
    'Fish': Icons.water,
    'Rabbit': Icons.cruelty_free,
    'Hamster': Icons.pets,
    'Guinea Pig': Icons.pets,
    'Turtle': Icons.pets,
    'Other': Icons.category,
  };

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(
            location['latitude'] ?? 0.0,
            location['longitude'] ?? 0.0,
          );
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      // Silently fail, location features will be disabled
    }
  }

  // Calculate distance between two coordinates
  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar with Search
            _buildAppBar(),

            // Quick Stats
            SliverToBoxAdapter(child: _buildQuickStats()),

            // Browse Pets Section Header
            SliverToBoxAdapter(child: _buildBrowsePetsHeader()),

            // Category Filter
            SliverToBoxAdapter(child: _buildCategoryFilter()),

            // Show Adopted Pets Toggle
            SliverToBoxAdapter(child: _buildAdoptedToggle()),

            // Pet Grid Header
            SliverToBoxAdapter(child: _buildPetGridHeader()),

            // Featured Pets Grid
            _buildFeaturedPetsGrid(),

            // Map Button
            SliverToBoxAdapter(child: _buildMapButton()),

            // Donation Banner
            SliverToBoxAdapter(child: _buildDonationBanner()),

            // Footer - About Us
            SliverToBoxAdapter(child: _buildFooter()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPetLocationPicker,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Pet', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.deepPurple,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple, Colors.deepPurple.shade700],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/adoptlyLogo_White.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  // Description
                  Text(
                    'Find your perfect companion and give them a loving home 🏡',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('pets').snapshots(),
        builder: (context, snapshot) {
          int totalPets = 0;
          int userPets = 0;
          int availablePets = 0;

          if (snapshot.hasData) {
            totalPets = snapshot.data!.docs.length;
            availablePets =
                snapshot.data!.docs
                    .where(
                      (doc) =>
                          (doc.data() as Map)['adoptionStatus'] == 'Available',
                    )
                    .length;
            userPets =
                snapshot.data!.docs
                    .where(
                      (doc) {
                        final data = doc.data() as Map;
                        return data['userId'] == _authService.currentUserId &&
                            data['adoptionStatus'] != 'Adopted' &&
                            data['adoptionStatus'] != 'Pending Review';
                      },
                    )
                    .length;
          }

          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Available',
                  '$availablePets',
                  Icons.pets,
                  Colors.green,
                ),
              ),
              if (userPets >= 1) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Your Pets',
                    '$userPets',
                    Icons.favorite,
                    Colors.deepPurple,
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total',
                  '$totalPets',
                  Icons.list_alt,
                  Colors.orange,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildMapButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MapScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Explore Pet Map',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Find pets near you on an interactive map',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrowsePetsHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.pets, color: Colors.deepPurple, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Browse Pets',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                'Find your perfect companion',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Filter by Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _categoryIcons[category] ?? Icons.category,
                          size: 18,
                          color: isSelected ? Colors.white : Colors.deepPurple,
                        ),
                        const SizedBox(width: 6),
                        Text(category),
                      ],
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: Colors.deepPurple,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.deepPurple,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    elevation: isSelected ? 4 : 1,
                    shadowColor: Colors.deepPurple.withOpacity(0.5),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdoptedToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _showAdoptedPets
                  ? Colors.deepPurple.shade200
                  : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                _showAdoptedPets
                    ? Colors.deepPurple.withOpacity(0.1)
                    : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: _showAdoptedPets ? Colors.deepPurple : Colors.grey[600],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Show Adopted Pets',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Include pets that have already been adopted',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: _showAdoptedPets,
            onChanged: (value) {
              setState(() {
                _showAdoptedPets = value;
              });
            },
            activeColor: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildPetGridHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('pets').snapshots(),
      builder: (context, snapshot) {
        int petCount = 0;
        if (snapshot.hasData) {
          // Count pets based on current filters
          petCount =
              snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final petType = data['petType']?.toString() ?? '';
                final adoptionStatus =
                    data['adoptionStatus']?.toString() ?? 'Available';

                // Always hide pending review pets (not yet approved by admin)
                if (adoptionStatus == 'Pending Review') {
                  return false;
                }

                // Hide adopted pets if toggle is off
                if (!_showAdoptedPets &&
                    adoptionStatus.toLowerCase() == 'adopted') {
                  return false;
                }

                // Category filter
                if (_selectedCategory != 'All' &&
                    petType != _selectedCategory) {
                  return false;
                }

                return true;
              }).length;
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Text(
                'Available Pets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$petCount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isGridView ? Icons.view_list : Icons.grid_view_rounded,
                    size: 22,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDonationBanner() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DonationScreen()),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/adoptlyDonation_Donate.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // About Us Header
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.deepPurple.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'About Us',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Why We Did This Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Colors.deepPurple,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Our Mission',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'In Malaysia, pet adoption still mainly happens through physical shelter visits, which can be time-consuming and inconvenient. While there are online platforms, many have a poor user experience and lack real-time features.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Plus, adoption efforts are scattered across different sites and social media, making it hard for users to find pets easily. That\'s where ADOPTLY comes in, a mobile app designed to streamline the adoption process with a clean interface, interactive features, and real-time updates, helping connect users with pets and shelters across the country.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Team Members Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: Colors.deepPurple,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Our Team',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTeamMember('ELFI SHAHRIN BIN ABD KARIM'),
                  const SizedBox(height: 12),
                  _buildTeamMember('AZIZUL HAKIM BIN AB MAULOD'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Footer Bottom
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/adoptlyLogo_White.png',
                    height: 40,
                    color: Colors.deepPurple.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '© 2025 Adoptly',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Making Pet Adoption Easy & Accessible',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
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

  Widget _buildTeamMember(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedPetsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('pets')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState());
        }

        // Filter pets based on selected category and adoption status
        var filteredDocs =
            snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final petType = data['petType']?.toString() ?? '';
              final adoptionStatus =
                  data['adoptionStatus']?.toString() ?? 'Available';

              // Always hide pending review pets (not yet approved by admin)
              if (adoptionStatus == 'Pending Review') {
                return false;
              }

              // Hide adopted pets if toggle is off
              if (!_showAdoptedPets &&
                  adoptionStatus.toLowerCase() == 'adopted') {
                return false;
              }

              // Category filter
              if (_selectedCategory != 'All' && petType != _selectedCategory) {
                return false;
              }

              return true;
            }).toList();

        // Sort: Available pets first, then adopted pets at the bottom
        filteredDocs.sort((a, b) {
          final aStatus =
              (a.data() as Map<String, dynamic>)['adoptionStatus']
                  ?.toString() ??
              'Available';
          final bStatus =
              (b.data() as Map<String, dynamic>)['adoptionStatus']
                  ?.toString() ??
              'Available';

          final aIsAdopted = aStatus.toLowerCase() == 'adopted';
          final bIsAdopted = bStatus.toLowerCase() == 'adopted';

          if (aIsAdopted && !bIsAdopted) return 1; // a goes after b
          if (!aIsAdopted && bIsAdopted) return -1; // a goes before b
          return 0; // keep original order
        });

        if (filteredDocs.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState());
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _isGridView ? 2 : 1,
              childAspectRatio: _isGridView ? 0.75 : 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildPetCard(doc.id, data);
            }, childCount: filteredDocs.length),
          ),
        );
      },
    );
  }

  Widget _buildPetCard(String petId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unknown';
    final petType = data['petType'] ?? 'Pet';
    final breed = data['breed'] ?? '';
    final imageUrl = data['imageUrl'] ?? '';
    final adoptionStatus = data['adoptionStatus'] ?? 'Available';
    final location = data['location'];
    final userId = data['userId'] ?? '';

    // Calculate distance if location is available
    String distanceText = '';
    if (_currentLocation != null && location != null) {
      try {
        final petLocation = LatLng(
          location['latitude'] ?? 0.0,
          location['longitude'] ?? 0.0,
        );
        final distance = _calculateDistance(_currentLocation!, petLocation);
        distanceText = '${distance.toStringAsFixed(1)} km away';
      } catch (e) {
        distanceText = '';
      }
    }

    final isAvailable = adoptionStatus == 'Available';

    return GestureDetector(
      onTap: () => _showPetDetails(petId, data),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pet Image
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child:
                        imageUrl.isNotEmpty
                            ? Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stack) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.pets,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                            )
                            : Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.pets,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                  ),
                  // Status Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isAvailable
                                ? Colors.green.withOpacity(0.9)
                                : Colors.orange.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        adoptionStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Pet Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _categoryIcons[petType] ?? Icons.pets,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          breed.isNotEmpty ? '$petType • $breed' : petType,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<String>(
                    future: _authService.getUsernameById(userId),
                    builder: (context, snapshot) {
                      final username = snapshot.data ?? 'Loading...';
                      return Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'by $username',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (distanceText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distanceText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No pets available yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to add a pet!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddPetLocationPicker,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Pet', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPetDetails(String petId, Map<String, dynamic> data) async {
    try {
      final location = data['location'];
      final userId = data['userId'] ?? '';

      // Fetch the username
      final username = await _authService.getUsernameById(userId);

      final petListing = PetListing(
        id: petId,
        name: data['name'] ?? 'Unknown',
        type: data['petType'] ?? 'Pet',
        username: username,
        imageUrl: data['imageUrl'] ?? '',
        location: LatLng(
          location['latitude'] ?? 0.0,
          location['longitude'] ?? 0.0,
        ),
        userId: userId,
        address: data['address'],
        description: data['description'],
        adoptionStatus: data['adoptionStatus'],
      );

      final isOwner = userId == _authService.currentUserId;

      // Show pet details sheet
      await PetDetailsSheet.show(
        context,
        petListing,
        isOwner,
        _authService,
        _savePet,
        _isPetSaved,
        _deletePet,
      );
    } catch (e) {
      print('Error showing pet details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pet details: $e')),
        );
      }
    }
  }

  Future<void> _savePet(PetListing pet) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return;

      // Toggle saved pets in the top-level `saved_pets` collection (matches Firestore rules
      // and is used by SavedPets/Profile/Map screens).
      final ref = _firestore.collection('saved_pets').doc('${userId}_${pet.id}');
      final docSnapshot = await ref.get();

      if (docSnapshot.exists) {
        // Already saved - remove it
        await ref.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet removed from saved pets')),
          );
        }
      } else {
        // Not saved - add it
        await ref.set({
          'userId': userId,
          'petId': pet.id,
          'savedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet saved successfully')),
          );
        }
      }
    } catch (e) {
      print('Error saving pet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update saved pet')),
        );
      }
    }
  }

  Future<bool> _isPetSaved(String petId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return false;

      final doc =
          await _firestore
              .collection('saved_pets')
              .doc('${userId}_${petId}')
              .get();

      return doc.exists;
    } catch (e) {
      print('Error checking saved pet: $e');
      return false;
    }
  }

  Future<void> _deletePet(PetListing pet) async {
    try {
      await _firestore.collection('pets').doc(pet.id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet deleted successfully')),
        );
      }
    } catch (e) {
      print('Error deleting pet: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting pet: $e')));
      }
    }
  }

  Future<void> _showAddPetLocationPicker() async {
    if (!_authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add a pet')),
      );
      return;
    }

    // Show dialog to choose location method
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Choose Location'),
            content: const Text('How would you like to set the pet location?'),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  // Use current location
                  if (_currentLocation != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                AddPetScreen(location: _currentLocation!),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to get current location'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Current Location'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Open map to pick location in selection mode
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => const MapScreen(
                            startInLocationSelectionMode: true,
                          ),
                    ),
                  );
                },
                icon: const Icon(Icons.map),
                label: const Text('Pick on Map'),
              ),
            ],
          ),
    );
  }
}
