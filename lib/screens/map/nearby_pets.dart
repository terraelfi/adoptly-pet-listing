import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/pet_listing.dart';
import '../../services/location_service.dart';

class NearbyPets {
  static Future<void> showNearbyPetsSheet(
    BuildContext context,
    List<PetListing> petListings,
    LatLng userLocation,
    double searchRadius,
    void Function(double) onRadiusChanged,
    void Function(PetListing, bool) showPetDetails,
    bool Function(String) isCurrentUserPetOwner,
  ) {
    // Make a copy of petListings to avoid modifying the original list
    List<PetListing> allPets = List.from(petListings);

    // Initialize filtered pets at start
    List<PetListing> filteredPets = filterNearbyPets(
      allPets,
      userLocation,
      searchRadius,
    );

    print("Initial nearby pets count: ${filteredPets.length}");

    // Display pet locations and distances for debugging
    for (var pet in allPets) {
      double distance = LocationService.calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        pet.location.latitude,
        pet.location.longitude,
      );
      print(
        "Pet: ${pet.name}, Location: ${pet.location.latitude},${pet.location.longitude}, Distance: ${distance.toStringAsFixed(2)} km",
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheetState) => Container(
                  padding: const EdgeInsets.all(16),
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pets within ${searchRadius.toStringAsFixed(1)}km',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Search radius: '),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4.0,
                                thumbShape: RoundSliderThumbShape(
                                  enabledThumbRadius: 12.0,
                                ),
                                overlayShape: RoundSliderOverlayShape(
                                  overlayRadius: 20.0,
                                ),
                                activeTrackColor: Colors.deepPurple,
                                inactiveTrackColor: Colors.deepPurple
                                    .withOpacity(0.3),
                                thumbColor: Colors.deepPurple,
                                overlayColor: Colors.deepPurple.withOpacity(
                                  0.3,
                                ),
                              ),
                              child: Slider(
                                value: searchRadius,
                                min: 1.0,
                                max: 20.0,
                                divisions: 19,
                                label: '${searchRadius.toStringAsFixed(1)}km',
                                onChanged: (value) {
                                  // Update the local state first
                                  setSheetState(() {
                                    // Update the search radius in the sheet state
                                    searchRadius = value;
                                    // Update filtered pets immediately
                                    filteredPets = filterNearbyPets(
                                      allPets,
                                      userLocation,
                                      value,
                                    );
                                    print(
                                      "Radius changed to: $value km, found ${filteredPets.length} pets",
                                    );
                                  });

                                  // Also update the parent state
                                  onRadiusChanged(value);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Found ${filteredPets.length} pets within range',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child:
                            filteredPets.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.pets,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No pets found in this area',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try increasing the search radius',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: filteredPets.length,
                                  itemBuilder: (context, index) {
                                    final pet = filteredPets[index];
                                    final distance =
                                        LocationService.calculateDistance(
                                          userLocation.latitude,
                                          userLocation.longitude,
                                          pet.location.latitude,
                                          pet.location.longitude,
                                        );

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.grey[200],
                                        child: ClipOval(
                                          child: Image.network(
                                            pet.imageUrl,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(Icons.pets),
                                          ),
                                        ),
                                      ),
                                      title: Text(pet.name),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${distance.toStringAsFixed(1)} km away',
                                          ),
                                          if (pet.address != null)
                                            Text(
                                              pet.address!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        showPetDetails(
                                          pet,
                                          isCurrentUserPetOwner(pet.userId),
                                        );
                                      },
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  static List<PetListing> filterNearbyPets(
    List<PetListing> allPets,
    LatLng userLocation,
    double searchRadius,
  ) {
    if (allPets.isEmpty) {
      print("No pets to filter");
      return [];
    }

    print('Filtering ${allPets.length} pets with radius: $searchRadius km');
    print('User location: ${userLocation.latitude}, ${userLocation.longitude}');

    // Filter pets within selected radius
    final nearbyPets =
        allPets.where((pet) {
          // Calculate distance directly using the Haversine formula
          final distance = LocationService.calculateDistance(
            userLocation.latitude,
            userLocation.longitude,
            pet.location.latitude,
            pet.location.longitude,
          );

          final isNearby = distance <= searchRadius;
          print(
            'Pet: ${pet.name}, Distance: ${distance.toStringAsFixed(2)} km, Within radius: $isNearby',
          );

          return isNearby;
        }).toList();

    print('Found ${nearbyPets.length} pets within $searchRadius km range');

    // Sort by distance
    nearbyPets.sort((a, b) {
      double distanceA = LocationService.calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        a.location.latitude,
        a.location.longitude,
      );
      double distanceB = LocationService.calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        b.location.latitude,
        b.location.longitude,
      );
      return distanceA.compareTo(distanceB);
    });

    return nearbyPets;
  }
}
