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
