import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/tag_formatter.dart';
import '../screens/report_issue_screen.dart';
import '../screens/upload_page.dart';
import '../utils/location_helper.dart';
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
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header with title and close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
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
                const Divider(height: 1),
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
    final List<String> images = List<String>.from(data['Images'] ?? []);
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
        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final choice = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Select Mode of Travel'),
                      content: const Text('How would you like to reach the location?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'wheelchair'),
                          child: const Text('Wheelchair'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'drive'),
                          child: const Text('Drive'),
                        ),
                      ],
                    ),
                  );

                  if (choice == null) return;

                  String? originLat;
                  String? originLon;

                  // Show wheelchair tip first if applicable
                  if (choice == 'wheelchair' && context.mounted) {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        title: const Text('Accessibility Tip'),
                        content: const Text('Enable "Wheelchair-accessible" under Trip Options in Google Maps for better routes!'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  }

                  try {
                    final position = await LocationHelper.getCurrentLocation();
                    if (position != null) {
                      originLat = position.latitude.toString();
                      originLon = position.longitude.toString();
                    }
                  } catch (e) {
                    originLat = null;
                    originLon = null;
                  }

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
                },
                icon: const Icon(Icons.directions_outlined),
                label: const Text('Get Directions'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReportIssueScreen()),
                  );
                },
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Report'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Share.share("Check this location: https://maps.google.com/?q=$destLat,$destLon");
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UploadPage(venueData: data),
                    ),
                  );
                },
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Upload'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        // Images Section
        if (images.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No attached pictures',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
        // Accessibility features
        if (orderedTags.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accessibility Features',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: orderedTags.map((entry) {
                    final icon = iconGetter(entry.key, entry.value);
                    final formattedValue = formatTag(entry.key, entry.value);
                    return Chip(
                      avatar: Icon(icon, size: 18),
                      label: Text(formattedValue),
                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}