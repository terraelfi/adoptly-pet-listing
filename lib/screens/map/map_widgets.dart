import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/pet_listing.dart';
import '../../models/shop_place.dart';
import 'shop_details_sheet.dart';

class MapWidgets {
  static Widget buildMapLegend() {
    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.7),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                const SizedBox(width: 5),
                const Text('Your location'),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 5),
                const Text('Other pets'),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 5),
                const Text('Your pets'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildUserLocationMarker(LatLng userLocation) {
    return MarkerLayer(
      markers: [
        Marker(
          point: userLocation,
          width: 20.0,
          height: 20.0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  static Widget buildPetMarkers(
    List<PetListing> petListings,
    bool Function(String) isCurrentUserPetOwner,
    void Function(PetListing, bool) showPetDetails,
  ) {
    return MarkerLayer(
      markers:
          petListings.map((pet) {
            final isOwner = isCurrentUserPetOwner(pet.userId);
            return Marker(
              point: pet.location,
              width: 40.0,
              height: 40.0,
              child: InkWell(
                onTap: () => showPetDetails(pet, isOwner),
                child: Container(
                  width: 40.0,
                  height: 40.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOwner ? Colors.orange : Colors.deepPurple,
                  ),
                  child: Icon(
                    isOwner ? Icons.star : Icons.pets,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  static Widget buildShopMarkers(
    List<ShopPlace> shops,
    void Function(LatLng) focusOn, {
    required BuildContext context,
    required LatLng userLocation,
  }) {
    if (shops.isEmpty) return const SizedBox.shrink();

    // Lightweight clustering by grid cell (~1km). Not zoom-aware but reduces clutter.
    const double cellSize = 0.01; // ~1.1km at equator
    final Map<String, List<ShopPlace>> buckets = {};
    for (final s in shops) {
      final latKey = (s.location.latitude / cellSize).round();
      final lngKey = (s.location.longitude / cellSize).round();
      final key = '$latKey:$lngKey';
      buckets.putIfAbsent(key, () => []).add(s);
    }

    final markers = <Marker>[];
    buckets.forEach((_, group) {
      if (group.length == 1) {
        final s = group.first;
        markers.add(
          Marker(
            point: s.location,
            width: 34,
            height: 34,
            child: InkWell(
              onTap: () {
                focusOn(s.location);
                ShopDetailsSheet.show(context, s, userLocation);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.teal,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 18),
              ),
            ),
          ),
        );
      } else {
        // Compute centroid for the cluster marker
        double lat = 0, lng = 0;
        for (final s in group) {
          lat += s.location.latitude;
          lng += s.location.longitude;
        }
        lat /= group.length;
        lng /= group.length;
        final center = LatLng(lat, lng);
        markers.add(
          Marker(
            point: center,
            width: 36,
            height: 36,
            child: InkWell(
              onTap: () => focusOn(center),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.teal[700],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    group.length.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    });

    return MarkerLayer(markers: markers);
  }
}
