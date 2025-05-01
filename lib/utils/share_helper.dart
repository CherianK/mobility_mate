import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

class ShareHelper {
  static Future<void> shareLocationWithDetails({
    required double latitude,
    required double longitude,
    required BuildContext context,
    String? name,
    String? description,
    List<String>? features,
  }) async {
    try {
      final String locationUrl = "https://maps.google.com/?q=$latitude,$longitude";
      String shareText = name != null
          ? "Check out $name: $locationUrl"
          : "Check this location: $locationUrl";

      if (description != null && description.isNotEmpty) {
        shareText += "\n\n$description";
      }

    if (features != null && features.isNotEmpty) {
      shareText += "\n\nDetails:\n• ${features.join('\n• ')}";
    }

      // ✅ Add your branding
      shareText += "\n\nSent via Mobility Mate 🧭";

      await Share.share(shareText);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Location shared successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Failed to share location: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      rethrow; // Re-throw the error for the calling code to handle if needed
    }
  }
}