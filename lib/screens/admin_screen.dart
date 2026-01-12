import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/pet_listing.dart';
import 'map/pet_details_sheet.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import 'package:firebase_storage/firebase_storage.dart' as fstorage;

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Admin Page',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.deepPurple,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              const Tab(text: 'Users'),
              const Tab(text: 'Pets'),
              // Pending Review tab with badge
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('pets')
                        .where('adoptionStatus', isEqualTo: 'Pending Review')
                        .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Review'),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              count > 99 ? '99+' : count.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_UsersTab(), _PetsTab(), _PendingReviewTab()],
        ),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  bool _isBusy = false;

  Future<void> _editUserDialog(String userId, Map<String, dynamic> data) async {
    final nameCtrl = TextEditingController(
      text: (data['username'] ?? '') as String,
    );
    final emailCtrl = TextEditingController(
      text: (data['email'] ?? '') as String,
    );
    final avatarCtrl = TextEditingController(
      text: (data['profileImageUrl'] ?? '') as String,
    );

    await showModalBottomSheet(
      context: context,
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
                      'Edit User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed:
                          _isBusy
                              ? null
                              : () async {
                                final confirm =
                                    await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (ctx) => AlertDialog(
                                            title: const Text('Update User'),
                                            content: const Text(
                                              'Are you sure you want to update this user\'s details?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      false,
                                                    ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      true,
                                                    ),
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.deepPurple,
                                                ),
                                                child: const Text('Update'),
                                              ),
                                            ],
                                          ),
                                    ) ??
                                    false;
                                if (!confirm) return;
                                try {
                                  setState(() => _isBusy = true);
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(userId)
                                      .set({
                                        'username': nameCtrl.text.trim(),
                                        'email': emailCtrl.text.trim(),
                                        'profileImageUrl':
                                            avatarCtrl.text.trim(),
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      }, SetOptions(merge: true));
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('User updated'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Update failed: $e'),
                                    ),
                                  );
                                } finally {
                                  if (mounted) setState(() => _isBusy = false);
                                }
                              },
                      icon: const Icon(Icons.save),
                      label: const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
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

  Future<void> _deleteUser(String userId, Map<String, dynamic> data) async {
    final username = (data['username'] ?? 'this user') as String;
    final confirm =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Delete User'),
                content: Text(
                  'Are you sure you want to delete $username from the Database?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!confirm) return;
    try {
      setState(() => _isBusy = true);
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted from Firestore')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '—';
    try {
      final dt = ts.toDate();
      return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
    } catch (_) {
      return '—';
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data?.docs ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = users[index];
            final data = doc.data();
            final username = (data['username'] ?? 'Unknown') as String;
            final email = (data['email'] ?? '') as String;
            final createdAt = data['createdAt'] as Timestamp?;
            final profileImageUrl = (data['profileImageUrl'] ?? '') as String;

            return ExpansionTile(
              leading:
                  (profileImageUrl.isNotEmpty)
                      ? CircleAvatar(
                        backgroundImage: NetworkImage(profileImageUrl),
                      )
                      : const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(email),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                _isBusy
                                    ? null
                                    : () => _editUserDialog(doc.id, data),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Update'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed:
                                _isBusy
                                    ? null
                                    : () => _deleteUser(doc.id, data),
                            icon: const Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 6),
                          Text('Created: ${_formatTimestamp(createdAt)}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.login, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Last sign-in: ${_formatTimestamp(data['lastSignInAt'] as Timestamp?)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _UserPetsList(userId: doc.id, ownerName: username),
                      const SizedBox(height: 8),
                      _UserAdoptedList(userId: doc.id),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _UserPetsList extends StatefulWidget {
  final String userId;
  final String ownerName;
  const _UserPetsList({required this.userId, required this.ownerName});

  @override
  State<_UserPetsList> createState() => _UserPetsListState();
}

class _UserPetsListState extends State<_UserPetsList> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('pets')
              .where('userId', isEqualTo: widget.userId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        final pets = snapshot.data?.docs ?? [];
        if (pets.isEmpty) {
          return const Text('No pets added by this user');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pets (${pets.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...pets.map((p) {
              final d = p.data();
              final name = (d['name'] ?? 'Unknown') as String;
              final type = (d['petType'] ?? 'Unknown') as String;
              final status = (d['adoptionStatus'] ?? '—') as String;
              final imgUrl = (d['imageUrl'] ?? '') as String;
              final address = (d['address'] ?? '') as String;
              LatLng loc;
              if (d['location'] is Map<String, dynamic>) {
                final m = d['location'] as Map<String, dynamic>;
                final lat = (m['latitude'] as num?)?.toDouble() ?? 0.0;
                final lng = (m['longitude'] as num?)?.toDouble() ?? 0.0;
                loc = LatLng(lat, lng);
              } else {
                loc = LatLng(0.0, 0.0);
              }
              final pet = PetListing(
                id: p.id,
                name: name,
                type: type,
                username: widget.ownerName,
                imageUrl: imgUrl,
                location: loc,
                userId: widget.userId,
                address: address,
                description: d['description'] as String?,
                adoptionStatus: d['adoptionStatus'] as String?,
                adoptedAt:
                    d['adoptedAt'] is Timestamp
                        ? (d['adoptedAt'] as Timestamp).toDate()
                        : null,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.pets, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final auth = AuthService();
                          final isOwner = auth.currentUserId == widget.userId;
                          await PetDetailsSheet.show(
                            context,
                            pet,
                            isOwner,
                            auth,
                            (p) async {},
                            (id) async => false,
                            (p) async {},
                            readOnly: true,
                          );
                        },
                        child: Text('$name • $type • $status'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete pet',
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm =
                            await showDialog<bool>(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: const Text('Delete Pet'),
                                    content: Text(
                                      'Delete "$name"? This removes the image from Cloudinary (if applicable) and Firestore.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                            ) ??
                            false;
                        if (!confirm) return;
                        try {
                          // Gather image URLs: primary + images list
                          final List<String> imageUrls = [];
                          if (imgUrl.isNotEmpty) imageUrls.add(imgUrl);
                          if (d['images'] is List) {
                            imageUrls.addAll(
                              (d['images'] as List).whereType<String>(),
                            );
                          }
                          // Delete Cloudinary images when applicable
                          for (final url in imageUrls) {
                            if (url.contains('res.cloudinary.com')) {
                              await CloudinaryService.deleteImageByUrl(url);
                            } else if (url.contains(
                              'firebasestorage.googleapis.com',
                            )) {
                              try {
                                await fstorage.FirebaseStorage.instance
                                    .refFromURL(url)
                                    .delete();
                              } catch (_) {}
                            }
                          }
                          // Delete Firestore pet
                          await FirebaseFirestore.instance
                              .collection('pets')
                              .doc(p.id)
                              .delete();
                          // Delete saved_pets references
                          final saved =
                              await FirebaseFirestore.instance
                                  .collection('saved_pets')
                                  .where('petId', isEqualTo: p.id)
                                  .get();
                          for (final doc in saved.docs) {
                            await doc.reference.delete();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pet deleted')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delete failed: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _UserAdoptedList extends StatefulWidget {
  final String userId;
  const _UserAdoptedList({required this.userId});

  @override
  State<_UserAdoptedList> createState() => _UserAdoptedListState();
}

class _UserAdoptedListState extends State<_UserAdoptedList> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('pets')
              .where('adoptedByUserId', isEqualTo: widget.userId)
              .where('adoptionStatus', isEqualTo: 'Adopted')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        final pets = snapshot.data?.docs ?? [];
        if (pets.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adopted Pets (${pets.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...pets.map((p) {
              final d = p.data();
              final name = (d['name'] ?? 'Unknown') as String;
              final type = (d['petType'] ?? 'Unknown') as String;
              final adoptedAtTs = d['adoptedAt'];
              String adoptedOn = '—';
              if (adoptedAtTs is Timestamp) {
                final dt = adoptedAtTs.toDate();
                adoptedOn =
                    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
              }
              // Build clickable row to open details read-only
              final imgUrl = (d['imageUrl'] ?? '') as String;
              final address = (d['address'] ?? '') as String;
              LatLng loc;
              if (d['location'] is Map<String, dynamic>) {
                final m = d['location'] as Map<String, dynamic>;
                final lat = (m['latitude'] as num?)?.toDouble() ?? 0.0;
                final lng = (m['longitude'] as num?)?.toDouble() ?? 0.0;
                loc = LatLng(lat, lng);
              } else {
                loc = LatLng(0.0, 0.0);
              }
              final ownerId = (d['userId'] ?? '') as String;
              final ownerName =
                  (d['username'] ?? 'Owner') as String; // best-effort
              final pet = PetListing(
                id: p.id,
                name: name,
                type: type,
                username: ownerName,
                imageUrl: imgUrl,
                location: loc,
                userId: ownerId,
                address: address,
                description: d['description'] as String?,
                adoptionStatus: d['adoptionStatus'] as String?,
                adoptedAt:
                    adoptedAtTs is Timestamp ? adoptedAtTs.toDate() : null,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final auth = AuthService();
                          await PetDetailsSheet.show(
                            context,
                            pet,
                            false,
                            auth,
                            (p) async {},
                            (id) async => false,
                            (p) async {},
                            readOnly: true,
                          );
                        },
                        child: Text('$name • $type • adopted $adoptedOn'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete adopted pet',
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm =
                            await showDialog<bool>(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: const Text('Delete Adopted Pet'),
                                    content: Text(
                                      'Delete "$name"? This removes the image from Cloudinary (if applicable) and Firestore.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                            ) ??
                            false;
                        if (!confirm) return;
                        try {
                          final List<String> imageUrls = [];
                          final imgUrl = (d['imageUrl'] ?? '') as String;
                          if (imgUrl.isNotEmpty) imageUrls.add(imgUrl);
                          if (d['images'] is List) {
                            imageUrls.addAll(
                              (d['images'] as List).whereType<String>(),
                            );
                          }
                          for (final url in imageUrls) {
                            if (url.contains('res.cloudinary.com')) {
                              await CloudinaryService.deleteImageByUrl(url);
                            } else if (url.contains(
                              'firebasestorage.googleapis.com',
                            )) {
                              try {
                                await fstorage.FirebaseStorage.instance
                                    .refFromURL(url)
                                    .delete();
                              } catch (_) {}
                            }
                          }
                          await FirebaseFirestore.instance
                              .collection('pets')
                              .doc(p.id)
                              .delete();
                          final saved =
                              await FirebaseFirestore.instance
                                  .collection('saved_pets')
                                  .where('petId', isEqualTo: p.id)
                                  .get();
                          for (final doc in saved.docs) {
                            await doc.reference.delete();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pet deleted')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delete failed: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _PetsTab extends StatefulWidget {
  const _PetsTab();

  @override
  State<_PetsTab> createState() => _PetsTabState();
}

class _PetsTabState extends State<_PetsTab> {
  String? _typeFilter;
  String? _adoptionFilter;
  String _search = '';
  final AuthService _auth = AuthService();
  final Map<String, String> _ownerNameCache = {};

  Future<String> _getOwnerName(String userId) async {
    if (userId.isEmpty) return 'Owner';
    if (_ownerNameCache.containsKey(userId)) return _ownerNameCache[userId]!;
    try {
      final name = await AuthService().getUsernameById(userId);
      _ownerNameCache[userId] = name;
      return name;
    } catch (_) {
      return 'Owner';
    }
  }

  final List<String> _petTypes = const [
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

  final List<String> _adoptionStatuses = const [
    'Available',
    'Adopted',
    'Pending Review',
  ];

  Future<void> _deletePet(String petId) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Delete Pet'),
                content: const Text(
                  'Are you sure you want to delete this pet?',
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

    try {
      await FirebaseFirestore.instance.collection('pets').doc(petId).delete();

      final saved =
          await FirebaseFirestore.instance
              .collection('saved_pets')
              .where('petId', isEqualTo: petId)
              .get();
      for (final doc in saved.docs) {
        await doc.reference.delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pet deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search Pets',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged:
                      (v) => setState(() => _search = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _typeFilter,
                hint: const Text('Type'),
                items:
                    <String?>[null, ..._petTypes]
                        .map(
                          (e) => DropdownMenuItem<String?>(
                            value: e,
                            child: Text(e ?? 'All'),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _typeFilter = v),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _adoptionFilter,
                hint: const Text('Status'),
                items:
                    <String?>[null, ..._adoptionStatuses]
                        .map(
                          (e) => DropdownMenuItem<String?>(
                            value: e,
                            child: Text(e ?? 'All'),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _adoptionFilter = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('pets').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final docs = snapshot.data?.docs ?? [];

              // Sort by createdAt desc when available; include docs without createdAt
              final sorted =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
              sorted.sort((a, b) {
                final va = a.data()['createdAt'];
                final vb = b.data()['createdAt'];
                if (va is Timestamp && vb is Timestamp) {
                  return vb.compareTo(va);
                }
                if (va is Timestamp)
                  return -1; // a has ts, b doesn't -> a first
                if (vb is Timestamp) return 1; // b has ts, a doesn't -> b first
                return 0;
              });

              final filtered =
                  sorted.where((d) {
                    final data = d.data();
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final breed =
                        (data['breed'] ?? '').toString().toLowerCase();
                    final type = data['petType']?.toString();
                    final status = data['adoptionStatus']?.toString();
                    final matchSearch =
                        _search.isEmpty ||
                        name.contains(_search) ||
                        breed.contains(_search);
                    final matchType =
                        _typeFilter == null || type == _typeFilter;
                    final matchStatus =
                        _adoptionFilter == null || status == _adoptionFilter;
                    return matchSearch && matchType && matchStatus;
                  }).toList();

              final total = docs.length;
              final available =
                  docs
                      .where((d) => d.data()['adoptionStatus'] == 'Available')
                      .length;

              if (docs.isEmpty) {
                return const Center(child: Text('No pets found'));
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Chip(label: Text('Total: $total')),
                        const SizedBox(width: 8),
                        Chip(label: Text('Available: $available')),
                        const Spacer(),
                        Chip(label: Text('Shown: ${filtered.length}')),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data();
                        final name = (data['name'] ?? 'Unknown') as String;
                        final type = (data['petType'] ?? 'Unknown') as String;
                        final status =
                            (data['adoptionStatus'] ?? '—') as String;
                        final breed = (data['breed'] ?? '—') as String;
                        final String? address = (data['address'] as String?);
                        final ownerId = (data['userId'] ?? '') as String;
                        final Map<String, dynamic>? loc =
                            data['location'] is Map<String, dynamic>
                                ? (data['location'] as Map<String, dynamic>)
                                : null;
                        final double? lat =
                            loc?['latitude'] is num
                                ? (loc!['latitude'] as num).toDouble()
                                : null;
                        final double? lng =
                            loc?['longitude'] is num
                                ? (loc!['longitude'] as num).toDouble()
                                : null;
                        final String addressLine =
                            (address != null && address.isNotEmpty)
                                ? address
                                : (lat != null && lng != null
                                    ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                                    : 'No address');

                        return FutureBuilder<String>(
                          future: _getOwnerName(ownerId),
                          builder: (context, snap) {
                            final ownerName = snap.data ?? 'Owner';
                            return ListTile(
                              leading: _PetThumbnail(data: data),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$type • $breed • $status'),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Owner: $ownerName',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          addressLine,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deletePet(doc.id),
                                tooltip: 'Delete',
                              ),
                              onTap: () async {
                                // Build PetListing and open details sheet (readOnly)
                                final pet = PetListing(
                                  id: doc.id,
                                  name: name,
                                  type: type,
                                  username: ownerName,
                                  imageUrl: (data['imageUrl'] ?? '') as String,
                                  location:
                                      (lat != null && lng != null)
                                          ? LatLng(lat, lng)
                                          : LatLng(0.0, 0.0),
                                  userId: ownerId,
                                  address: address,
                                  description: data['description'] as String?,
                                  adoptionStatus:
                                      data['adoptionStatus'] as String?,
                                  adoptedAt:
                                      data['adoptedAt'] is Timestamp
                                          ? (data['adoptedAt'] as Timestamp)
                                              .toDate()
                                          : null,
                                );
                                await PetDetailsSheet.show(
                                  context,
                                  pet,
                                  false,
                                  _auth,
                                  (p) async {},
                                  (id) async => false,
                                  (p) async {},
                                  readOnly: true,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PetThumbnail extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PetThumbnail({required this.data});

  @override
  Widget build(BuildContext context) {
    final dynamic imagesField = data['images'];
    final String singleImage = (data['imageUrl'] ?? '').toString();

    // Determine primary image and count
    String? primaryUrl;
    int extraCount = 0;

    if (imagesField is List) {
      final urls = imagesField.whereType<String>().toList();
      if (urls.isNotEmpty) {
        primaryUrl = urls.first;
        extraCount = urls.length - 1;
      }
    }

    // Fallback to single imageUrl field
    primaryUrl ??= singleImage.isNotEmpty ? singleImage : null;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child:
                primaryUrl != null
                    ? Image.network(
                      primaryUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.pets,
                              size: 24,
                              color: Colors.grey,
                            ),
                          ),
                    )
                    : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.pets,
                        size: 24,
                        color: Colors.grey,
                      ),
                    ),
          ),
          if (extraCount > 0)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$extraCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// New tab for reviewing pending pet submissions
class _PendingReviewTab extends StatefulWidget {
  const _PendingReviewTab();

  @override
  State<_PendingReviewTab> createState() => _PendingReviewTabState();
}

class _PendingReviewTabState extends State<_PendingReviewTab> {
  final AuthService _auth = AuthService();
  final Map<String, String> _ownerNameCache = {};

  Future<String> _getOwnerName(String userId) async {
    if (userId.isEmpty) return 'Owner';
    if (_ownerNameCache.containsKey(userId)) return _ownerNameCache[userId]!;
    try {
      final name = await AuthService().getUsernameById(userId);
      _ownerNameCache[userId] = name;
      return name;
    } catch (_) {
      return 'Owner';
    }
  }

  Future<void> _approvePet(String petId) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Approve Pet'),
                content: const Text(
                  'Are you sure you want to approve this pet listing? It will become visible on the map.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                    child: const Text('Approve'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('pets').doc(petId).update({
        'adoptionStatus': 'Available',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUserId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pet approved and now visible on the map'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Approval failed: $e')));
    }
  }

  Future<void> _rejectPet(String petId, String petName) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Reject Pet'),
                content: Text(
                  'Are you sure you want to reject "$petName"? This will permanently delete the listing.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Reject & Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirm) return;

    try {
      // Get pet data for image cleanup
      final petDoc =
          await FirebaseFirestore.instance.collection('pets').doc(petId).get();

      if (petDoc.exists) {
        final data = petDoc.data()!;
        final List<String> imageUrls = [];
        final imgUrl = (data['imageUrl'] ?? '') as String;
        if (imgUrl.isNotEmpty) imageUrls.add(imgUrl);
        if (data['images'] is List) {
          imageUrls.addAll((data['images'] as List).whereType<String>());
        }

        // Delete Cloudinary images
        for (final url in imageUrls) {
          if (url.contains('res.cloudinary.com')) {
            await CloudinaryService.deleteImageByUrl(url);
          } else if (url.contains('firebasestorage.googleapis.com')) {
            try {
              await fstorage.FirebaseStorage.instance.refFromURL(url).delete();
            } catch (_) {}
          }
        }
      }

      // Delete the pet document
      await FirebaseFirestore.instance.collection('pets').doc(petId).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pet listing rejected and deleted'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rejection failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('pets')
              .where('adoptionStatus', isEqualTo: 'Pending Review')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final pendingPets = snapshot.data?.docs ?? [];

        if (pendingPets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green[300],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No pending reviews',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'All pet listings have been reviewed',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.orange[50],
              child: Row(
                children: [
                  const Icon(Icons.pending_actions, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    '${pendingPets.length} pet(s) awaiting review',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: pendingPets.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = pendingPets[index];
                  final data = doc.data();
                  final name = (data['name'] ?? 'Unknown') as String;
                  final type = (data['petType'] ?? 'Unknown') as String;
                  final breed = (data['breed'] ?? '—') as String;
                  final description = (data['description'] ?? '') as String;
                  final ownerId = (data['userId'] ?? '') as String;
                  final createdAt = data['createdAt'] as Timestamp?;
                  final address = (data['address'] ?? '') as String;
                  final imgUrl = (data['imageUrl'] ?? '') as String;

                  // Build location
                  LatLng loc;
                  if (data['location'] is Map<String, dynamic>) {
                    final m = data['location'] as Map<String, dynamic>;
                    final lat = (m['latitude'] as num?)?.toDouble() ?? 0.0;
                    final lng = (m['longitude'] as num?)?.toDouble() ?? 0.0;
                    loc = LatLng(lat, lng);
                  } else {
                    loc = LatLng(0.0, 0.0);
                  }

                  return FutureBuilder<String>(
                    future: _getOwnerName(ownerId),
                    builder: (context, snap) {
                      final ownerName = snap.data ?? 'Loading...';

                      // Build PetListing for details sheet
                      final pet = PetListing(
                        id: doc.id,
                        name: name,
                        type: type,
                        username: ownerName,
                        imageUrl: imgUrl,
                        location: loc,
                        userId: ownerId,
                        address: address,
                        description: description,
                        adoptionStatus: data['adoptionStatus'] as String?,
                        adoptedAt:
                            data['adoptedAt'] is Timestamp
                                ? (data['adoptedAt'] as Timestamp).toDate()
                                : null,
                      );

                      return ExpansionTile(
                        leading: _PetThumbnail(data: data),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$type • $breed'),
                            Text(
                              'By: $ownerName',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // View Full Details Button
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await PetDetailsSheet.show(
                                        context,
                                        pet,
                                        false, // not owner
                                        _auth,
                                        (p) async {}, // no save
                                        (id) async => false, // not saved
                                        (p) async {}, // no delete from here
                                        readOnly: true,
                                      );
                                    },
                                    icon: const Icon(Icons.visibility),
                                    label: const Text('View Full Details'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.deepPurple,
                                      side: const BorderSide(
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (description.isNotEmpty) ...[
                                  const Text(
                                    'Description:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (address.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(address)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (createdAt != null) ...[
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Submitted: ${_formatTimestamp(createdAt)}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _approvePet(doc.id),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Approve'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            () => _rejectPet(doc.id, name),
                                        icon: const Icon(Icons.close),
                                        label: const Text('Reject'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '—';
    try {
      final dt = ts.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }
}
