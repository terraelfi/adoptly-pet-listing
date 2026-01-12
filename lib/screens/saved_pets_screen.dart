import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/pet_listing.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'map/pet_details_sheet.dart';

class SavedPetsScreen extends StatefulWidget {
  const SavedPetsScreen({Key? key}) : super(key: key);

  @override
  _SavedPetsScreenState createState() => _SavedPetsScreenState();
}

class _SavedPetsScreenState extends State<SavedPetsScreen> {
  final AuthService _authService = AuthService();
  List<PetListing> _savedPets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPets();
  }

  Future<void> _loadSavedPets() async {
    if (!_authService.isLoggedIn) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final userId = _authService.currentUserId;
      final savedPetsSnapshot =
          await FirebaseFirestore.instance
              .collection('saved_pets')
              .where('userId', isEqualTo: userId)
              .get();

      final List<PetListing> pets = [];

      for (var doc in savedPetsSnapshot.docs) {
        final petId = doc.data()['petId'];
        final petDoc =
            await FirebaseFirestore.instance
                .collection('pets')
                .doc(petId)
                .get();

        if (petDoc.exists) {
          final data = petDoc.data()!;
          final location = data['location'];
          final petUserId = data['userId'] ?? '';
          String username = await _authService.getUsernameById(petUserId);

          pets.add(
            PetListing(
              id: petDoc.id,
              name: data['name'],
              type: data['petType'] ?? 'Unknown',
              username: username,
              imageUrl: data['imageUrl'],
              location: LatLng(location['latitude'], location['longitude']),
              userId: petUserId,
              address: data['address'],
              description: data['description'] as String?,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _savedPets = pets;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading saved pets: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeSavedPet(PetListing pet) async {
    try {
      final userId = _authService.currentUserId;
      await FirebaseFirestore.instance
          .collection('saved_pets')
          .doc('${userId}_${pet.id}')
          .delete();

      setState(() {
        _savedPets.removeWhere((p) => p.id == pet.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet removed from saved list')),
        );
      }
    } catch (e) {
      print('Error removing saved pet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove pet from saved list')),
        );
      }
    }
  }

  Future<void> _toggleSavePet(PetListing pet) async {
    // Same behavior as map: toggle saved
    try {
      final userId = _authService.currentUserId;
      final ref =
          FirebaseFirestore.instance.collection('saved_pets').doc('${userId}_${pet.id}');
      final snap = await ref.get();
      if (snap.exists) {
        await ref.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet removed from saved pets')),
          );
        }
        setState(() {
          _savedPets.removeWhere((p) => p.id == pet.id);
        });
      } else {
        await ref.set({
          'userId': userId,
          'petId': pet.id,
          'savedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet saved')),
          );
        }
      }
    } catch (_) {}
  }

  Future<bool> _isPetSaved(String petId) async {
    try {
      final userId = _authService.currentUserId;
      final snap = await FirebaseFirestore.instance
          .collection('saved_pets')
          .doc('${userId}_${petId}')
          .get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  Widget _buildPetCard(PetListing pet) {
    return Dismissible(
      key: Key(pet.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _removeSavedPet(pet);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                  child: const Icon(Icons.pets),
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
              Text('Type: ${pet.type}'),
              Text('Owner: ${pet.username}'),
              if (pet.address != null)
                Text(
                  pet.address!,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeSavedPet(pet),
            color: Colors.red,
          ),
          onTap: () async {
            if (!_authService.isLoggedIn) return;
            final isOwner = _authService.currentUserId == pet.userId;
            await PetDetailsSheet.show(
              context,
              pet,
              isOwner,
              _authService,
              (p) => _toggleSavePet(p),
              (id) => _isPetSaved(id),
              (p) async {
                // Only allow delete if owner; the sheet guards with isOwner
                try {
                  await FirebaseFirestore.instance.collection('pets').doc(p.id).delete();
                  final saved = await FirebaseFirestore.instance
                      .collection('saved_pets')
                      .where('petId', isEqualTo: p.id)
                      .get();
                  for (final d in saved.docs) {
                    await d.reference.delete();
                  }
                  if (mounted) {
                    setState(() {
                      _savedPets.removeWhere((sp) => sp.id == p.id);
                    });
                  }
                } catch (_) {}
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_authService.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Saved Pets',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Please log in to view your saved pets',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Navigate to login screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  ).then((result) {
                    if (result == true) {
                      _loadSavedPets();
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
                child: const Text(
                  'Log In',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Pets', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
      ),
      body: RefreshIndicator(
        onRefresh: _loadSavedPets,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _savedPets.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.bookmark_border,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No saved pets yet',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Save pets you\'re interested in to view them here',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
                : ListView.builder(
                  itemCount: _savedPets.length,
                  itemBuilder: (context, index) {
                    return _buildPetCard(_savedPets[index]);
                  },
                ),
      ),
    );
  }
}
