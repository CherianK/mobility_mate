/// Utility functions for extracting venue name and type from various possible structures.
/// Extracts the name of a venue from various possible locations in the venue map.
/// Checks direct keys, 'Tags', 'Metadata', and falls back to any key containing 'name'.
String? extractVenueName(Map<String, dynamic> venue) {
  // 1. Direct keys
  if (venue['Name'] != null && venue['Name'].toString().trim().isNotEmpty) {
    return _capitalize(venue['Name'].toString());
  }
  if (venue['name'] != null && venue['name'].toString().trim().isNotEmpty) {
    return _capitalize(venue['name'].toString());
  }
  // 2. Tags sub-map
  if (venue['Tags'] is Map) {
    final tags = venue['Tags'] as Map;
    if (tags['Name'] != null && tags['Name'].toString().trim().isNotEmpty) {
      return _capitalize(tags['Name'].toString());
    }
    if (tags['name'] != null && tags['name'].toString().trim().isNotEmpty) {
      return _capitalize(tags['name'].toString());
    }
  }
  // 3. Metadata sub-map
  if (venue['Metadata'] is Map) {
    final meta = venue['Metadata'] as Map;
    if (meta['Name'] != null && meta['Name'].toString().trim().isNotEmpty) {
      return _capitalize(meta['Name'].toString());
    }
    if (meta['name'] != null && meta['name'].toString().trim().isNotEmpty) {
      return _capitalize(meta['name'].toString());
    }
  }
  // 4. Fallback: look for any key containing 'name'
  final entry = venue.entries.firstWhere(
    (e) => e.key.toLowerCase().contains('name') && e.value != null && e.value.toString().trim().isNotEmpty,
    orElse: () => const MapEntry('', null),
  );
  if (entry.key.isNotEmpty && entry.value != null) {
    return _capitalize(entry.value.toString());
  }
  // Not found
  return null;
}

/// Extracts the type of a venue from various possible locations in the venue map.
/// Checks direct keys, 'Tags', 'Metadata', and falls back to any key containing 'type'.
/// If not found, uses the provided [defaultType].
String? extractVenueType(Map<String, dynamic> venue, {String? defaultType}) {
  // 1. Direct key
  if (venue['Type'] != null && venue['Type'].toString().trim().isNotEmpty) {
    return _capitalize(venue['Type'].toString());
  }
  // 2. Tags sub-map
  if (venue['Tags'] is Map) {
    final tags = venue['Tags'] as Map;
    if (tags['Type'] != null && tags['Type'].toString().trim().isNotEmpty) {
      return _capitalize(tags['Type'].toString());
    }
    if (tags['type'] != null && tags['type'].toString().trim().isNotEmpty) {
      return _capitalize(tags['type'].toString());
    }
  }
  // 3. Metadata sub-map
  if (venue['Metadata'] is Map) {
    final meta = venue['Metadata'] as Map;
    if (meta['Type'] != null && meta['Type'].toString().trim().isNotEmpty) {
      return _capitalize(meta['Type'].toString());
    }
    if (meta['type'] != null && meta['type'].toString().trim().isNotEmpty) {
      return _capitalize(meta['type'].toString());
    }
  }
  // 4. Fallback: look for any key containing 'type'
  final entry = venue.entries.firstWhere(
    (e) => e.key.toLowerCase().contains('type') && e.value != null && e.value.toString().trim().isNotEmpty,
    orElse: () => const MapEntry('', null),
  );
  if (entry.key.isNotEmpty && entry.value != null) {
    return _capitalize(entry.value.toString());
  }
  // 5. If the type is known from context, use it
  if (defaultType != null) return defaultType;
  return null;
}

/// Capitalizes the first letter of the input string.
String _capitalize(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1);
}
