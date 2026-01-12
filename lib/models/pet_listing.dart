import 'package:latlong2/latlong.dart';

class PetListing {
  final String id;
  final String name;
  final String type;
  final String username;
  final String imageUrl;
  final LatLng location;
  final String userId; // Added user ID field
  final String? address; // Added address field
  final String? description; // Optional description
  final String? adoptionStatus; // e.g., Available, Adopted, Pending
  final DateTime? adoptedAt; // When adopted

  PetListing({
    required this.id,
    required this.name,
    required this.type,
    required this.username,
    required this.imageUrl,
    required this.location,
    required this.userId, // Added user ID to constructor
    this.address, // Added address parameter
    this.description, // Added description parameter
    this.adoptionStatus,
    this.adoptedAt,
  });
}
