import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'add_pet_screen.dart';
import 'auth_screen.dart';
import '../models/pet_listing.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'map/map_widgets.dart';
import '../models/shop_place.dart';
import 'map/pet_details_sheet.dart';
import 'map/nearby_pets_bottom_sheet.dart';
import 'map/location_utils.dart';
import 'dart:async';
import 'settings_screen.dart';
import '../services/env_config.dart';

// MapTiler API key loaded from environment
String get mapTilerApiKey => EnvConfig.mapTilerApiKey;

class MapScreen extends StatefulWidget {
  final String? initialPetId;
  final bool startInLocationSelectionMode;

  const MapScreen({
    Key? key,
    this.initialPetId,
    this.startInLocationSelectionMode = false,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<PetListing> _petListings = [];
  List<ShopPlace> _shops = [];
  bool _showShops = false;
  bool _isSelectingLocation = false;
  LatLng? _selectedLocation;
  final AuthService _authService = AuthService();
  String? _currentUsername;
  LatLng? _userLocation;
  bool _isLoadingLocation = false;
  double _searchRadius = 5.0; // default search radius in km
  Timer? _refreshTimer; // Timer for periodic refresh
  StreamSubscription<QuerySnapshot>?
  _petListingsSubscription; // Firestore subscription

  // (unused) Convert map coordinates to LatLng

  // Fetch pets from Firestore and update the list
  Future<void> _fetchPets() async {
    final querySnapshot =
        await FirebaseFirestore.instance.collection('pets').get();
    final List<PetListing> listings = [];

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final location = data['location'];
      final userId = data['userId'] ?? '';

      // Skip adopted and pending review pets
      final String? adoptionStatus = data['adoptionStatus'] as String?;
      if (adoptionStatus != null && 
          (adoptionStatus.toLowerCase() == 'adopted' || 
           adoptionStatus == 'Pending Review')) {
        continue;
      }

      // Get the username for this pet listing
      String username = await _authService.getUsernameById(userId);

      // Create LatLng object
      LatLng petLocation = LatLng(location['latitude'], location['longitude']);

      // Get address from coordinates
      String? address = await LocationUtils.getAddressFromCoordinates(
        petLocation,
      );

      listings.add(
        PetListing(
          id: doc.id,
          name: data['name'],
          type: data['petType'] ?? 'Unknown',
          username: username,
          imageUrl: data['imageUrl'],
          location: petLocation,
          userId: userId,
          address: address,
          description: data['description'] as String?,
          adoptionStatus: adoptionStatus,
          adoptedAt:
              (data['adoptedAt'] is Timestamp)
                  ? (data['adoptedAt'] as Timestamp).toDate()
                  : null,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _petListings = listings;
      });
    }

    return;
  }

  // Check if the current user is the owner of the pet
  bool _isCurrentUserPetOwner(String petUserId) {
    return _authService.currentUserId == petUserId;
  }

  // Get current user information
  void _getCurrentUser() async {
    if (_authService.isLoggedIn) {
      final userData = await _authService.getUserData();
      if (mounted) {
        setState(() {
          _currentUsername = userData?['username'];
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    setState(() {
      _isLoadingLocation = true;
    });
    _initializeMap().then((_) {
      _fetchPets();
      _getCurrentUser();

      // If initial pet ID is provided, wait for pets to load then show details
      if (widget.initialPetId != null) {
        // Use a delayed future to wait for pets to load
        Future.delayed(const Duration(seconds: 2), () {
          _showInitialPetDetails();
        });
      }

      // If starting in location selection mode, trigger it after map loads
      if (widget.startInLocationSelectionMode) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _startAddingPet();
          }
        });
      }

      // Subscribe to real-time updates
      _subscribeToRealTimeUpdates();

      // Set up periodic refresh (every 5 minutes) as a fallback
      _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (mounted) {
          _fetchPets();
          debugPrint('Refreshed pet listings (periodic 5-minute refresh)');
        }
      });
    });
  }

  // (removed unused _fetchPetsAndWait)

  // Subscribe to real-time updates from Firestore
  void _subscribeToRealTimeUpdates() {
    _petListingsSubscription = FirebaseFirestore.instance
        .collection('pets')
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            _processFirestoreUpdate(snapshot);
          }
        });
    debugPrint('Subscribed to real-time pet listing updates');
  }

  // Process Firestore updates and update the UI
  Future<void> _processFirestoreUpdate(QuerySnapshot snapshot) async {
    // Only process if we have documents
    if (snapshot.docs.isEmpty) return;

    // Check for added/modified documents since we last processed
    final List<PetListing> updatedListings = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final location = data['location'];
      final userId = data['userId'] ?? '';

      // Skip if missing crucial data
      if (location == null) continue;

      // Skip adopted and pending review pets
      final String? adoptionStatus = data['adoptionStatus'] as String?;
      if (adoptionStatus != null && 
          (adoptionStatus.toLowerCase() == 'adopted' || 
           adoptionStatus == 'Pending Review')) {
        continue;
      }

      // Get the username for this pet listing
      String username = await _authService.getUsernameById(userId);

      // Create LatLng object
      LatLng petLocation = LatLng(location['latitude'], location['longitude']);

      // Get address from coordinates
      String? address = await LocationUtils.getAddressFromCoordinates(
        petLocation,
      );

      updatedListings.add(
        PetListing(
          id: doc.id,
          name: data['name'],
          type: data['petType'] ?? 'Unknown',
          username: username,
          imageUrl: data['imageUrl'],
          location: petLocation,
          userId: userId,
          address: address,
          description: data['description'] as String?,
          adoptionStatus: adoptionStatus,
          adoptedAt:
              (data['adoptedAt'] is Timestamp)
                  ? (data['adoptedAt'] as Timestamp).toDate()
                  : null,
        ),
      );
    }

    if (mounted) {
      // Update the list if there are changes
      if (updatedListings.isNotEmpty) {
        setState(() {
          _petListings = updatedListings;
          debugPrint(
            'Updated pet listings from real-time update: ${_petListings.length} pets',
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // Cancel the timer when disposed
    _petListingsSubscription?.cancel(); // Cancel the Firestore subscription
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_userLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isLoadingLocation = true;
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          _mapController.move(_userLocation!, 15.0);
          setState(() {
            _isLoadingLocation = false;
          });
        });
      });
    }
  }

  Future<void> _initializeMap() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final locationMap = await LocationService.getCurrentLocation();
      if (mounted) {
        final latLng = LatLng(
          locationMap['latitude']!,
          locationMap['longitude']!,
        );
        setState(() {
          _userLocation = latLng;
        });
        _mapController.move(latLng, 15.0);

        // Delay setting loading to false to ensure map has time to move
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isLoadingLocation = false;
            });
          }
        });
      }
    } catch (e) {
      print('Error getting initial location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });

        String errorMessage = 'Could not get your location.';
        if (e.toString().contains('permissions are denied')) {
          errorMessage =
              'Location permission denied. Please enable in settings.';
        } else if (e.toString().contains('services are disabled')) {
          errorMessage = 'Location services are disabled. Please enable GPS.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: Duration(seconds: 5),
            action: SnackBarAction(label: 'Retry', onPressed: _refreshLocation),
          ),
        );
      }
    }
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final locationMap = await LocationService.getCurrentLocation();
      if (mounted) {
        final latLng = LatLng(
          locationMap['latitude']!,
          locationMap['longitude']!,
        );
        setState(() {
          _userLocation = latLng;
        });
        _mapController.move(latLng, 15.0);

        // Update could trigger UI recompute (no local nearby cache needed)

        // Delay setting loading to false
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isLoadingLocation = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get your location')),
        );
      }
    }
  }

  void _getUserLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final locationMap = await LocationService.getCurrentLocation();
      if (mounted) {
        final userLatLng = LatLng(
          locationMap['latitude']!,
          locationMap['longitude']!,
        );
        setState(() {
          _userLocation = userLatLng;
        });

        // Delay setting loading to false
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isLoadingLocation = false;
            });
          }
        });
      }
    } catch (e) {
      print('Error getting user location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });

        String errorMessage = 'Could not get your location.';
        if (e.toString().contains('permissions are denied')) {
          errorMessage =
              'Location permission denied. Please enable in settings.';
        } else if (e.toString().contains('services are disabled')) {
          errorMessage = 'Location services are disabled. Please enable GPS.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), duration: Duration(seconds: 5)),
        );
      }
    }
  }

  // Handle map tap to select location
  void _onMapTap(LatLng tappedLocation) {
    if (_isSelectingLocation) {
      setState(() {
        _selectedLocation = tappedLocation;
        _isSelectingLocation = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddPetScreen(location: _selectedLocation!),
        ),
      ).then((_) {
        _fetchPets();
      });
    }
  }

  // Start the process of adding a new pet
  void _addPet() {
    if (!_authService.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      ).then((result) {
        if (result == true) {
          _getCurrentUser();
          _startAddingPet();
        }
      });
    } else {
      _startAddingPet();
    }
  }

  void _startAddingPet() {
    setState(() {
      _isSelectingLocation = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Now tap on the map to select pet location'),
        duration: Duration(seconds: 5),
      ),
    );
  }

  Future<void> _savePet(PetListing pet) async {
    if (!_authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to save pets')),
      );
      return;
    }

    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login again to save pets')),
        );
        return;
      }
      final savedPetRef = FirebaseFirestore.instance
          .collection('saved_pets')
          .doc('${userId}_${pet.id}');

      final docSnapshot = await savedPetRef.get();
      if (docSnapshot.exists) {
        await savedPetRef.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet removed from saved pets')),
          );
        }
      } else {
        await savedPetRef.set({
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
        final msg =
            (e is FirebaseException)
                ? 'Failed to save pet (${e.code})'
                : 'Failed to save pet';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<bool> _isPetSaved(String petId) async {
    if (!_authService.isLoggedIn) return false;

    try {
      final userId = _authService.currentUserId;
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('saved_pets')
              .doc('${userId}_${petId}')
              .get();

      return docSnapshot.exists;
    } catch (e) {
      print('Error checking saved status: $e');
      return false;
    }
  }

  Future<void> _deletePet(PetListing pet) async {
    try {
      bool confirm =
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Delete Pet Listing'),
                  content: const Text(
                    'Are you sure you want to delete this pet listing? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!confirm) return;

      await FirebaseFirestore.instance.collection('pets').doc(pet.id).delete();

      final savedPetsSnapshot =
          await FirebaseFirestore.instance
              .collection('saved_pets')
              .where('petId', isEqualTo: pet.id)
              .get();

      for (var doc in savedPetsSnapshot.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        setState(() {
          _petListings.removeWhere((p) => p.id == pet.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet listing deleted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error deleting pet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete pet listing')),
        );
      }
    }
  }

  void _showPetDetails(PetListing pet, bool isOwner) async {
    _mapController.move(pet.location, 15.0);

    await PetDetailsSheet.show(
      context,
      pet,
      isOwner,
      _authService,
      _savePet,
      _isPetSaved,
      _deletePet,
    );
  }

  // Show details for a specific pet when coming from a notification
  void _showInitialPetDetails() async {
    if (_petListings.isEmpty) return;

    try {
      // Find the pet in our listings
      final petIndex = _petListings.indexWhere(
        (pet) => pet.id == widget.initialPetId,
      );

      // If found, show the pet details
      if (petIndex >= 0) {
        final pet = _petListings[petIndex];

        // Move the map to the pet's location
        _mapController.move(pet.location, 15.0);

        // Wait a moment for the map to update
        await Future.delayed(const Duration(milliseconds: 300));

        // Show the pet details
        if (mounted) {
          _showPetDetails(pet, _isCurrentUserPetOwner(pet.userId));
        }
      }
    } catch (e) {
      print('Error showing initial pet details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pet Listings Map',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              if (!_isLoadingLocation) {
                setState(() {
                  _isLoadingLocation = true;
                });
                _fetchPets().then((_) {
                  setState(() {
                    _isLoadingLocation = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pet listings refreshed')),
                  );
                });
              }
            },
            tooltip: 'Refresh listings',
          ),
          _authService.isLoggedIn
              ? IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                onPressed: () async {
                  await _authService.signOut();
                  setState(() {
                    _currentUsername = null;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out successfully')),
                    );
                  }
                },
              )
              : TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  ).then((result) {
                    if (result == true) {
                      _getCurrentUser();
                    }
                  });
                },
                child: const Text(
                  'Login',
                  style: TextStyle(color: Colors.white),
                ),
              ),
        ],
      ),
      body: Stack(
        children: [
          // Map layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              initialCenter: LatLng(
                0,
                0,
              ), // Default position before we get user location
              initialZoom: 3.0,
              onTap: (tapPosition, latLng) => _onMapTap(latLng),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$mapTilerApiKey',
                userAgentPackageName: 'com.example.app',
              ),
              if (_userLocation != null)
                MapWidgets.buildUserLocationMarker(_userLocation!),
              MapWidgets.buildPetMarkers(
                _petListings,
                _isCurrentUserPetOwner,
                _showPetDetails,
              ),
              if (_showShops)
                MapWidgets.buildShopMarkers(
                  _shops,
                  (latLng) => _mapController.move(latLng, 16.0),
                  context: context,
                  userLocation: _userLocation!,
                ),
            ],
          ),

          // Map legend
          MapWidgets.buildMapLegend(),

          // My location button (positioned above the bottom sheet)
          Positioned(
            right: 16,
            bottom:
                MediaQuery.of(context).size.height *
                0.45, // Position above the sheet
            child: FloatingActionButton(
              heroTag: 'location',
              onPressed: () {
                if (_userLocation != null) {
                  _mapController.move(_userLocation!, 15.0);
                } else {
                  _getUserLocation();
                }
              },
              backgroundColor: Colors.white,
              mini: true,
              child: const Icon(Icons.my_location, color: Colors.deepPurple),
            ),
          ),

          // Loading indicator
          if (_isLoadingLocation)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // Persistent bottom sheet
          if (_userLocation != null)
            DraggableScrollableSheet(
              initialChildSize: 0.25,
              minChildSize: 0.12,
              maxChildSize: 0.9,
              snapSizes: const [0.25, 0.6, 0.9],
              snap: true,
              builder: (context, scrollController) {
                return NearbyPetsBottomSheet(
                  petListings: _petListings,
                  userLocation: _userLocation!,
                  initialSearchRadius: _searchRadius,
                  onRadiusChanged: (value) {
                    setState(() {
                      _searchRadius = value;
                    });
                  },
                  showPetDetails: _showPetDetails,
                  isCurrentUserPetOwner: _isCurrentUserPetOwner,
                  onAddPet: _addPet,
                  scrollController: scrollController,
                  onModeChanged: (isShops) {
                    setState(() {
                      _showShops = isShops;
                    });
                  },
                  onShopsChanged: (shops) {
                    setState(() {
                      _shops = shops;
                    });
                  },
                  onFocusLocation: (loc) {
                    _mapController.move(loc, 16.0);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
