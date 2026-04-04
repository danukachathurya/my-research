import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'car_care_api_service.dart';

enum CarCareCategory { carWash, service }

class CarCareService {
  const CarCareService({
    required this.name,
    required this.address,
    required this.description,
    required this.rating,
    required this.distanceKm,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.serviceTypes,
    required this.source,
    this.shopName,
  });

  final String name;
  final String address;
  final String description;
  final double? rating;
  final double distanceKm;
  final double latitude;
  final double longitude;
  final CarCareCategory category;
  final List<String> serviceTypes;
  final String source;
  final String? shopName;

  bool get _usesGeneratedLocationTitle =>
      name.startsWith('Car Wash - ') || name.startsWith('Service Center - ');

  List<String> get _addressParts => address
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  bool _isIgnoredLocationPart(String value) {
    final normalized = value.toLowerCase();
    return normalized == 'sri lanka' ||
        normalized.endsWith('district') ||
        normalized.endsWith('province') ||
        RegExp(r'^\d{4,6}$').hasMatch(value);
  }

  String? _locationPart({bool skipFirst = false}) {
    final parts = _addressParts;
    final startIndex = skipFirst ? 1 : 0;

    for (var index = startIndex; index < parts.length; index++) {
      final part = parts[index];
      if (_isIgnoredLocationPart(part)) {
        continue;
      }
      return part;
    }
    return null;
  }

  String get cardTitle {
    if (_usesGeneratedLocationTitle) {
      return name;
    }

    final locationLabel = _locationPart() ?? 'Nearby';
    final prefix =
        category == CarCareCategory.carWash ? 'Car Wash' : 'Service Center';
    return '$prefix - $locationLabel';
  }

  String? get companyName {
    if (!_usesGeneratedLocationTitle) {
      return name.trim().isEmpty ? null : name;
    }

    final primaryPart = _locationPart();
    final secondaryPart = _locationPart(skipFirst: true);
    if (primaryPart == null) {
      return null;
    }

    if (secondaryPart != null &&
        primaryPart.toLowerCase() != secondaryPart.toLowerCase()) {
      return primaryPart;
    }

    return null;
  }

  factory CarCareService.fromJson(Map<String, dynamic> json) {
    return CarCareService(
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      category: _categoryFromApi((json['category'] ?? '').toString()),
      serviceTypes: (json['service_types'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      source: (json['source'] ?? 'live').toString(),
      shopName: json['shop_name'] != null && (json['shop_name'] as String).isNotEmpty
          ? (json['shop_name'] as String)
          : null,
    );
  }
}

CarCareCategory _categoryFromApi(String value) {
  switch (value) {
    case 'car_wash':
      return CarCareCategory.carWash;
    case 'service':
    default:
      return CarCareCategory.service;
  }
}

extension CarCareCategoryX on CarCareCategory {
  String get label {
    switch (this) {
      case CarCareCategory.carWash:
        return 'Car Wash';
      case CarCareCategory.service:
        return 'Car Service';
    }
  }

  String get subtitle {
    switch (this) {
      case CarCareCategory.carWash:
        return 'Wash, detailing, and interior cleaning near you';
      case CarCareCategory.service:
        return 'Oil changes, engine checks, and tire support nearby';
    }
  }

  String get searchHint {
    switch (this) {
      case CarCareCategory.carWash:
        return 'Search shop, wash, detailing...';
      case CarCareCategory.service:
        return 'Search shop, oil, engine, tire...';
    }
  }

  String get filterTitle {
    switch (this) {
      case CarCareCategory.carWash:
        return 'Wash Types';
      case CarCareCategory.service:
        return 'Service Types';
    }
  }

  List<String> get filterOptions {
    switch (this) {
      case CarCareCategory.carWash:
        return const ['Basic Wash', 'Interior Cleaning', 'Premium Wash'];
      case CarCareCategory.service:
        return const ['Oil Change', 'Engine Check', 'Tire Shop'];
    }
  }

  IconData get icon {
    switch (this) {
      case CarCareCategory.carWash:
        return Icons.local_car_wash_rounded;
      case CarCareCategory.service:
        return Icons.build_circle_rounded;
    }
  }

  List<Color> get colors {
    switch (this) {
      case CarCareCategory.carWash:
        return const [Color(0xFF0EA5A4), Color(0xFF115E59)];
      case CarCareCategory.service:
        return const [Color(0xFFF59E0B), Color(0xFFB45309)];
    }
  }

  String get apiValue {
    switch (this) {
      case CarCareCategory.carWash:
        return 'car_wash';
      case CarCareCategory.service:
        return 'service';
    }
  }
}

class CarCareDashboardPage extends StatelessWidget {
  const CarCareDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Car Care Dashboard')),
      body: Container(
        color: const Color(0xFFF5F7FB),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 760 ? 2 : 1;

              return GridView.count(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: crossAxisCount == 2 ? 1.24 : 1.06,
                children: CarCareCategory.values
                    .map(
                      (category) => _CategorySelectionCard(
                        category: category,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CarCareCategoryPage(category: category),
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CarCareCategoryPage extends StatefulWidget {
  const CarCareCategoryPage({super.key, required this.category});

  final CarCareCategory category;

  @override
  State<CarCareCategoryPage> createState() => _CarCareCategoryPageState();
}

class _CarCareCategoryPageState extends State<CarCareCategoryPage> {
  final CarCareApiService _apiService = CarCareApiService();
  static const double _fallbackLatitude = 6.9271;
  static const double _fallbackLongitude = 79.8612;

  String _searchQuery = '';
  bool _onlyHighRated = false;
  bool _isLoading = true;
  bool _isResolvingLocation = false;
  String? _errorMessage;
  String? _locationStatusMessage;
  List<CarCareService> _services = const [];
  final Set<String> _selectedServiceTypes = <String>{};
  Position? _currentPosition;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _initializePage() async {
    await _loadCurrentLocation();
    if (!mounted) {
      return;
    }
    await _refreshServices();
  }

  bool get _hasActiveFilters {
    return _selectedServiceTypes.isNotEmpty || _onlyHighRated;
  }

  bool get _hasLiveLocation => _currentPosition != null;

  List<String> get _activeFilters {
    final filters = <String>[];
    if (_onlyHighRated) {
      filters.add('4 stars and above');
    }
    // Also include selected service types as active filter chips
    filters.addAll(_selectedServiceTypes);
    return filters;
  }

  List<CarCareService> get _displayServices {
    final services = _services.map(_serviceWithComputedDistance).toList();

    services.sort((a, b) {
      final distanceCompare = a.distanceKm.compareTo(b.distanceKm);
      if (distanceCompare != 0) {
        return distanceCompare;
      }
      return (b.rating ?? 0).compareTo(a.rating ?? 0);
    });

    return services;
  }

  List<CarCareService> get _nearestServices =>
      _displayServices.take(20).toList();

  CarCareService _serviceWithComputedDistance(CarCareService service) {
    return CarCareService(
      name: service.name,
      address: service.address,
      description: service.description,
      rating: service.rating,
      distanceKm: _distanceFromCurrentLocation(service),
      latitude: service.latitude,
      longitude: service.longitude,
      category: service.category,
      serviceTypes: service.serviceTypes,
      source: service.source,
      shopName: service.shopName,
    );
  }

  double _distanceFromCurrentLocation(CarCareService service) {
    final originLatitude = _currentPosition?.latitude ?? _fallbackLatitude;
    final originLongitude = _currentPosition?.longitude ?? _fallbackLongitude;
    return Geolocator.distanceBetween(
          originLatitude,
          originLongitude,
          service.latitude,
          service.longitude,
        ) /
        1000;
  }

  Future<void> _refreshServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final serviceJson = await _apiService.fetchNearestLocations(
        search: _searchQuery,
        category: widget.category.apiValue,
        serviceTypes: _selectedServiceTypes.toList(),
        latitude: _currentPosition?.latitude ?? _fallbackLatitude,
        longitude: _currentPosition?.longitude ?? _fallbackLongitude,
        minRating: _onlyHighRated ? 4.0 : null,
        limit: 20,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _services = serviceJson.map(CarCareService.fromJson).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _services = const [];
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _refreshServices,
    );
  }

  void _clearFilters() {
    setState(() {
      _onlyHighRated = false;
      _selectedServiceTypes.clear();
    });
    _refreshServices();
  }

  void _toggleServiceType(String serviceType) {
    setState(() {
      if (_selectedServiceTypes.contains(serviceType)) {
        _selectedServiceTypes.remove(serviceType);
      } else {
        _selectedServiceTypes.add(serviceType);
      }
    });
    _refreshServices();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isResolvingLocation = true);

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          setState(() {
            _locationStatusMessage =
                'Location is turned off. Showing nearby places from the default Colombo area.';
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationStatusMessage =
                'Location permission is not enabled. Showing nearby places from the default Colombo area.';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPosition = position;
        _locationStatusMessage =
            'Using your live device location for nearest car wash results.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationStatusMessage =
              'Could not get your live location right now. Showing nearby places from the default Colombo area.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isResolvingLocation = false);
      }
    }
  }

  Future<void> _refreshWithLatestLocation() async {
    await _loadCurrentLocation();
    if (!mounted) {
      return;
    }
    await _refreshServices();
  }

  Future<void> _openMaps(CarCareService service) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${service.latitude},${service.longitude}',
    });

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  Future<void> _showFilterSheet() async {
    bool tempOnlyHighRated = _onlyHighRated;
    // Copy current selection so user can cancel without applying
    final Set<String> tempSelectedTypes = Set<String>.from(_selectedServiceTypes);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Filter ${widget.category.label}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempOnlyHighRated = false;
                                tempSelectedTypes.clear();
                              });
                            },
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- Service / Wash Type filter ---
                      _FilterSection(
                        title: widget.category.filterTitle,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: widget.category.filterOptions.map((option) {
                            final selected = tempSelectedTypes.contains(option);
                            return FilterChip(
                              label: Text(option),
                              selected: selected,
                              onSelected: (_) {
                                setModalState(() {
                                  if (selected) {
                                    tempSelectedTypes.remove(option);
                                  } else {
                                    tempSelectedTypes.add(option);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // --- Rating filter ---
                      _FilterSection(
                        title: 'Rating',
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('4 stars and above'),
                          value: tempOnlyHighRated,
                          onChanged: (value) {
                            setModalState(() => tempOnlyHighRated = value);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- Apply button ---
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _onlyHighRated = tempOnlyHighRated;
                              _selectedServiceTypes
                                ..clear()
                                ..addAll(tempSelectedTypes);
                            });
                            Navigator.pop(context);
                            _refreshServices();
                          },
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayServices = _displayServices;
    final nearestServices = _nearestServices;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.label),
        actions: [
          IconButton(
            tooltip: 'Filter services',
            onPressed: _showFilterSheet,
            icon: const Icon(Icons.filter_alt_rounded),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF5F7FB),
        child: RefreshIndicator(
          onRefresh: _refreshWithLatestLocation,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _CategorySummaryCard(
                category: widget.category,
                services: displayServices,
                nearestServices: nearestServices,
              ),
              const SizedBox(height: 18),
              TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: widget.category.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _FilterOverviewCard(
                category: widget.category,
                activeFilters: _activeFilters,
                selectedServiceTypes: _selectedServiceTypes,
                onToggleServiceType: _toggleServiceType,
                onOpenFilters: _showFilterSheet,
                onClearFilters: _hasActiveFilters ? _clearFilters : null,
              ),
              if (_locationStatusMessage != null) ...[
                const SizedBox(height: 16),
                _LocationStatusCard(
                  message: _locationStatusMessage!,
                  isLiveLocation: _hasLiveLocation,
                  onRefreshLocation: _isResolvingLocation
                      ? null
                      : _refreshWithLatestLocation,
                ),
              ],
              const SizedBox(height: 24),
              _SectionHeader(
                icon: Icons.place_rounded,
                title: 'Nearest Locations',
                subtitle: _isResolvingLocation
                    ? 'Updating distances from your current location'
                    : _hasLiveLocation
                    ? 'Top 20 live nearby ${widget.category.label.toLowerCase()} results'
                    : 'Top 20 nearby ${widget.category.label.toLowerCase()} results from the default Colombo area',
              ),
              const SizedBox(height: 12),
              if (_isLoading && _services.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null && _services.isEmpty)
                _buildEmptyState(
                  message:
                      'Could not load ${widget.category.label.toLowerCase()} data.\n$_errorMessage',
                  actionLabel: 'Retry',
                  onAction: _refreshServices,
                )
              else if (nearestServices.isEmpty)
                _buildEmptyState(
                  message:
                      'No nearby ${widget.category.label.toLowerCase()} matches the current filters.',
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: nearestServices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final service = nearestServices[index];
                    return _NearestLocationCard(
                      service: service,
                      onTap: () => _openMaps(service),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    String message = 'No services match your search or filters.',
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 40,
            color: Color(0xFF64748B),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategorySelectionCard extends StatelessWidget {
  const _CategorySelectionCard({required this.category, required this.onTap});

  final CarCareCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = category.colors;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(category.icon, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 18),
                Text(
                  category.label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  category.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Open'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySummaryCard extends StatelessWidget {
  const _CategorySummaryCard({
    required this.category,
    required this.services,
    required this.nearestServices,
  });

  final CarCareCategory category;
  final List<CarCareService> services;
  final List<CarCareService> nearestServices;

  @override
  Widget build(BuildContext context) {
    final nearestDistance = nearestServices.isEmpty
        ? '--'
        : '${nearestServices.first.distanceKm.toStringAsFixed(1)} km';
    final ratedServices = nearestServices
        .where((service) => service.rating != null)
        .toList();
    final topRated = ratedServices.isEmpty
        ? 'Live'
        : ratedServices
              .map((service) => service.rating!)
              .reduce((a, b) => a > b ? a : b)
              .toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: category.colors),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(category.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  category.subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _MetricTile(label: 'Shops', value: '${services.length}'),
              const SizedBox(width: 12),
              _MetricTile(label: 'Nearest', value: nearestDistance),
              const SizedBox(width: 12),
              _MetricTile(label: 'Top Rated', value: topRated),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({
    required this.message,
    required this.isLiveLocation,
    required this.onRefreshLocation,
  });

  final String message;
  final bool isLiveLocation;
  final VoidCallback? onRefreshLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isLiveLocation
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isLiveLocation
                  ? Icons.my_location_rounded
                  : Icons.location_searching_rounded,
              color: isLiveLocation
                  ? const Color(0xFF15803D)
                  : const Color(0xFFC2410C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLiveLocation ? 'Live Location Active' : 'Using Fallback Area',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onRefreshLocation,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh Location'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterOverviewCard extends StatelessWidget {
  const _FilterOverviewCard({
    required this.category,
    required this.activeFilters,
    required this.selectedServiceTypes,
    required this.onToggleServiceType,
    required this.onOpenFilters,
    required this.onClearFilters,
  });

  final CarCareCategory category;
  final List<String> activeFilters;
  final Set<String> selectedServiceTypes;
  final ValueChanged<String> onToggleServiceType;
  final VoidCallback onOpenFilters;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.tune_rounded),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Filter Section',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onOpenFilters,
                icon: const Icon(Icons.filter_alt_rounded),
                label: const Text('Filter'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Category: ${category.label}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.filterTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: category.filterOptions
                .map(
                  (option) => FilterChip(
                    label: Text(option),
                    selected: selectedServiceTypes.contains(option),
                    onSelected: (_) => onToggleServiceType(option),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          if (activeFilters.isEmpty)
            const Text(
              'No extra filters applied. Showing all nearby results in this category.',
              style: TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
          if (activeFilters.any((f) => !category.filterOptions.contains(f))) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeFilters
                  .where((filter) => !category.filterOptions.contains(filter))
                  .map(
                    (filter) => Chip(
                      avatar: const Icon(Icons.check_circle, size: 18),
                      label: Text(filter),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (onClearFilters != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _NearestLocationCard extends StatelessWidget {
  const _NearestLocationCard({required this.service, required this.onTap});

  final CarCareService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = service.category.colors;
    final primaryTitle = service.companyName ?? service.cardTitle;
    final secondaryTitle =
        service.companyName != null ? service.cardTitle : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          service.category.icon,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          service.category.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Chip(
                    avatar: const Icon(
                      Icons.public_rounded,
                      size: 18,
                      color: Color(0xFF0F172A),
                    ),
                    label: Text(service.source),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                primaryTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (secondaryTitle != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.route_rounded,
                      size: 18,
                      color: Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        secondaryTitle,
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // Show actual shop name if available and different from primary title
              if (service.shopName != null &&
                  service.shopName!.isNotEmpty &&
                  service.shopName!.toLowerCase() != primaryTitle.toLowerCase()) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 18,
                      color: Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        service.shopName!,
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      service.address,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (service.description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  service.description,
                  style: const TextStyle(color: Color(0xFF475569), height: 1.4),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  if (service.rating != null) ...[
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      service.rating!.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 14),
                  ],
                  const Icon(
                    Icons.near_me_rounded,
                    color: Color(0xFF0F766E),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${service.distanceKm.toStringAsFixed(1)} km away',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF0F766E),
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: const Icon(Icons.location_on_rounded),
                  label: const Text('View Location'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
