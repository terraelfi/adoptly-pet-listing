import 'package:flutter/material.dart';
import '../models/pet_listing.dart';

class PetInfoCard extends StatelessWidget {
  final PetListing pet;
  final VoidCallback onClose;

  const PetInfoCard({super.key, required this.pet, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // Pet image
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Image.asset(pet.imageUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            // Pet info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    pet.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    pet.type,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pet.username,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            // Action buttons
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    // Add pet to favorites
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    // View owner profile
                  },
                ),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.videocam_outlined),
                  onPressed: () {
                    // Video call functionality
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () {
                    // Call functionality
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
