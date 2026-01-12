import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'dart:async';
import '../models/pet_listing.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
// import 'saved_pets_screen.dart';
import 'auth_screen.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'settings_screen.dart';
import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import '../services/location_service.dart';
import 'package:geocoding/geocoding.dart';
import 'map/pet_details_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  // Removed unused notification service field
  List<PetListing> _userPets = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  late TabController _tabController;
  List<PetListing> _adoptedPets = [];
  List<PetListing> _savedPets = [];
  String? _username;
  String? _email;
  // Removed unused notification radius state
  // final GlobalKey _cropBoundaryKey = GlobalKey();
  final TransformationController _cropTransformController =
      TransformationController();
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cropTransformController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    if (_authService.isLoggedIn) {
      final userData = await _authService.getUserData();
      if (mounted) {
        setState(() {
          _username = userData?['username'] ?? 'User';
          _email = userData?['email'] ?? '';
          _userData = userData; // ensure avatar gets profileImageUrl
        });
      }
      await _loadUserPets();
      await _loadAdoptedPets();
      await _loadSavedPets();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedPets() async {
    if (!_authService.isLoggedIn) return;

    try {
      final userId = _authService.currentUserId;
      final savedPetsSnapshot =
          await FirebaseFirestore.instance
              .collection('saved_pets')
              .where('userId', isEqualTo: userId)
              .get();

      if (savedPetsSnapshot.docs.isEmpty) {
        setState(() {
          _savedPets = [];
        });
        return;
      }

      // Get the pet IDs from saved_pets collection
      final petIds =
          savedPetsSnapshot.docs
              .map((doc) => doc.data()['petId'] as String)
              .toList();

      // Fetch the actual pet data from pets collection
      final List<PetListing> savedPetsList = [];

      for (final petId in petIds) {
        final petDoc =
            await FirebaseFirestore.instance
                .collection('pets')
                .doc(petId)
                .get();

        if (petDoc.exists) {
          final data = petDoc.data()!;
          // Fetch owner username from users collection
          String ownerUsername = 'Unknown';
          try {
            final ownerId = (data['userId'] ?? '') as String;
            if (ownerId.isNotEmpty) {
              ownerUsername = await _authService.getUsernameById(ownerId);
            }
          } catch (_) {}
          savedPetsList.add(
            PetListing(
              id: petDoc.id,
              name: data['name'] ?? 'Unknown',
              type: data['petType'] ?? 'Unknown',
              username: ownerUsername,
              imageUrl: data['imageUrl'] ?? '',
              location:
                  data['location'] != null
                      ? LatLng(
                        data['location']['latitude'] ?? 0.0,
                        data['location']['longitude'] ?? 0.0,
                      )
                      : LatLng(0.0, 0.0),
              userId: data['userId'] ?? '',
              address: data['address'] ?? '',
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _savedPets = savedPetsList;
        });
      }

      // Debug print to verify count
      print('Saved pets loaded: ${_savedPets.length}');
    } catch (e) {
      print('Error loading saved pets: $e');
    }
  }

  Future<void> _loadUserPets() async {
    if (!_authService.isLoggedIn) return;

    try {
      final userId = _authService.currentUserId;
      final userPetsSnapshot =
          await FirebaseFirestore.instance
              .collection('pets')
              .where('userId', isEqualTo: userId)
              .get();

      if (mounted) {
        setState(() {
          _userPets =
              userPetsSnapshot.docs.map((doc) {
                final data = doc.data();
                return PetListing(
                  id: doc.id,
                  name: data['name'] ?? 'Unknown',
                  type: data['petType'] ?? 'Unknown',
                  username: _username ?? 'User',
                  imageUrl: data['imageUrl'] ?? '',
                  location:
                      data['location'] != null
                          ? LatLng(
                            data['location']['latitude'] ?? 0.0,
                            data['location']['longitude'] ?? 0.0,
                          )
                          : LatLng(0.0, 0.0),
                  userId: data['userId'] ?? '',
                  address: data['address'] ?? '',
                  description: data['description'] as String?,
                  adoptionStatus: data['adoptionStatus'] as String?,
                  adoptedAt:
                      data['adoptedAt'] is Timestamp
                          ? (data['adoptedAt'] as Timestamp).toDate()
                          : null,
                );
              }).toList();
        });
      }

      print('User pets loaded: ${_userPets.length}');
      for (var pet in _userPets) {
        print('Pet: ${pet.name}, Type: ${pet.type}, ID: ${pet.id}');
      }
    } catch (e) {
      print('Error loading user pets: $e');
    }
  }

  Future<void> _loadAdoptedPets() async {
    if (!_authService.isLoggedIn) return;

    try {
      final userId = _authService.currentUserId;
      final adoptedSnapshot =
          await FirebaseFirestore.instance
              .collection('pets')
              .where('adoptedByUserId', isEqualTo: userId)
              .where('adoptionStatus', isEqualTo: 'Adopted')
              .get();

      final List<PetListing> adopted =
          adoptedSnapshot.docs.map((doc) {
            final data = doc.data();
            return PetListing(
              id: doc.id,
              name: data['name'] ?? 'Unknown',
              type: data['petType'] ?? 'Unknown',
              username: _username ?? 'User',
              imageUrl: data['imageUrl'] ?? '',
              location:
                  data['location'] != null
                      ? LatLng(
                        data['location']['latitude'] ?? 0.0,
                        data['location']['longitude'] ?? 0.0,
                      )
                      : LatLng(0.0, 0.0),
              userId: data['userId'] ?? '',
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
          _adoptedPets = adopted;
        });
      }
    } catch (e) {
      print('Error loading adopted pets: $e');
    }
  }

  Future<void> _deletePet(PetListing pet) async {
    try {
      // Show confirmation dialog
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

      // Delete from Firestore
      await FirebaseFirestore.instance.collection('pets').doc(pet.id).delete();

      // Delete related saved_pets documents
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
          _userPets.removeWhere((p) => p.id == pet.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet listing deleted successfully')),
        );
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

  Widget _buildPetCard(PetListing pet) {
    final isPendingReview = pet.adoptionStatus == 'Pending Review';
    
    final cardWidget = Dismissible(
      key: Key(pet.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
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
        );
      },
      onDismissed: (direction) => _deletePet(pet),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isPendingReview ? Colors.grey[100] : null,
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColorFiltered(
              colorFilter: isPendingReview
                  ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                  : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
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
          ),
          title: Text(
            pet.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPendingReview ? Colors.grey[600] : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pet.type,
                style: TextStyle(
                  color: isPendingReview ? Colors.grey[500] : null,
                ),
              ),
              if (isPendingReview)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: const Text(
                    'Pending Review',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: isPendingReview ? Colors.grey : Colors.red,
                ),
                onPressed: () => _deletePet(pet),
                tooltip: 'Delete listing',
              ),
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: isPendingReview ? Colors.grey : Colors.deepPurple,
                ),
                onPressed: () => _showEditPetDialog(pet),
                tooltip: 'Edit',
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isPendingReview ? Colors.grey[400] : null,
              ),
            ],
          ),
          onTap: () async {
            final isOwner = true;
            await PetDetailsSheet.show(
              context,
              pet,
              isOwner,
              _authService,
              (p) => _toggleSavePet(p),
              (id) => _isPetSaved(id),
              (p) => _deletePet(p),
              readOnly: true,
            );
          },
        ),
      ),
    );
    
    // Apply opacity for pending review items
    if (isPendingReview) {
      return Opacity(
        opacity: 0.7,
        child: cardWidget,
      );
    }
    
    return cardWidget;
  }

  Future<void> _showEditPetDialog(PetListing pet) async {
    final BuildContext parentContext = context;
    String name = pet.name;
    String type = pet.type;
    String description = pet.description ?? '';
    String adoptionStatus = 'Available';
    String healthStatus = 'Healthy';
    final List<String> healthStatusesOptions = const [
      'Healthy',
      'Well-fed',
      'Needs medical attention',
      'Recovering',
      'Requires special care',
      'Vaccinated',
      'Dewormed',
      'Spayed/Neutered',
      'Not spayed/neutered',
      'Unknown',
    ];
    final Map<String, String> healthEmojis = const {
      'Healthy': '❤️',
      'Well-fed': '🍽️',
      'Needs medical attention': '🏥',
      'Recovering': '🩹',
      'Requires special care': '🧑‍⚕️',
      'Vaccinated': '💉',
      'Dewormed': '🦠',
      'Spayed/Neutered': '✂️',
      'Not spayed/neutered': '❌',
      'Unknown': '❓',
    };
    final Set<String> selectedHealthStatuses = <String>{};
    String breed = '';
    String ageStr = '';
    LatLng? newLocation;
    String? newAddress;

    // Fetch current full doc to prefill optional fields
    try {
      final snap =
          await FirebaseFirestore.instance.collection('pets').doc(pet.id).get();
      final data = snap.data();
      if (data != null) {
        adoptionStatus = (data['adoptionStatus'] as String?) ?? adoptionStatus;
        healthStatus = (data['healthStatus'] as String?) ?? healthStatus;
        breed = (data['breed'] as String?) ?? breed;
        final int? ageNum =
            data['age'] is num ? (data['age'] as num).toInt() : null;
        ageStr = ageNum?.toString() ?? ageStr;
        if (data['healthStatuses'] is List) {
          selectedHealthStatuses.addAll(
            (data['healthStatuses'] as List).whereType<String>(),
          );
        } else if ((data['healthStatus'] as String?) != null) {
          selectedHealthStatuses.addAll(
            (data['healthStatus'] as String)
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty),
          );
        }
      }
    } catch (_) {}

    final nameCtrl = TextEditingController(text: name);
    final descCtrl = TextEditingController(text: description);
    final breedCtrl = TextEditingController(text: breed);
    final ageCtrl = TextEditingController(text: ageStr);

    await showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Edit Pet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type.isEmpty ? null : type,
                      items:
                          const [
                                'Cat',
                                'Dog',
                                'Bird',
                                'Fish',
                                'Rabbit',
                                'Hamster',
                                'Guinea Pig',
                                'Turtle',
                                'Other',
                              ]
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (v) => setSheetState(() => type = v ?? type),
                      decoration: const InputDecoration(
                        labelText: 'Pet Type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: breedCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Breed',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: adoptionStatus.isEmpty ? null : adoptionStatus,
                      items:
                          const ['Available', 'Adopted', 'Pending']
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged:
                          (v) => setSheetState(
                            () => adoptionStatus = v ?? adoptionStatus,
                          ),
                      decoration: const InputDecoration(
                        labelText: 'Adoption Status',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Health Status (multi-select chips)
                    const SizedBox(height: 12),
                    const Text(
                      'Health Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: healthStatusesOptions.map((status) {
                          final bool isSelected =
                              selectedHealthStatuses.contains(status);
                          final emoji = healthEmojis[status] ?? '❇️';
                          return FilterChip(
                            label: Text('$emoji  $status'),
                            selected: isSelected,
                            onSelected: (val) {
                              setSheetState(() {
                                if (val) {
                                  selectedHealthStatuses.add(status);
                                } else {
                                  selectedHealthStatuses.remove(status);
                                }
                              });
                            },
                            selectedColor: Colors.deepPurple[50],
                            checkmarkColor: Colors.deepPurple,
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.deepPurple
                                  : Colors.grey.shade300,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final loc =
                              await LocationService.getCurrentLocation();
                          final lat = loc['latitude']!;
                          final lng = loc['longitude']!;
                          String addr = '';
                          try {
                            final placemarks = await placemarkFromCoordinates(
                              lat,
                              lng,
                            );
                            if (placemarks.isNotEmpty) {
                              final p = placemarks.first;
                              addr = [
                                    p.street,
                                    p.locality,
                                    p.administrativeArea,
                                    p.country,
                                  ]
                                  .where((s) => (s ?? '').isNotEmpty)
                                  .map((s) => s ?? '')
                                  .join(', ');
                            }
                          } catch (_) {}
                          setSheetState(() {
                            newLocation = LatLng(lat, lng);
                            newAddress = addr.isNotEmpty ? addr : null;
                          });
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Location error: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.my_location),
                      label: Text(
                        newLocation == null
                            ? 'Use my current location'
                            : 'New location set${newAddress != null ? ' • $newAddress' : ''}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final update = <String, dynamic>{
                            'name': nameCtrl.text.trim(),
                            'petType': type,
                            'breed': breedCtrl.text.trim(),
                            'age': int.tryParse(ageCtrl.text.trim()) ?? 0,
                            'adoptionStatus': adoptionStatus,
                            'healthStatus': selectedHealthStatuses.isEmpty
                                ? 'Unknown'
                                : selectedHealthStatuses.join(', '),
                            'healthStatuses':
                                selectedHealthStatuses.toList(),
                            'description': descCtrl.text.trim(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          };
                          if (newLocation != null) {
                            update['location'] = {
                              'latitude': newLocation?.latitude,
                              'longitude': newLocation?.longitude,
                            };
                            if (newAddress != null) {
                              update['address'] = newAddress;
                            }
                          }

                          await FirebaseFirestore.instance
                              .collection('pets')
                              .doc(pet.id)
                              .set(update, SetOptions(merge: true));

                          if (!mounted) return;
                          Navigator.pop(parentContext);
                          await _loadUserPets();
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(content: Text('Pet updated')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(content: Text('Update failed: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader() {
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
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white,
                backgroundImage:
                    _userData != null && _userData!['profileImageUrl'] != null
                        ? NetworkImage(_userData!['profileImageUrl'])
                        : null,
                child:
                    _userData != null && _userData!['profileImageUrl'] != null
                        ? null
                        : const Icon(
                          Icons.person,
                          size: 45,
                          color: Colors.deepPurple,
                        ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () async {
                    await _handleChangeProfilePhoto();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _username ?? 'User',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _showEditUsernameDialog,
            icon: const Icon(Icons.edit, size: 16, color: Colors.white),
            label: const Text(
              'Edit name',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _email ?? '',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
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
                  _userPets.where((pet) => pet.adoptionStatus != 'Adopted' && pet.adoptionStatus != 'Pending Review').length.toString(),
                  Icons.pets,
                ),
                _buildVerticalDivider(),
                _buildStatCard(
                  'Adopted',
                  _adoptedPets.length.toString(),
                  Icons.favorite,
                ),
                _buildVerticalDivider(),
                FutureBuilder<int>(
                  key: ValueKey(
                    'saved_pets_count_${DateTime.now().millisecondsSinceEpoch}',
                  ),
                  future: _getSavedPetsCount(),
                  builder: (context, snapshot) {
                    final count =
                        snapshot.hasData ? snapshot.data.toString() : '0';
                    return _buildStatCard('Saved', count, Icons.bookmark);
                  },
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

  @override
  Widget build(BuildContext context) {
    if (!_authService.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Please sign in to view your profile',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  );
                },
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _openSettingsScreen,
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _showLogoutConfirmation,
            tooltip: 'Logout',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildUserHeader(),
                    const Divider(),
                    TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).primaryColor,
                      tabs: const [
                        Tab(text: 'My Listings'),
                        Tab(text: 'Saved Pets'),
                        Tab(text: 'Adopted'),
                      ],
                    ),
                    Container(
                      height:
                          _userPets.isEmpty &&
                                  _savedPets.isEmpty &&
                                  _adoptedPets.isEmpty
                              ? 100 // Small height if no pets
                              : math.max(
                                    math.max(
                                      _userPets.length,
                                      _savedPets.length,
                                    ),
                                    _adoptedPets.length,
                                  ) *
                                  100, // Dynamic height based on content
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildUserPetsTab(),
                          _buildSavedPetsTab(),
                          _buildAdoptedPetsTab(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
    );
  }

  Widget _buildUserHeader() {
    return _buildProfileHeader();
  }

  Widget _buildUserPetsTab() {
    if (_userPets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'You haven\'t listed any pets yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to add pet screen via the bottom navigation
                // This is a simple approach; you might need to adjust based on your navigation
                Navigator.pop(context);
                // Go to map screen to select a location for adding a pet
              },
              icon: const Icon(Icons.add),
              label: const Text('Add a Pet Listing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return _buildPetsList(_userPets);
  }

  Widget _buildSavedPetsTab() {
    if (_savedPets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'You haven\'t saved any pets yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to explore screen
                Navigator.pop(context);
                // This assumes the explore/map is at index 0 of your bottom navigation
              },
              icon: const Icon(Icons.search),
              label: const Text('Explore Pets'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return _buildSavedPetsList(_savedPets);
  }

  Widget _buildAdoptedPetsTab() {
    if (_adoptedPets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
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

  Widget _buildPetsList(List<PetListing> pets) {
    return ListView.builder(
      itemCount: pets.length,
      itemBuilder: (context, index) => _buildPetCard(pets[index]),
    );
  }

  Widget _buildSavedPetsList(List<PetListing> pets) {
    return ListView.builder(
      itemCount: pets.length,
      itemBuilder: (context, index) => _buildReadonlyPetCard(pets[index]),
    );
  }

  Widget _buildReadonlyPetCard(PetListing pet) {
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
            const SizedBox(height: 2),
            Text(
              'Owner: ${pet.username}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () async {
          final isOwner = _authService.currentUserId == pet.userId;
          await PetDetailsSheet.show(
            context,
            pet,
            isOwner,
            _authService,
            (p) => _toggleSavePet(p),
            (id) => _isPetSaved(id),
            (p) => _deletePet(p),
          );
        },
      ),
    );
  }

  Future<void> _toggleSavePet(PetListing pet) async {
    if (!_authService.isLoggedIn) return;
    try {
      final userId = _authService.currentUserId;
      final savedRef = FirebaseFirestore.instance
          .collection('saved_pets')
          .doc('${userId}_${pet.id}');
      final exists = (await savedRef.get()).exists;
      if (exists) {
        await savedRef.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet removed from saved pets')),
          );
        }
        setState(() {
          _savedPets.removeWhere((p) => p.id == pet.id);
        });
      } else {
        await savedRef.set({
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to toggle save')));
      }
    }
  }

  Future<bool> _isPetSaved(String petId) async {
    if (!_authService.isLoggedIn) return false;
    try {
      final userId = _authService.currentUserId;
      final snap =
          await FirebaseFirestore.instance
              .collection('saved_pets')
              .doc('${userId}_${petId}')
              .get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  Future<int> _getSavedPetsCount() async {
    if (!_authService.isLoggedIn) return 0;

    try {
      final userId = _authService.currentUserId;
      final savedPetsSnapshot =
          await FirebaseFirestore.instance
              .collection('saved_pets')
              .where('userId', isEqualTo: userId)
              .get();

      return savedPetsSnapshot.docs.length;
    } catch (e) {
      print('Error getting saved pets count: $e');
      return 0;
    }
  }

  // Notification radius settings removed as unused

  void _openSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _showEditUsernameDialog() async {
    final controller = TextEditingController(text: _username ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Name'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (newName == null || newName.isEmpty) return;

    try {
      final userId = _authService.currentUserId;
      if (userId == null) return;
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'username': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _username = newName;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update name: $e')));
    }
  }

  Future<void> _handleChangeProfilePhoto() async {
    final File? picked = await UserProfileService.showProfileImagePickerDialog(
      context,
    );
    if (picked == null) return;

    setState(() {
      _isLoading = true;
    });

    final imageUrl = await UserProfileService.uploadProfileImage(picked);
    if (!mounted) return;
    if (imageUrl != null) {
      await _loadUserData();
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload profile image')),
      );
    }
  }

  // Show confirmation dialog before logging out
  Future<void> _showLogoutConfirmation() async {
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Logout'),
                  ),
                ],
              ),
        ) ??
        false;

    if (shouldLogout && mounted) {
      await _authService.signOut();
      // Clear entire navigation stack to properly dispose all screens and their listeners
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false, // Remove all previous routes
      );
    }
  }
}
