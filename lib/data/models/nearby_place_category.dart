// Place types for "near me" map searches, plus the launcher that opens Google Maps.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// One chip on the nearby screen: Arabic label, Maps query, and icon.
class NearbyPlaceCategory {
  /// Chip text.
  final String label;

  /// What to search for in Maps.
  final String mapsQuery;

  /// Chip icon.
  final IconData icon;

  /// A place chip.
  const NearbyPlaceCategory({
    required this.label,
    required this.mapsQuery,
    required this.icon,
  });
}

/// The chips on the online tab.
const List<NearbyPlaceCategory> nearbyPlaceCategories = [
  NearbyPlaceCategory(
    label: 'بقاليات',
    mapsQuery: 'بقاليات',
    icon: Icons.local_grocery_store_rounded,
  ),
  NearbyPlaceCategory(
    label: 'مطاعم',
    mapsQuery: 'مطاعم',
    icon: Icons.restaurant_rounded,
  ),
  NearbyPlaceCategory(
    label: 'صيدليات',
    mapsQuery: 'صيدليات',
    icon: Icons.local_pharmacy_rounded,
  ),
  NearbyPlaceCategory(
    label: 'محطات وقود',
    mapsQuery: 'محطة وقود',
    icon: Icons.local_gas_station_rounded,
  ),
];

/// Opens Maps with "near me" for the category; falls back to geo: if the https URL won't launch.
Future<bool> openNearbyPlaceSearch(NearbyPlaceCategory category) async {
  final encoded = Uri.encodeComponent('${category.mapsQuery} بالقرب مني');
  final maps = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$encoded',
  );

  if (await canLaunchUrl(maps)) {
    return launchUrl(maps, mode: LaunchMode.externalApplication);
  }

  final geo = Uri.parse('geo:0,0?q=$encoded');
  if (await canLaunchUrl(geo)) {
    return launchUrl(geo, mode: LaunchMode.externalApplication);
  }

  return launchUrl(maps, mode: LaunchMode.externalApplication);
}
