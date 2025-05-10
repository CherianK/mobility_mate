import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/tag_formatter.dart';
import '../screens/report_issue_screen.dart';
import '../screens/upload_page.dart';
import '../utils/location_helper.dart';
import '../utils/share_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LocationBottomSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final String title;
  final IconData Function(String, dynamic) iconGetter;
  final VoidCallback onClose;

  const LocationBottomSheet({
    super.key,
    required this.data,
    required this.title,
    required this.iconGetter,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.extent <= 0.22) {
          onClose();
        }
        return true;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // Drag handle with animation
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated indicator
                    Positioned(
                      top: 2,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(seconds: 3),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: (1 - value).clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, 6 * value),
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_up,
                                  color: Colors.blue,
                                  size: 24,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Existing drag handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: _buildContent(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final Map<String, dynamic> tags = data['Tags'] ?? {};
    final List<MapEntry<String, dynamic>> allTags = tags.entries.toList();
    final List<String> images = (data['Images'] as List<dynamic>? ?? [])
      .where((img) => img is Map && img['approved_status'] == true)
      .map<String>((img) => img['image_url'] as String)
      .toList();
    final prioritizedKeys = [
      'wheelchair',
      'access',
      'parkingaccessible',
      'toilets:wheelchair',
    ];

    final List<MapEntry<String, dynamic>> orderedTags = [
      ...prioritizedKeys
          .map((key) => allTags.where((entry) => entry.key.toLowerCase() == key))
          .expand((e) => e),
      ...allTags
          .where((entry) => !prioritizedKeys.contains(entry.key.toLowerCase()))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    ];

    final destLat = data['Location_Lat']?.toString() ?? '';
    final destLon = data['Location_Lon']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and close button
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final choice = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                          children: [
                            Icon(Icons.directions, color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            const Text(
                              'Select Mode of Travel',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'How would you like to reach the location?',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTravelModeButton(
                                    context,
                                    'wheelchair',
                                    Icons.accessible,
                                    'Wheelchair',
                                    Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTravelModeButton(
                                    context,
                                    'drive',
                                    Icons.directions_car,
                                    'Drive',
                                    Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );

                    if (choice == null) return;

                    String? originLat;
                    String? originLon;

                    if (choice == 'wheelchair' && context.mounted) {
                      await showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (context) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop(),
                          child: Material(
                            color: Colors.transparent,
                            child: GestureDetector(
                              onTap: () {}, // Prevent taps from propagating to the parent GestureDetector
                              child: AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Accessibility Tip',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.blue.shade100,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.accessibility_new,
                                            color: Colors.blue.shade700,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              'Enable "Wheelchair-accessible" under Trip Options in Google Maps for better routes!',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        // Continue with Google Maps after Got it is pressed
                                        _launchGoogleMaps(context, destLat, destLon, originLat, originLon, choice);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        'Got it',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                      return; // Return here to prevent the Google Maps call when dialog is dismissed by tapping outside
                    }

                    // Move the Google Maps launch logic to a separate method
                    _launchGoogleMaps(context, destLat, destLon, originLat, originLon, choice);
                  },
                  icon: const Icon(Icons.directions_outlined, color: Colors.white),
                  label: const Text('Get Directions', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ReportIssueScreen()),
                        );
                      },
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Report'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Color(0xFFD1D1D6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        
                        final lat = double.tryParse(destLat);
                        final lon = double.tryParse(destLon);
                        final List<String> featureDescriptions = orderedTags
                          .map((entry) => formatTag(entry.key, entry.value))
                          .where((value) => value.trim().isNotEmpty)
                          .toList();
                        
                        
                        if (lat != null && lon != null) {
                          ShareHelper.shareLocationWithDetails(
                            latitude: lat,
                            longitude: lon,
                            name: title,
                            features: featureDescriptions,
                            context: context,
                          );
                        }
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Color(0xFFD1D1D6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UploadPage(venueData: data),
                          ),
                        );
                      },
                      icon: const Icon(Icons.upload_outlined),
                      label: const Text(
                        'Upload',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Color(0xFFD1D1D6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Images Section
        if (images.isNotEmpty) ...[
          const Divider(height: 1, color: Color(0xFFE5E5EA)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index != images.length - 1 ? 8.0 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: Stack(
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: images[index],
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.error),
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: images[index],
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.error),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const Divider(height: 1, color: Color(0xFFE5E5EA)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No attached pictures',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Accessibility features
        if (orderedTags.isNotEmpty) ...[
          const Divider(height: 1, color: Color(0xFFE5E5EA)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accessibility Features',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                ...orderedTags.map((entry) {
                  final key = entry.key.replaceAll('_', ' ').split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
                  final value = entry.value.toString().toLowerCase();

                  Color valueColor;
                  String displayValue;

                  if (value == 'yes') {
                    valueColor = Colors.green;
                    displayValue = 'Available';
                  } else if (value == 'no') {
                    valueColor = Colors.red;
                    displayValue = 'Unavailable';
                  } else {
                    valueColor = Colors.blue;
                    displayValue = entry.value.toString();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              iconGetter(entry.key, entry.value),
                              color: valueColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              key,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayValue,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: valueColor),
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTravelModeButton(
    BuildContext context,
    String mode,
    IconData icon,
    String label,
    Color color,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchGoogleMaps(BuildContext context, String destLat, String destLon, String? originLat, String? originLon, String choice) async {
    Uri url;
    if (choice == 'drive') {
      if (originLat != null && originLon != null) {
        url = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLon&destination=$destLat,$destLon&travelmode=driving');
      } else {
        url = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLon&travelmode=driving');
      }
    } else {
      if (originLat != null && originLon != null) {
        url = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLon&destination=$destLat,$destLon&travelmode=walking');
      } else {
        url = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLon&travelmode=walking');
      }
    }

    if (choice == 'wheelchair' && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Tip: Enable "Wheelchair-accessible" under Trip Options in Google Maps for better routes!'),
          duration: Duration(seconds: 3),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch Google Maps.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}