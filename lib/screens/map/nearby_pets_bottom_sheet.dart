import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:latlong2/latlong.dart';
import '../../models/pet_listing.dart';
import '../../models/shop_place.dart';
import '../../services/places_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/location_service.dart';

class NearbyPetsBottomSheet extends StatefulWidget {
  final List<PetListing> petListings;
  final LatLng userLocation;
  final double initialSearchRadius;
  final void Function(double) onRadiusChanged;
  final void Function(PetListing, bool) showPetDetails;
  final bool Function(String) isCurrentUserPetOwner;
  final VoidCallback onAddPet;
  final ScrollController? scrollController;
  final void Function(bool isShops)? onModeChanged;
  final void Function(List<ShopPlace> shops)? onShopsChanged;
  final void Function(LatLng location)? onFocusLocation;

  const NearbyPetsBottomSheet({
    Key? key,
    required this.petListings,
    required this.userLocation,
    required this.initialSearchRadius,
    required this.onRadiusChanged,
    required this.showPetDetails,
    required this.isCurrentUserPetOwner,
    required this.onAddPet,
    this.scrollController,
    this.onModeChanged,
    this.onShopsChanged,
    this.onFocusLocation,
  }) : super(key: key);

  @override
  _NearbyPetsBottomSheetState createState() => _NearbyPetsBottomSheetState();
}

class _NearbyPetsBottomSheetState extends State<NearbyPetsBottomSheet> {
  late double _searchRadius;
  late List<PetListing> _filteredPets;
  String _searchQuery = '';
  String _selectedPetType = 'All';
  String _mode = 'Pets'; // 'Pets' or 'Shops'
  List<ShopPlace> _nearbyShops = [];
  bool _loadingShops = false;
  DateTime? _lastShopFetch;

  final List<String> _petTypes = [
    'All',
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

  @override
  void initState() {
    super.initState();
    _searchRadius = widget.initialSearchRadius;
    _filteredPets = _filterPets();
    // Preload shops lightly once to warm cache (no aggressive polling)
    _maybeFetchShops();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onModeChanged?.call(_mode == 'Shops');
      if (_nearbyShops.isNotEmpty) {
        widget.onShopsChanged?.call(_nearbyShops);
      }
    });
  }

  @override
  void didUpdateWidget(NearbyPetsBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petListings != widget.petListings ||
        oldWidget.userLocation != widget.userLocation) {
      setState(() {
        _filteredPets = _filterPets();
      });
      if (_mode == 'Shops' && oldWidget.userLocation != widget.userLocation) {
        // Resort with new user position; reuse cached shops if within TTL
        setState(() {
          _nearbyShops = _sortShopsByDistance(_nearbyShops);
        });
        widget.onShopsChanged?.call(_nearbyShops);
      }
    }
  }

  Future<void> _maybeFetchShops() async {
    // Debounce to avoid too many requests on free tier
    if (_loadingShops) return;
    final now = DateTime.now();
    if (_lastShopFetch != null &&
        now.difference(_lastShopFetch!) < const Duration(minutes: 3)) {
      return;
    }
    setState(() {
      _loadingShops = true;
    });
    final shops = await PlacesService.getNearbyPetShops(
      location: widget.userLocation,
      radiusKm: 10.0,
    );
    if (!mounted) return;
    setState(() {
      _nearbyShops = _sortShopsByDistance(shops);
      _loadingShops = false;
      _lastShopFetch = now;
    });
    widget.onShopsChanged?.call(_nearbyShops);
  }

  List<ShopPlace> _sortShopsByDistance(List<ShopPlace> shops) {
    final double uLat = widget.userLocation.latitude;
    final double uLng = widget.userLocation.longitude;
    final sorted = List<ShopPlace>.from(shops);
    sorted.sort((a, b) {
      final da = LocationService.calculateDistance(
        uLat,
        uLng,
        a.location.latitude,
        a.location.longitude,
      );
      final db = LocationService.calculateDistance(
        uLat,
        uLng,
        b.location.latitude,
        b.location.longitude,
      );
      return da.compareTo(db);
    });
    return sorted;
  }

  void _openInMaps({double? lat, double? lng, String? query}) async {
    try {
      // Prefer exact coordinates when available
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
        return;
      }

      // Fallback: query-only path (not used by UI, but safe to keep)
      if (query != null && query.isNotEmpty) {
        final String encoded = Uri.encodeComponent(query);

        if (!kIsWeb && Platform.isAndroid) {
          final Uri geo = Uri.parse('geo:0,0?q=$encoded');
          if (await canLaunchUrl(geo)) {
            await launchUrl(geo, mode: LaunchMode.externalApplication);
            return;
          }
          final Uri web = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$encoded',
          );
          await launchUrl(web, mode: LaunchMode.externalApplication);
          return;
        }

        if (!kIsWeb && Platform.isIOS) {
          final Uri gmm = Uri.parse('comgooglemaps://?q=$encoded');
          if (await canLaunchUrl(gmm)) {
            await launchUrl(gmm, mode: LaunchMode.externalApplication);
            return;
          }
          final Uri apple = Uri.parse('http://maps.apple.com/?q=$encoded');
          await launchUrl(apple, mode: LaunchMode.externalApplication);
          return;
        }

        final Uri web = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$encoded',
        );
        await launchUrl(web, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // No-op on failure
    }
  }

  List<PetListing> _filterPets() {
    // First filter by distance
    List<PetListing> byDistance =
        widget.petListings.where((pet) {
          final distance = LocationService.calculateDistance(
            widget.userLocation.latitude,
            widget.userLocation.longitude,
            pet.location.latitude,
            pet.location.longitude,
          );
          return distance <= _searchRadius;
        }).toList();

    // Then filter by search query if provided
    List<PetListing> bySearch = byDistance;
    if (_searchQuery.isNotEmpty) {
      bySearch =
          byDistance.where((pet) {
            return pet.name.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (pet.address != null &&
                    pet.address!.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    )) ||
                pet.type.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
    }

    // Then filter by pet type if not "All"
    List<PetListing> byType = bySearch;
    if (_selectedPetType != 'All') {
      byType =
          bySearch.where((pet) {
            return pet.type.toLowerCase().contains(
              _selectedPetType.toLowerCase(),
            );
          }).toList();
    }

    // Sort by distance
    byType.sort((a, b) {
      double distanceA = LocationService.calculateDistance(
        widget.userLocation.latitude,
        widget.userLocation.longitude,
        a.location.latitude,
        a.location.longitude,
      );
      double distanceB = LocationService.calculateDistance(
        widget.userLocation.latitude,
        widget.userLocation.longitude,
        b.location.latitude,
        b.location.longitude,
      );
      return distanceA.compareTo(distanceB);
    });

    return byType;
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle for dragging
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Pets'),
                  selected: _mode == 'Pets',
                  onSelected: (s) {
                    if (!s) return;
                    setState(() {
                      _mode = 'Pets';
                    });
                    widget.onModeChanged?.call(false);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Pet Shops'),
                  selected: _mode == 'Shops',
                  onSelected: (s) async {
                    if (!s) return;
                    setState(() {
                      _mode = 'Shops';
                    });
                    widget.onModeChanged?.call(true);
                    await _maybeFetchShops();
                  },
                ),
              ],
            ),
            if (_mode == 'Pets')
              ElevatedButton.icon(
                onPressed: widget.onAddPet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add a pet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // Search bar
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search pets...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _filteredPets = _filterPets();
              });
            },
          ),
        ),

        const SizedBox(height: 16),

        if (_mode == 'Pets')
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  _petTypes
                      .map(
                        (type) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(type),
                            selected: _selectedPetType == type,
                            onSelected: (selected) {
                              setState(() {
                                _selectedPetType = type;
                                _filteredPets = _filterPets();
                              });
                            },
                            backgroundColor: Colors.grey[100],
                            selectedColor: Colors.deepPurple.withOpacity(0.2),
                            checkmarkColor: Colors.deepPurple,
                            labelStyle: TextStyle(
                              color:
                                  _selectedPetType == type
                                      ? Colors.deepPurple
                                      : Colors.black,
                              fontWeight:
                                  _selectedPetType == type
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color:
                                    _selectedPetType == type
                                        ? Colors.deepPurple
                                        : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),

        const SizedBox(height: 16),

        // Search radius slider (hidden in Shops mode; fixed 10 km)
        if (_mode == 'Pets')
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Distance:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4.0,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10.0,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16.0,
                        ),
                        activeTrackColor: Colors.deepPurple,
                        inactiveTrackColor: Colors.deepPurple.withOpacity(0.3),
                        thumbColor: Colors.deepPurple,
                        overlayColor: Colors.deepPurple.withOpacity(0.3),
                      ),
                      child: Slider(
                        value: _searchRadius,
                        min: 1.0,
                        max: 10.0,
                        divisions: 18,
                        label: '${_searchRadius.toStringAsFixed(1)}km',
                        onChanged: (value) {
                          setState(() {
                            _searchRadius = value;
                            _filteredPets = _filterPets();
                          });
                          widget.onRadiusChanged(value);
                        },
                      ),
                    ),
                  ),
                  Text(
                    '${_searchRadius.toStringAsFixed(1)} km',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        if (_mode == 'Shops')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: const [
                Text(
                  'Distance:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 8),
                Text('10.0 km (fixed)'),
              ],
            ),
          ),

        const SizedBox(height: 4),

        if (_mode == 'Pets')
          Text(
            'Found ${_filteredPets.length} pets within range',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: Colors.deepPurple,
            ),
          )
        else
          Text(
            _loadingShops
                ? 'Loading pet shops...'
                : 'Found ${_nearbyShops.length} pet shops within range',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: Colors.deepPurple,
            ),
          ),

        const Divider(height: 24, thickness: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      // Use a ListView with the scrollController to make the entire sheet draggable
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Add the header section
          _buildHeader(),

          if (_mode == 'Pets')
            (_filteredPets.isEmpty
                ? Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pets, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No pets found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your filters or search radius',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
                : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredPets.length,
                  itemBuilder: (context, index) {
                    final pet = _filteredPets[index];
                    final distance = LocationService.calculateDistance(
                      widget.userLocation.latitude,
                      widget.userLocation.longitude,
                      pet.location.latitude,
                      pet.location.longitude,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          widget.showPetDetails(
                            pet,
                            widget.isCurrentUserPetOwner(pet.userId),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Pet image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  pet.imageUrl,
                                  height: 70,
                                  width: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 70,
                                      width: 70,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.pets, size: 35),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Pet details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pet.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      pet.type,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${distance.toStringAsFixed(1)} km away',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (pet.address != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        pet.address!,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ))
          else
            (_loadingShops
                ? Container(
                  height: 120,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                )
                : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _nearbyShops.length,
                  itemBuilder: (context, index) {
                    final shop = _nearbyShops[index];
                    final distance = LocationService.calculateDistance(
                      widget.userLocation.latitude,
                      widget.userLocation.longitude,
                      shop.location.latitude,
                      shop.location.longitude,
                    );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child:
                                  shop.photoReference != null
                                      ? Image.network(
                                        PlacesService.buildPhotoUrl(
                                          shop.photoReference!,
                                        ),
                                        height: 70,
                                        width: 70,
                                        fit: BoxFit.cover,
                                      )
                                      : Container(
                                        height: 70,
                                        width: 70,
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.store,
                                          size: 35,
                                        ),
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${distance.toStringAsFixed(1)} km away',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (shop.rating != null)
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 14,
                                              color: Colors.amber,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              shop.rating!.toStringAsFixed(1),
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (shop.openNow != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          child: Text(
                                            shop.openNow!
                                                ? 'Open now'
                                                : 'Closed',
                                            style: TextStyle(
                                              color:
                                                  shop.openNow!
                                                      ? Colors.green[700]
                                                      : Colors.red[700],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (shop.address != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      shop.address!,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed:
                                              () => _openInMaps(
                                                lat: shop.location.latitude,
                                                lng: shop.location.longitude,
                                              ),
                                          icon: const Icon(Icons.directions),
                                          label: const Text('Open in Maps'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed:
                                              () => widget.onFocusLocation
                                                  ?.call(shop.location),
                                          icon: const Icon(
                                            Icons.center_focus_strong,
                                          ),
                                          label: const Text('Focus here'),
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
                )),
          // Add extra padding at the bottom to ensure content isn't hidden behind navigation
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
