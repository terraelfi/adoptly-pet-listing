import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/shop_place.dart';
import '../../services/location_service.dart';
import '../../services/places_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopDetailsSheet {
  static Future<void> show(
    BuildContext context,
    ShopPlace shop,
    LatLng userLocation,
  ) async {
    final double distanceKm = LocationService.calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      shop.location.latitude,
      shop.location.longitude,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          shop.photoReference != null
                              ? Image.network(
                                PlacesService.buildPhotoUrl(
                                  shop.photoReference!,
                                ),
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              )
                              : Container(
                                height: 100,
                                width: 100,
                                color: Colors.grey[200],
                                child: const Icon(Icons.store, size: 48),
                              ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${distanceKm.toStringAsFixed(1)} km away',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                          if (shop.rating != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  shop.rating!.toStringAsFixed(1),
                                  style: TextStyle(color: Colors.grey[800]),
                                ),
                                if (shop.userRatingsTotal != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${shop.userRatingsTotal})',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          if (shop.openNow != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              shop.openNow! ? 'Open now' : 'Closed',
                              style: TextStyle(
                                color:
                                    shop.openNow!
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (shop.address != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shop.address!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        () => _openInMaps(
                          lat: shop.location.latitude,
                          lng: shop.location.longitude,
                        ),
                    icon: const Icon(Icons.directions),
                    label: const Text('Open in Maps'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
    );
  }

  static Future<void> _openInMaps({double? lat, double? lng}) async {
    try {
      if (lat != null && lng != null) {
        final String encodedLabel = Uri.encodeComponent('Pet Shop');

        if (!kIsWeb && Platform.isAndroid) {
          final Uri geo = Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedLabel)');
          if (await canLaunchUrl(geo)) {
            await launchUrl(geo, mode: LaunchMode.externalApplication);
            return;
          }
          final Uri web = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
          );
          await launchUrl(web, mode: LaunchMode.externalApplication);
          return;
        }

        if (!kIsWeb && Platform.isIOS) {
          final Uri gmm = Uri.parse(
            'comgooglemaps://?q=$lat,$lng&center=$lat,$lng',
          );
          if (await canLaunchUrl(gmm)) {
            await launchUrl(gmm, mode: LaunchMode.externalApplication);
            return;
          }
          final Uri apple = Uri.parse(
            'http://maps.apple.com/?ll=$lat,$lng&q=$encodedLabel',
          );
          await launchUrl(apple, mode: LaunchMode.externalApplication);
          return;
        }

        final Uri web = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        );
        await launchUrl(web, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}
