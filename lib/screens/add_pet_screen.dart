import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import 'dart:io';

class AddPetScreen extends StatefulWidget {
  final LatLng location;

  const AddPetScreen({super.key, required this.location});

  @override
  _AddPetScreenState createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String petType = 'Cat'; // Default pet type
  String breed =
      'Cat'; // Changed from 'Unknown/Mixed' to match default pet type
  String healthStatus = 'Healthy';
  String age = '';
  String description = '';
  bool _isSaving = false;
  bool _isUploading = false;
  String? _address;
  File? _selectedImage;
  // Multiple images support
  final List<String> _imageUrls = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Lists for dropdown menus
  final List<String> _petTypes = [
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

  // Map of breeds by pet type
  final Map<String, List<String>> _breedsByType = {
    'Cat': [
      'Unknown/Mixed',
      'Domestic Shorthair',
      'Domestic Longhair',
      'Persian',
      'Siamese',
      'Maine Coon',
      'British Shorthair',
      'Ragdoll',
      'Bengal',
      'Burmese',
    ],
    'Dog': [
      'Unknown/Mixed',
      'German Shepherd',
      'Golden Retriever',
      'Labrador Retriever',
      'Poodle',
      'Bulldog',
      'Shih Tzu',
      'Siberian Husky',
      'Pomeranian',
      'Pug',
      'Chihuahua',
      'Beagle',
      'Dachshund',
      'Rottweiler',
      'Boxer',
      'Malinois',
      'Pembroke Welsh Corgi',
    ],
    'Bird': [
      'Unknown/Mixed',
      'Budgerigar',
      'Cockatiel',
      'Parrot',
      'Canary',
      'Finch',
      'Lovebird',
      'Mynah',
    ],
    'Fish': [
      'Unknown/Mixed',
      'Goldfish',
      'Betta',
      'Guppy',
      'Tetra',
      'Angelfish',
      'Koi',
      'Arowana',
    ],
    'Rabbit': [
      'Unknown/Mixed',
      'Holland Lop',
      'Netherland Dwarf',
      'Mini Rex',
      'Angora',
      'Lionhead',
    ],
    'Hamster': [
      'Unknown/Mixed',
      'Syrian',
      'Dwarf Campbell',
      'Dwarf Winter White',
      'Roborovski',
      'Chinese',
    ],
    'Guinea Pig': [
      'Unknown/Mixed',
      'American',
      'Abyssinian',
      'Peruvian',
      'Silkie',
      'Teddy',
    ],
    'Turtle': [
      'Unknown/Mixed',
      'Red-Eared Slider',
      'Painted',
      'Box Turtle',
      'Map Turtle',
    ],
    'Other': ['Unknown/Mixed', 'Please specify in description'],
  };

  // Health status options
  final List<String> _healthStatuses = [
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
  final Set<String> _selectedHealthStatuses = {};
  final Map<String, String> _healthEmojis = const {
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

  // Search query for breed search
  String _breedSearchQuery = '';
  List<String> _filteredBreeds = [];

  @override
  void initState() {
    super.initState();
    _getAddressFromCoordinates();
    _filteredBreeds = _breedsByType[petType]!;
  }

  // Filter breeds based on search query
  void _filterBreeds(String query) {
    setState(() {
      _breedSearchQuery = query;
      if (query.isEmpty) {
        _filteredBreeds = _breedsByType[petType]!;
      } else {
        _filteredBreeds =
            _breedsByType[petType]!
                .where(
                  (breed) => breed.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      }
    });
  }

  // Function to get address from coordinates
  Future<void> _getAddressFromCoordinates() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.location.latitude,
        widget.location.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address =
              '${place.locality ?? ''}, ${place.administrativeArea ?? ''}';
        });
      }
    } catch (e) {
      print('Error getting address: $e');
    }
  }

  // Function to handle image selection and upload (supports multiple images)
  Future<void> _selectAndUploadImage() async {
    if (_imageUrls.length >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 5 images allowed')),
        );
      }
      return;
    }
    try {
      // Show loading indicator
      setState(() {
        _isUploading = true;
      });

      // Verify Cloudinary connection first
      final validationResults = await CloudinaryService.validateUploadPresets();
      if (!validationResults['cloudName']!) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cloudinary authentication failed. Please check your credentials.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          setState(() {
            _isUploading = false;
          });
        }
        return;
      }

      // Pick image(s) using our CloudinaryService with multi-select support
      final pickedResult = await CloudinaryService.showMultiImagePickerDialog(
        context,
        maxImages: 5,
        currentCount: _imageUrls.length,
      );

      // If no image was picked, return
      if (pickedResult == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // Handle the result - could be a single File or List<File>
      List<File> filesToUpload = [];
      if (pickedResult is File) {
        filesToUpload = [pickedResult];
      } else if (pickedResult is List<File>) {
        // Limit to remaining slots
        final remaining = 5 - _imageUrls.length;
        filesToUpload = pickedResult.take(remaining).toList();
      }

      if (filesToUpload.isEmpty) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // Show uploading message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Uploading ${filesToUpload.length} image${filesToUpload.length > 1 ? 's' : ''}...',
            ),
          ),
        );
      }

      // Upload all images with progress tracking
      final uploadedUrls = await CloudinaryService.uploadMultipleImages(
        filesToUpload,
        uploadType: UploadType.pet,
        onProgress: (uploaded, total) {
          if (mounted) {
            // Update progress in snackbar
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Uploading... $uploaded of $total'),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
      );

      // Add successfully uploaded URLs to the list
      if (uploadedUrls.isNotEmpty) {
        setState(() {
          _imageUrls.addAll(uploadedUrls);
          // Keep single imageUrl field as primary for backward compatibility
          imageUrl = _imageUrls.isNotEmpty ? _imageUrls.first : imageUrl;
          _isUploading = false;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${uploadedUrls.length} image${uploadedUrls.length > 1 ? 's' : ''} uploaded successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to upload images. Please check your internet connection and try again.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          setState(() {
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      print('Error in image upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _savePet() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSaving = true;
      });

      _formKey.currentState?.save();

      // Creating a new document for the pet
      try {
        // Get current user ID
        String? userId = _authService.currentUserId;

        if (userId == null) {
          throw Exception('User not logged in');
        }

        final petData = {
          'name': name,
          'petType': petType,
          'breed': breed,
          'age': int.tryParse(age) ?? 0,
          'healthStatus':
              _selectedHealthStatuses.isEmpty
                  ? 'Unknown'
                  : _selectedHealthStatuses.join(', '),
          'healthStatuses': _selectedHealthStatuses.toList(),
          'adoptionStatus': 'Pending Review',
          'imageUrl': _imageUrls.isNotEmpty ? _imageUrls.first : imageUrl,
          'images': _imageUrls,
          'address': _address ?? '',
          'description': description,
          'location': {
            'latitude': widget.location.latitude,
            'longitude': widget.location.longitude,
          },
          'userId': userId,
          'createdOn': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Adding the pet to Firestore
        await _firestore.collection('pets').add(petData);

        // After saving, show success popup and navigate back
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.pending_actions,
                          size: 48,
                          color: Colors.orange[700],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Pet Submitted!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your pet listing has been submitted for review. It will appear on the map once approved by an admin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Status: Pending Review',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Go back to previous screen
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Got it!'),
                      ),
                    ),
                  ],
                ),
          );
        }
      } catch (e) {
        print('Error saving pet: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save pet: ${e.toString()}')),
          );
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  // Show breed selection dialog with search functionality
  Future<void> _showBreedSelectionDialog() async {
    _breedSearchQuery = '';
    _filteredBreeds = _breedsByType[petType]!;

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Breed'),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _breedSearchQuery = value;
                          if (value.isEmpty) {
                            _filteredBreeds = _breedsByType[petType]!;
                          } else {
                            _filteredBreeds =
                                _breedsByType[petType]!
                                    .where(
                                      (breed) => breed.toLowerCase().contains(
                                        value.toLowerCase(),
                                      ),
                                    )
                                    .toList();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          _filteredBreeds.isEmpty
                              ? const Center(
                                child: Text('No matching breeds found'),
                              )
                              : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _filteredBreeds.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    title: Text(_filteredBreeds[index]),
                                    onTap: () {
                                      Navigator.of(
                                        context,
                                      ).pop(_filteredBreeds[index]);
                                    },
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        breed = result;
      });
    }
  }

  // Default placeholder image URL
  String imageUrl =
      'https://res.cloudinary.com/dhzjdkye9/image/upload/v1/pet_images/placeholder_pet.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Pet', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Display the selected location information
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        const Text(
                          'Selected Location',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _address ?? 'Loading address...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Pet images preview grid (max 5)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Photos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._imageUrls.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final url = entry.value;
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stack) => Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image),
                                      ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _imageUrls.removeAt(idx);
                                      imageUrl =
                                          _imageUrls.isNotEmpty
                                              ? _imageUrls.first
                                              : imageUrl;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        if (_imageUrls.length < 5)
                          InkWell(
                            onTap: _isUploading ? null : _selectAndUploadImage,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[100],
                              ),
                              child:
                                  _isUploading
                                      ? const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                      )
                                      : const Center(
                                        child: Icon(
                                          Icons.add_a_photo,
                                          color: Colors.deepPurple,
                                        ),
                                      ),
                            ),
                          ),
                      ],
                    ),
                    if (_imageUrls.isEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Add up to 5 photos. First photo will be used as cover.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Pet information form
                const SizedBox(height: 4),
                const Text(
                  'Pet Information',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Pet Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pets),
                  ),
                  validator:
                      (value) => value!.isEmpty ? 'Please enter a name' : null,
                  onSaved: (value) => name = value!,
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  minLines: 3,
                  maxLines: 6,
                  onSaved: (value) => description = value?.trim() ?? '',
                ),
                const SizedBox(height: 12),

                // Pet Type Dropdown
                DropdownButtonFormField<String>(
                  value: petType,
                  decoration: const InputDecoration(
                    labelText: 'Pet Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  validator:
                      (value) =>
                          value == null ? 'Please select a pet type' : null,
                  onChanged: (newValue) {
                    if (newValue != null && newValue != petType) {
                      setState(() {
                        petType = newValue;
                        breed =
                            newValue; // Set breed to pet type instead of 'Unknown/Mixed'
                      });
                    }
                  },
                  items:
                      _petTypes
                          .map(
                            (type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 12),

                // Breed Selection Button
                InkWell(
                  onTap: _showBreedSelectionDialog,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Breed',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pets_outlined),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(breed),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  validator:
                      (value) => value!.isEmpty ? 'Please enter age' : null,
                  keyboardType: TextInputType.number,
                  onSaved: (value) => age = value!,
                ),
                const SizedBox(height: 12),

                // Health Status (multi-select chips)
                const SizedBox(height: 4),
                const Text(
                  'Health Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                    children:
                        _healthStatuses.map((status) {
                          final selected = _selectedHealthStatuses.contains(
                            status,
                          );
                          final emoji = _healthEmojis[status] ?? '❇️';
                          return FilterChip(
                            label: Text('$emoji  $status'),
                            selected: selected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedHealthStatuses.add(status);
                                } else {
                                  _selectedHealthStatuses.remove(status);
                                }
                              });
                            },
                            selectedColor: Colors.deepPurple[50],
                            checkmarkColor: Colors.deepPurple,
                            side: BorderSide(
                              color:
                                  selected
                                      ? Colors.deepPurple
                                      : Colors.grey.shade300,
                            ),
                          );
                        }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _savePet,
                  icon:
                      _isSaving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Pet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
