import 'package:latlong2/latlong.dart';

class ShopPlace {
  final String placeId;
  final String name;
  final String? address;
  final LatLng location;
  final double? rating;
  final int? userRatingsTotal;
  final bool? openNow;
  final String? photoReference;

  const ShopPlace({
    required this.placeId,
    required this.name,
    required this.location,
    this.address,
    this.rating,
    this.userRatingsTotal,
    this.openNow,
    this.photoReference,
  });
}

