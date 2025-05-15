String formatTag(String key, dynamic value) {
  List<String> words = key.split('_');
  String formattedKey = words
      .map((word) => word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1).toLowerCase()
          : '')
      .join(' ');
  String formattedValue = value.toString();
  if (formattedValue.isNotEmpty) {
    formattedValue =
        formattedValue[0].toUpperCase() + formattedValue.substring(1).toLowerCase();
  }
  return '$formattedKey: $formattedValue';
}

String? formatMarkerDisplayName({
  required String? name,
  required String markerType,
}) {
  if (name == null || name.isEmpty) return null;
  String formattedName = name.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
  switch (markerType) {
    case 'trains':
      return formattedName.endsWith('Station') ? formattedName : '$formattedName Station';
    case 'trams':
      return formattedName;
    case 'medical':
      return formattedName;
    default:
      return null;
  }
}
