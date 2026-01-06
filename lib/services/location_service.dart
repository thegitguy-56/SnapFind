import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Distance threshold for considering a POI as "near" (in meters)
  static const double _nearbyThresholdMeters = 100.0;

  // Fallback location name when no campus POI matches
  static const String _fallbackLocation = 'Saveetha University, Saveetha Nagar';

  /// List of campus Points of Interest (POIs) with coordinates
  /// Format: {name, latitude, longitude}
  /// TODO: Enable POI matching to provide ultra-precise location names like "Near Library" or "Canteen A"
  /// Why: POIs can pinpoint landmarks within campus more accurately than reverse geocoding alone
  /// Threshold: 100 meters to consider a POI as "near" the capture location
  static const List<Map<String, dynamic>> _campusPOIs = [
    {
      'name': 'Kaveri Hostel',
      'latitude': 13.026695658694733,
      'longitude': 80.01358623261811,
    },
    {
      'name': 'Equitorial Garden Canteens',
      'latitude': 13.026592437955918,
      'longitude': 80.01402745600102,
    },
    {
      'name': 'Rectangular Block',
      'latitude': 13.026485531971636,
      'longitude': 80.0152534154422,
    },
    {
      'name': 'Circular building,ADMIN Block',
      'latitude': 13.025969666819428,
      'longitude': 80.01646550220798,
    },
    {
      'name': 'SAIL Library',
      'latitude': 13.026231843771907,
      'longitude': 80.01720021108711,
    },
    {
      'name': 'Vaigai Hostel',
      'latitude': 13.030270282732625,
      'longitude': 80.01676551373177,
    },
    {
      'name': 'Krishna Hostel',
      'latitude': 13.03024076348444,
      'longitude': 80.01802632071957,
    },
    {
      'name': 'Noyyal Hostel',
      'latitude': 13.027879118447064, 
      'longitude': 80.01751355671419,
    },
    // Add more campus POIs here with actual coordinates
  ];

  /// Resolves GPS coordinates to a human-readable location name
  ///
  /// Returns a natural language description that is never null or empty.
  /// Attempts campus POI matching first, then falls back to reverse geocoding.
  Future<String> resolveLocationName(Position position) async {
    // First, check if user is near a campus POI
    final campusPOIName = _findNearbyPOI(position);
    if (campusPOIName != _fallbackLocation) {
      return campusPOIName;
    }

    // If no POI matched, attempt reverse geocoding
    try {
      // Attempt reverse geocoding
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;

        // Check if placemark.name is specific (not generic)
        if (_isSpecificLocationName(placemark.name)) {
          return placemark.name ?? _buildFallbackLocation(placemark);
        }

        // Try subLocality first (most specific after name)
        if (_isValidLocationName(placemark.subLocality)) {
          return 'Near ${placemark.subLocality}';
        }

        // Fall back to locality
        if (_isValidLocationName(placemark.locality)) {
          return 'Near ${placemark.locality}';
        }

        // Last resort: use administrative area
        if (_isValidLocationName(placemark.administrativeArea)) {
          return 'Near ${placemark.administrativeArea}';
        }
      }

      // Fallback when no placemarks found, return campus area
      return _fallbackLocation;
    } catch (e) {
      // If reverse geocoding fails, return generic campus location
      return _fallbackLocation;
    }
  }

  /// Checks if a location name is specific enough to use directly
  ///
  /// Filters out generic area names that don't provide precise location info
  bool _isSpecificLocationName(String? name) {
    if (name == null || name.isEmpty) {
      return false;
    }

    // Check for common generic keywords
    final genericKeywords = [
      'University',
      'Campus',
      'Area',
      'District',
      'Region',
      'Zone',
    ];
    for (final keyword in genericKeywords) {
      if (name.contains(keyword)) {
        return false;
      }
    }

    return true;
  }

  /// Validates that a location string is usable
  bool _isValidLocationName(String? name) {
    return name != null && name.isNotEmpty && name != 'null';
  }

  /// Builds a fallback location description using coordinate info
  ///
  /// This is called when no specific location name can be determined
  String _buildLocationFromCoordinates(Position position) {
    return 'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
  }

  /// Constructs a location description from placemark data
  ///
  /// Assembles available placemark components into a readable string
  String _buildFallbackLocation(Placemark placemark) {
    final parts = <String>[];

    if (placemark.subLocality?.isNotEmpty ?? false) {
      parts.add(placemark.subLocality!);
    }
    if (placemark.locality?.isNotEmpty ?? false) {
      parts.add(placemark.locality!);
    }
    if (placemark.administrativeArea?.isNotEmpty ?? false) {
      parts.add(placemark.administrativeArea!);
    }

    if (parts.isEmpty) {
      return 'Unknown Location';
    }

    return parts.join(', ');
  }

  /// TODO: Implement nearby POI matching for ultra-precise locations
  ///
  /// This method finds campus landmarks within 100 meters of the GPS position
  /// and returns "Near <POI Name>" for maximum precision.
  String _findNearbyPOI(Position position) {
    double nearestDistance = double.infinity;
    String? nearestPOIName;

    for (final poi in _campusPOIs) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        poi['latitude'] as double,
        poi['longitude'] as double,
      );

      // Check if within 100-meter threshold and closer than previous match
      if (distance <= _nearbyThresholdMeters && distance < nearestDistance) {
        nearestDistance = distance;
        nearestPOIName = poi['name'] as String;
      }
    }

    if (nearestPOIName != null) {
      return 'Near $nearestPOIName';
    }

    return _fallbackLocation;
  }
}
