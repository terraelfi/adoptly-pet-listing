import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../models/pet_listing.dart';
import '../../models/chat_room.dart';
import '../../models/chat_message.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../chat_screen.dart';
import '../user_profile_screen.dart';
import '../donation_screen.dart';

class PetDetailsSheet {
  static Future<void> show(
    BuildContext context,
    PetListing pet,
    bool isOwner,
    AuthService authService,
    Future<void> Function(PetListing) savePet,
    Future<bool> Function(String) isPetSaved,
    Future<void> Function(PetListing) deletePet, {
    bool readOnly = false,
  }) async {
    bool isSaved = false;
    if (!isOwner) {
      isSaved = await isPetSaved(pet.id);
    }

    // Interested users count (adoption requests)
    int interestedCount = 0;
    bool interestLoaded = false;

    // Load additional images (if any) and health status from Firestore
    List<String> images = [];
    List<String> healthStatuses = [];
    String? healthStatusStr;
    String? breed;
    String? ownerProfileImageUrl;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('pets').doc(pet.id).get();
      final data = doc.data();
      if (data != null && data['images'] is List) {
        images = (data['images'] as List).whereType<String>().toList();
      }
      if (data != null && data['healthStatuses'] is List) {
        healthStatuses =
            (data['healthStatuses'] as List).whereType<String>().toList();
      }
      if (data != null && data['healthStatus'] is String) {
        healthStatusStr = data['healthStatus'] as String;
      }
      if (data != null && data['breed'] is String) {
        breed = (data['breed'] as String).trim();
      }
    } catch (e) {
      // ignore errors; fall back to single image
    }

    // Load owner profile image
    try {
      final ownerDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(pet.userId)
              .get();
      if (ownerDoc.exists) {
        final ownerData = ownerDoc.data();
        if (ownerData != null && ownerData['profileImageUrl'] != null) {
          ownerProfileImageUrl = ownerData['profileImageUrl'] as String;
        }
      }
    } catch (e) {
      // ignore errors; will use default avatar
    }
    if (images.isEmpty && pet.imageUrl.isNotEmpty) {
      images = [pet.imageUrl];
    }

    int currentImageIndex = 0;

    // Keep root context for navigation after closing sheet
    final BuildContext rootContext = context;

    // Load other pets from the same owner
    List<PetListing> ownerOtherPets = [];
    bool otherPetsLoaded = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => DraggableScrollableSheet(
                  initialChildSize: 0.7,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  expand: false,
                  builder:
                      (context, scrollController) => Container(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Load interest count once
                              if (!interestLoaded)
                                () {
                                  interestLoaded = true;
                                  FirebaseFirestore.instance
                                      .collection('chatRooms')
                                      .where('petId', isEqualTo: pet.id)
                                      .where(
                                        'hasAdoptionRequest',
                                        isEqualTo: true,
                                      )
                                      .get()
                                      .then((snap) {
                                        setState(() {
                                          interestedCount = snap.docs.length;
                                        });
                                      })
                                      .catchError((_) {});
                                  return const SizedBox.shrink();
                                }(),
                              if (images.isNotEmpty) ...[
                                SizedBox(
                                  height: 220,
                                  width: double.infinity,
                                  child: Stack(
                                    children: [
                                      PageView.builder(
                                        itemCount: images.length,
                                        onPageChanged: (i) {
                                          setState(() {
                                            currentImageIndex = i;
                                          });
                                        },
                                        itemBuilder: (context, index) {
                                          final url = images[index];
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Image.network(
                                              url,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              errorBuilder:
                                                  (c, e, s) => Container(
                                                    color: Colors.grey[300],
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.broken_image,
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                      if (images.length > 1)
                                        Positioned(
                                          bottom: 8,
                                          left: 0,
                                          right: 0,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: List.generate(
                                              images.length,
                                              (i) => Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 3,
                                                    ),
                                                width:
                                                    currentImageIndex == i
                                                        ? 10
                                                        : 6,
                                                height:
                                                    currentImageIndex == i
                                                        ? 10
                                                        : 6,
                                                decoration: BoxDecoration(
                                                  color:
                                                      currentImageIndex == i
                                                          ? Colors.white
                                                          : Colors.white70,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.2),
                                                      blurRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              // Pet Header Section
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Pet Name
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                pet.name,
                                                style: const TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (isOwner && !readOnly)
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 24,
                                                ),
                                                onPressed: () => deletePet(pet),
                                                tooltip: 'Delete listing',
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Type and Breed Chips
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.deepPurple.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color:
                                                      Colors
                                                          .deepPurple
                                                          .shade200,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.category,
                                                    size: 14,
                                                    color:
                                                        Colors
                                                            .deepPurple
                                                            .shade700,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    pet.type,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors
                                                              .deepPurple
                                                              .shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (breed != null &&
                                                breed.isNotEmpty)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: Colors.blue.shade200,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.pets,
                                                      size: 14,
                                                      color:
                                                          Colors.blue.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      breed,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Colors
                                                                .blue
                                                                .shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if ((pet.adoptionStatus ?? '')
                                                    .toLowerCase() ==
                                                'adopted')
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color:
                                                        Colors.green.shade200,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.check_circle,
                                                      size: 14,
                                                      color:
                                                          Colors.green.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Adopted',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Colors
                                                                .green
                                                                .shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Interest Badge
                              if (interestedCount >= 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.favorite,
                                        size: 16,
                                        color: Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        interestedCount == 1
                                            ? '1 user interested in adopting'
                                            : '$interestedCount users interested in adopting',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (interestedCount >= 1)
                                const SizedBox(height: 16),
                              // Health Status Section
                              Builder(
                                builder: (context) {
                                  final List<String> statuses =
                                      healthStatuses.isNotEmpty
                                          ? healthStatuses
                                          : ((healthStatusStr ?? '')
                                              .split(',')
                                              .map((s) => s.trim())
                                              .where((s) => s.isNotEmpty)
                                              .toList());
                                  if (statuses.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  final Map<String, String> emojis = {
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
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.favorite,
                                              size: 16,
                                              color: Colors.green.shade700,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Health Status',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children:
                                              statuses
                                                  .map(
                                                    (s) => Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              Colors
                                                                  .green
                                                                  .shade300,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        '${emojis[s] ?? '❇️'} $s',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors
                                                                  .green
                                                                  .shade900,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              // Details Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Location
                                    if (pet.address != null) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 20,
                                            color: Colors.deepPurple.shade400,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Location',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  pet.address!,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (pet.description != null &&
                                          pet.description!.isNotEmpty)
                                        const Divider(height: 24),
                                    ],
                                    // Description
                                    if (pet.description != null &&
                                        pet.description!.isNotEmpty) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.article,
                                            size: 20,
                                            color: Colors.deepPurple.shade400,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'About',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  pet.description!,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Owner Section
                              GestureDetector(
                                onTap:
                                    isOwner
                                        ? null
                                        : () {
                                          Navigator.push(
                                            rootContext,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      UserProfileScreen(
                                                        userId: pet.userId,
                                                        username: pet.username,
                                                      ),
                                            ),
                                          );
                                        },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            Colors.deepPurple.shade100,
                                        backgroundImage:
                                            ownerProfileImageUrl != null
                                                ? NetworkImage(
                                                  ownerProfileImageUrl,
                                                )
                                                : null,
                                        child:
                                            ownerProfileImageUrl == null
                                                ? Icon(
                                                  Icons.person,
                                                  color:
                                                      Colors
                                                          .deepPurple
                                                          .shade700,
                                                  size: 20,
                                                )
                                                : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Posted by',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              pet.username,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isOwner)
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.grey.shade400,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (isOwner && !readOnly)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      // Close details sheet first
                                      Navigator.pop(context);
                                      try {
                                        // Prefill from Firestore (to include optional fields)
                                        final snap =
                                            await FirebaseFirestore.instance
                                                .collection('pets')
                                                .doc(pet.id)
                                                .get();
                                        final data = snap.data();

                                        String name = pet.name;
                                        String type = pet.type;
                                        String description =
                                            pet.description ??
                                            (data?['description'] ?? '');
                                        String adoptionStatus =
                                            (data?['adoptionStatus']
                                                as String?) ??
                                            'Available';
                                        final List<String>
                                        healthStatusesOptions = const [
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
                                        final Map<String, String> healthEmojis =
                                            const {
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
                                        final Set<String>
                                        selectedHealthStatuses = <String>{};
                                        if (data?['healthStatuses'] is List) {
                                          selectedHealthStatuses.addAll(
                                            (data?['healthStatuses'] as List)
                                                .whereType<String>(),
                                          );
                                        } else if ((data?['healthStatus']
                                                as String?) !=
                                            null) {
                                          selectedHealthStatuses.addAll(
                                            (data?['healthStatus'] as String)
                                                .split(',')
                                                .map((s) => s.trim())
                                                .where((s) => s.isNotEmpty),
                                          );
                                        }
                                        String breed =
                                            (data?['breed'] as String?) ?? '';
                                        String ageStr =
                                            (data?['age'] is num)
                                                ? (data?['age'] as num)
                                                    .toInt()
                                                    .toString()
                                                : '';

                                        final nameCtrl = TextEditingController(
                                          text: name,
                                        );
                                        final descCtrl = TextEditingController(
                                          text: description,
                                        );
                                        final breedCtrl = TextEditingController(
                                          text: breed,
                                        );
                                        final ageCtrl = TextEditingController(
                                          text: ageStr,
                                        );

                                        await showModalBottomSheet(
                                          context: rootContext,
                                          isScrollControlled: true,
                                          builder: (ctx) {
                                            return Padding(
                                              padding: EdgeInsets.only(
                                                bottom:
                                                    MediaQuery.of(
                                                      ctx,
                                                    ).viewInsets.bottom,
                                                left: 16,
                                                right: 16,
                                                top: 16,
                                              ),
                                              child: StatefulBuilder(
                                                builder: (ctx, setSheetState) {
                                                  return SingleChildScrollView(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: [
                                                        const Text(
                                                          'Edit Pet',
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        TextField(
                                                          controller: nameCtrl,
                                                          decoration:
                                                              const InputDecoration(
                                                                labelText:
                                                                    'Name',
                                                                border:
                                                                    OutlineInputBorder(),
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        DropdownButtonFormField<
                                                          String
                                                        >(
                                                          value:
                                                              type.isEmpty
                                                                  ? null
                                                                  : type,
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
                                                                    (
                                                                      e,
                                                                    ) => DropdownMenuItem(
                                                                      value: e,
                                                                      child:
                                                                          Text(
                                                                            e,
                                                                          ),
                                                                    ),
                                                                  )
                                                                  .toList(),
                                                          onChanged:
                                                              (v) =>
                                                                  setSheetState(
                                                                    () =>
                                                                        type =
                                                                            v ??
                                                                            type,
                                                                  ),
                                                          decoration:
                                                              const InputDecoration(
                                                                labelText:
                                                                    'Pet Type',
                                                                border:
                                                                    OutlineInputBorder(),
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        TextField(
                                                          controller: breedCtrl,
                                                          decoration:
                                                              const InputDecoration(
                                                                labelText:
                                                                    'Breed',
                                                                border:
                                                                    OutlineInputBorder(),
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        TextField(
                                                          controller: ageCtrl,
                                                          keyboardType:
                                                              TextInputType
                                                                  .number,
                                                          decoration:
                                                              const InputDecoration(
                                                                labelText:
                                                                    'Age',
                                                                border:
                                                                    OutlineInputBorder(),
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        DropdownButtonFormField<
                                                          String
                                                        >(
                                                          value:
                                                              adoptionStatus
                                                                      .isEmpty
                                                                  ? null
                                                                  : adoptionStatus,
                                                          items:
                                                              const [
                                                                    'Available',
                                                                    'Adopted',
                                                                    'Pending',
                                                                  ]
                                                                  .map(
                                                                    (
                                                                      e,
                                                                    ) => DropdownMenuItem(
                                                                      value: e,
                                                                      child:
                                                                          Text(
                                                                            e,
                                                                          ),
                                                                    ),
                                                                  )
                                                                  .toList(),
                                                          onChanged:
                                                              (
                                                                v,
                                                              ) => setSheetState(
                                                                () =>
                                                                    adoptionStatus =
                                                                        v ??
                                                                        adoptionStatus,
                                                              ),
                                                          decoration: const InputDecoration(
                                                            labelText:
                                                                'Adoption Status',
                                                            border:
                                                                OutlineInputBorder(),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        const Text(
                                                          'Health Status',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 8,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            border: Border.all(
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Wrap(
                                                            spacing: 8,
                                                            runSpacing: 4,
                                                            children:
                                                                healthStatusesOptions.map((
                                                                  status,
                                                                ) {
                                                                  final bool
                                                                  isSelected =
                                                                      selectedHealthStatuses
                                                                          .contains(
                                                                            status,
                                                                          );
                                                                  final emoji =
                                                                      healthEmojis[status] ??
                                                                      '❇️';
                                                                  return FilterChip(
                                                                    label: Text(
                                                                      '$emoji  $status',
                                                                    ),
                                                                    selected:
                                                                        isSelected,
                                                                    onSelected: (
                                                                      val,
                                                                    ) {
                                                                      setSheetState(() {
                                                                        if (val) {
                                                                          selectedHealthStatuses.add(
                                                                            status,
                                                                          );
                                                                        } else {
                                                                          selectedHealthStatuses.remove(
                                                                            status,
                                                                          );
                                                                        }
                                                                      });
                                                                    },
                                                                    selectedColor:
                                                                        Colors
                                                                            .deepPurple[50],
                                                                    checkmarkColor:
                                                                        Colors
                                                                            .deepPurple,
                                                                    side: BorderSide(
                                                                      color:
                                                                          isSelected
                                                                              ? Colors.deepPurple
                                                                              : Colors.grey.shade300,
                                                                    ),
                                                                  );
                                                                }).toList(),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        TextField(
                                                          controller: descCtrl,
                                                          minLines: 3,
                                                          maxLines: 6,
                                                          decoration:
                                                              const InputDecoration(
                                                                labelText:
                                                                    'Description',
                                                                border:
                                                                    OutlineInputBorder(),
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 16,
                                                        ),
                                                        ElevatedButton.icon(
                                                          onPressed: () async {
                                                            try {
                                                              final update = <
                                                                String,
                                                                dynamic
                                                              >{
                                                                'name':
                                                                    nameCtrl
                                                                        .text
                                                                        .trim(),
                                                                'petType': type,
                                                                'breed':
                                                                    breedCtrl
                                                                        .text
                                                                        .trim(),
                                                                'age':
                                                                    int.tryParse(
                                                                      ageCtrl
                                                                          .text
                                                                          .trim(),
                                                                    ) ??
                                                                    0,
                                                                'adoptionStatus':
                                                                    adoptionStatus,
                                                                'healthStatus':
                                                                    selectedHealthStatuses
                                                                            .isEmpty
                                                                        ? 'Unknown'
                                                                        : selectedHealthStatuses
                                                                            .join(
                                                                              ', ',
                                                                            ),
                                                                'healthStatuses':
                                                                    selectedHealthStatuses
                                                                        .toList(),
                                                                'description':
                                                                    descCtrl
                                                                        .text
                                                                        .trim(),
                                                                'updatedAt':
                                                                    FieldValue.serverTimestamp(),
                                                              };

                                                              await FirebaseFirestore
                                                                  .instance
                                                                  .collection(
                                                                    'pets',
                                                                  )
                                                                  .doc(pet.id)
                                                                  .set(
                                                                    update,
                                                                    SetOptions(
                                                                      merge:
                                                                          true,
                                                                    ),
                                                                  );

                                                              Navigator.pop(
                                                                ctx,
                                                              ); // close sheet
                                                              ScaffoldMessenger.of(
                                                                rootContext,
                                                              ).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    'Pet updated',
                                                                  ),
                                                                ),
                                                              );
                                                            } catch (e) {
                                                              ScaffoldMessenger.of(
                                                                rootContext,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    'Update failed: $e',
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          },
                                                          icon: const Icon(
                                                            Icons.save,
                                                          ),
                                                          label: const Text(
                                                            'Save Changes',
                                                          ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .deepPurple,
                                                            foregroundColor:
                                                                Colors.white,
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  vertical: 12,
                                                                ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          rootContext,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to open editor: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit Pet'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                )
                              else if (!readOnly &&
                                  (pet.adoptionStatus ?? '').toLowerCase() !=
                                      'adopted')
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      await savePet(pet);
                                      setState(() {
                                        isSaved = !isSaved;
                                      });
                                    },
                                    icon: Icon(
                                      isSaved
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                    ),
                                    label: Text(isSaved ? 'Saved' : 'Save Pet'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          isSaved ? Colors.grey : Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!readOnly &&
                                  !isOwner &&
                                  (pet.adoptionStatus ?? '').toLowerCase() !=
                                      'adopted') ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      // Start chat and send adoption request
                                      try {
                                        final currentUser =
                                            await authService.getUserData();
                                        if (currentUser == null) return;

                                        final chatService = ChatService();
                                        final participantIds = [
                                          authService.currentUserId!,
                                          pet.userId,
                                        ]..sort();

                                        // Create or get chat room
                                        final chatRoom = ChatRoom(
                                          id: '',
                                          participantIds: participantIds,
                                          participants: {
                                            authService.currentUserId!: {
                                              'id': authService.currentUserId!,
                                              'username':
                                                  currentUser['username'] ??
                                                  'User',
                                            },
                                            pet.userId: {
                                              'id': pet.userId,
                                              'username': pet.username,
                                            },
                                          },
                                          participantNames: {
                                            authService.currentUserId!:
                                                currentUser['username'] ??
                                                'User',
                                            pet.userId: pet.username,
                                          },
                                          participantAvatars: {},
                                          lastMessageTime: Timestamp.now(),
                                          lastMessageContent:
                                              'Adoption request',
                                          petId: pet.id,
                                          petName: pet.name,
                                          petImageUrl: pet.imageUrl,
                                        );
                                        final chatRoomId = await chatService
                                            .createChatRoom(chatRoom);

                                        // Send a special adoption request message
                                        await chatService.sendMessage(
                                          ChatMessage(
                                            id: '',
                                            chatRoomId: chatRoomId,
                                            senderId:
                                                authService.currentUserId!,
                                            senderName:
                                                currentUser['username'] ??
                                                'User',
                                            senderAvatar:
                                                currentUser['profileImageUrl'],
                                            content:
                                                '[ADOPTION_REQUEST] Request to adopt ${pet.name}',
                                            timestamp: Timestamp.now(),
                                            isRead: false,
                                          ),
                                        );
                                        // Mark the chat room as having an adoption request for counting
                                        await FirebaseFirestore.instance
                                            .collection('chatRooms')
                                            .doc(chatRoomId)
                                            .set({
                                              'hasAdoptionRequest': true,
                                            }, SetOptions(merge: true));

                                        // Navigate to chat using the root context (still mounted)
                                        Navigator.push(
                                          rootContext,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => ChatScreen(
                                                  chatRoomId: chatRoomId,
                                                  otherUserId: pet.userId,
                                                  otherUserName: pet.username,
                                                  petId: pet.id,
                                                  petName: pet.name,
                                                  petImageUrl: pet.imageUrl,
                                                ),
                                          ),
                                        );
                                      } catch (_) {}
                                    },
                                    icon: const Icon(Icons.favorite),
                                    label: const Text('Adopt'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              // Other pets from this owner section
                              if (!otherPetsLoaded)
                                () {
                                  otherPetsLoaded = true;
                                  FirebaseFirestore.instance
                                      .collection('pets')
                                      .where('userId', isEqualTo: pet.userId)
                                      .limit(10)
                                      .get()
                                      .then((snap) {
                                        final pets = <PetListing>[];
                                        for (var doc in snap.docs) {
                                          // Skip the current pet
                                          if (doc.id == pet.id) continue;

                                          try {
                                            final data = doc.data();
                                            final location = data['location'];

                                            if (location == null) continue;
                                            
                                            // Skip pets that are pending review (not yet approved)
                                            final adoptionStatus = data['adoptionStatus'] as String?;
                                            if (adoptionStatus == 'Pending Review') continue;

                                            pets.add(
                                              PetListing(
                                                id: doc.id,
                                                name: data['name'] ?? 'Unknown',
                                                type:
                                                    data['petType'] ??
                                                    'Unknown',
                                                username: pet.username,
                                                imageUrl:
                                                    data['imageUrl'] ?? '',
                                                location: LatLng(
                                                  location['latitude'],
                                                  location['longitude'],
                                                ),
                                                userId: pet.userId,
                                                address:
                                                    data['address'] as String?,
                                                description:
                                                    data['description']
                                                        as String?,
                                                adoptionStatus:
                                                    data['adoptionStatus']
                                                        as String?,
                                                adoptedAt:
                                                    (data['adoptedAt']
                                                            is Timestamp)
                                                        ? (data['adoptedAt']
                                                                as Timestamp)
                                                            .toDate()
                                                        : null,
                                              ),
                                            );
                                          } catch (e) {
                                            // Skip pets with invalid data
                                            continue;
                                          }
                                        }
                                        setState(() {
                                          ownerOtherPets = pets;
                                        });
                                      })
                                      .catchError((_) {});
                                  return const SizedBox.shrink();
                                }(),
                              if (ownerOtherPets.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text(
                                  'More from ${pet.username}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 210,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: ownerOtherPets.length,
                                    itemBuilder: (context, index) {
                                      final otherPet = ownerOtherPets[index];
                                      return GestureDetector(
                                        onTap: () {
                                          // Close current sheet and open new one
                                          Navigator.pop(context);
                                          // Small delay to allow sheet to close smoothly
                                          Future.delayed(
                                            const Duration(milliseconds: 300),
                                            () {
                                              show(
                                                rootContext,
                                                otherPet,
                                                false,
                                                authService,
                                                savePet,
                                                isPetSaved,
                                                deletePet,
                                                readOnly: readOnly,
                                              );
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: 170,
                                          margin: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.06,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Pet Image
                                              ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      topLeft: Radius.circular(
                                                        12,
                                                      ),
                                                      topRight: Radius.circular(
                                                        12,
                                                      ),
                                                    ),
                                                child:
                                                    otherPet.imageUrl.isNotEmpty
                                                        ? Image.network(
                                                          otherPet.imageUrl,
                                                          height: 120,
                                                          width:
                                                              double.infinity,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                c,
                                                                e,
                                                                s,
                                                              ) => Container(
                                                                height: 120,
                                                                color:
                                                                    Colors
                                                                        .grey[300],
                                                                child: const Center(
                                                                  child: Icon(
                                                                    Icons.pets,
                                                                    size: 40,
                                                                    color:
                                                                        Colors
                                                                            .grey,
                                                                  ),
                                                                ),
                                                              ),
                                                        )
                                                        : Container(
                                                          height: 120,
                                                          color:
                                                              Colors.grey[300],
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons.pets,
                                                              size: 40,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                        ),
                                              ),
                                              // Pet Details
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      otherPet.name,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.category,
                                                          size: 13,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            otherPet.type,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors
                                                                      .grey[600],
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if ((otherPet.adoptionStatus ??
                                                                '')
                                                            .toLowerCase() ==
                                                        'adopted')
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 3,
                                                            ),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .check_circle,
                                                              size: 12,
                                                              color:
                                                                  Colors
                                                                      .green[600],
                                                            ),
                                                            const SizedBox(
                                                              width: 3,
                                                            ),
                                                            Text(
                                                              'Adopted',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color:
                                                                    Colors
                                                                        .green[600],
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              // Donation Banner
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context); // Close pet details
                                  Navigator.push(
                                    rootContext,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const DonationScreen(),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.deepPurple.withOpacity(
                                            0.3,
                                          ),
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
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                ),
          ),
    );
  }
}
