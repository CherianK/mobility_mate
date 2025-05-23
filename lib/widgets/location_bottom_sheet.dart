import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/tag_formatter.dart';
import '../screens/report_issue_screen.dart';
import '../screens/upload_page.dart';
import '../utils/location_helper.dart';
import '../utils/share_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../screens/vote_page.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class LocationBottomSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final String title;
  final IconData Function(String, dynamic) iconGetter;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final bool showBackButton;

  const LocationBottomSheet({
    super.key,
    required this.data,
    required this.title,
    required this.iconGetter,
    required this.onClose,
    this.onBack,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);
    
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
              color: isDark ? theme.cardColor : Colors.white,
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
                                  color: isDark ? Colors.blue.shade700.withOpacity(0.2) : theme.primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_up,
                                  color: isDark ? Colors.blue.shade300 : theme.primaryColor,
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
                        color: isDark ? Colors.grey[700] : const Color(0xFFE5E5EA),
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);
    final Map<String, dynamic> tags = data['Tags'] ?? {};
    final List<MapEntry<String, dynamic>> allTags = tags.entries.toList();
    final List<Map<String, dynamic>> images = (data['Images'] as List<dynamic>? ?? [])
      .where((img) => img is Map && img['approved_status'] == true)
      .map<Map<String, dynamic>>((img) => {
        'url': img['image_url'] as String,
        'upload_time': img['image_upload_time'] as String,
      })
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
              if (showBackButton) ...[
                IconButton(
                  icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black87),
                  onPressed: onBack ?? () => Navigator.of(context).pop(),
                  tooltip: 'Back to toilet list',
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black87),
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
                        backgroundColor: isDark ? theme.cardColor : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                          children: [
                            Icon(Icons.directions, color: isDark ? Colors.white : theme.primaryColor),
                            const SizedBox(width: 12),
                            Text(
                              'Select Mode of Travel',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'How would you like to reach the location?',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
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
                                    isDark ? Colors.white : theme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTravelModeButton(
                                    context,
                                    'drive',
                                    Icons.directions_car,
                                    'Drive',
                                    isDark ? Colors.white : Colors.green,
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
                              onTap: () {},
                              child: AlertDialog(
                                backgroundColor: isDark ? theme.cardColor : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: isDark ? Colors.white : theme.primaryColor),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Accessibility Tip',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black,
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
                                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark ? Colors.white.withOpacity(0.2) : Colors.blue.shade100,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.accessibility_new,
                                            color: isDark ? Colors.white : theme.primaryColor,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              'Enable "Wheelchair-accessible" under Trip Options in Google Maps for better routes!',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: isDark ? Colors.white : Colors.blue.shade900,
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
                                        _launchGoogleMaps(context, destLat, destLon, originLat, originLon, choice);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark ? Colors.blue.shade700 : theme.primaryColor,
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
                      return;
                    }

                    _launchGoogleMaps(context, destLat, destLon, originLat, originLon, choice);
                  },
                  icon: Icon(
                    Icons.directions_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: Text(
                    'Get Directions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blue.shade700 : theme.primaryColor,
                    elevation: isDark ? 4 : 2,
                    shadowColor: isDark ? Colors.blue.shade700.withOpacity(0.5) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                          MaterialPageRoute(
                            builder: (_) => UploadPage(venueData: data),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.upload_outlined,
                        color: isDark ? Colors.white : theme.primaryColor,
                        size: 22,
                      ),
                      label: Text(
                        'Upload',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          color: isDark ? Colors.white : theme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : theme.primaryColor,
                        side: BorderSide(
                          color: isDark ? Colors.white.withOpacity(0.3) : theme.primaryColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        backgroundColor: isDark ? Colors.white.withOpacity(0.1) : theme.primaryColor.withOpacity(0.05),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                      icon: Icon(
                        Icons.share_outlined,
                        color: isDark ? Colors.white : theme.primaryColor,
                        size: 22,
                      ),
                      label: Text(
                        'Share',
                        style: TextStyle(
                          color: isDark ? Colors.white : theme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : theme.primaryColor,
                        side: BorderSide(
                          color: isDark ? Colors.white.withOpacity(0.3) : theme.primaryColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        backgroundColor: isDark ? Colors.white.withOpacity(0.1) : theme.primaryColor.withOpacity(0.05),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ReportIssueScreen()),
                        );
                      },
                      icon: Icon(
                        Icons.report_problem_outlined,
                        color: isDark ? Colors.white : theme.primaryColor,
                        size: 22,
                      ),
                      label: Text(
                        'Report',
                        style: TextStyle(
                          color: isDark ? Colors.white : theme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : theme.primaryColor,
                        side: BorderSide(
                          color: isDark ? Colors.white.withOpacity(0.3) : theme.primaryColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        backgroundColor: isDark ? Colors.white.withOpacity(0.1) : theme.primaryColor.withOpacity(0.05),
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
          Divider(height: 1, color: isDark ? Colors.grey[800] : const Color(0xFFE5E5EA)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
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
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                opaque: false,
                                barrierColor: Colors.black.withOpacity(0.95),
                                pageBuilder: (context, animation, secondaryAnimation) => _FullScreenGallery(
                                  images: images,
                                  initialIndex: index,
                                  isDark: isDark,
                                  theme: theme,
                                ),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                              ),
                            );
                          },
                          child: Hero(
                            tag: images[index]['url'],
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark ? Colors.grey[800]! : const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: CachedNetworkImage(
                                      imageUrl: images[index]['url'],
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 200,
                                        height: 200,
                                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        width: 200,
                                        height: 200,
                                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                                        child: const Icon(Icons.error),
                                      ),
                                    ),
                                  ),
                                  // Date overlay
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.7),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Text(
                                        _formatDate(images[index]['upload_time']),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
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
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Vote button moved here
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Normalize the data before passing it to VotePage
                      final normalizedData = {
                        'name': data['Metadata']?['name'] ?? data['Tags']?['name'] ?? 'Unknown Location',
                        'id': data['id'] ?? data['Metadata']?['name'] ?? data['Tags']?['name'] ?? 'Unknown Location',
                        'images': (data['Images'] as List<dynamic>? ?? [])
                          .where((img) => img is Map && img['approved_status'] == true)
                          .map((img) => img['image_url'] as String)
                          .toList(),
                        'tags': data['Tags'] ?? {},
                        'Location_Lat': data['Location_Lat'],
                        'Location_Lon': data['Location_Lon'],
                        'accessibility_type_name': data['Accessibility_Type_Name'],
                      };
                      
                      print('DEBUG - Sending data to VotePage: ${normalizedData['accessibility_type_name']}');
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VotePage(initialLocation: normalizedData),
                        ),
                      );
                    },
                    icon: const Icon(Icons.thumbs_up_down_outlined, color: Colors.white),
                    label: const Text('Vote on Photos', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Divider(height: 1, color: isDark ? Colors.grey[800] : const Color(0xFFE5E5EA)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No attached pictures',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Accessibility features
        if (orderedTags.isNotEmpty) ...[
          Divider(height: 1, color: isDark ? Colors.grey[800] : const Color(0xFFE5E5EA)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accessibility Features',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                ...orderedTags.map((entry) {
                  final key = entry.key.replaceAll('_', ' ').split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
                  final value = entry.value.toString().toLowerCase();

                  Color valueColor;
                  String displayValue;

                  if (value == 'yes') {
                    valueColor = isDark ? Colors.green.shade300 : Colors.green;
                    displayValue = 'Available';
                  } else if (value == 'no') {
                    valueColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
                    displayValue = 'Unavailable';
                  } else {
                    valueColor = isDark ? Colors.blue.shade300 : theme.primaryColor;
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
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              key,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayValue,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: valueColor,
                            ),
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? color.withOpacity(0.4) : color.withOpacity(0.3),
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

// Move _formatDate here so it is accessible to all widgets in this file
String _formatDate(String? dateStr) {
  if (dateStr == null) return 'Date unknown';
  try {
    final dateTime = DateTime.parse(dateStr);
    return 'Uploaded 	${dateTime.day}/${dateTime.month}/${dateTime.year}';
  } catch (e) {
    return 'Date unknown';
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;
  final bool isDark;
  final ThemeData theme;

  const _FullScreenGallery({
    required this.images,
    required this.initialIndex,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          alignment: Alignment.center,
          children: [
            PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: widget.images.length,
              onPageChanged: _onPageChanged,
              builder: (context, index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(widget.images[index]['url']),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2.5,
                  heroAttributes: PhotoViewHeroAttributes(tag: widget.images[index]['url']),
                );
              },
              scrollPhysics: const BouncingScrollPhysics(),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
            // Close button
            Positioned(
              right: 16,
              top: 40,
              child: SafeArea(
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ),
            ),
            // Image index indicator
            Positioned(
              bottom: 60,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // Caption (upload date)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatDate(widget.images[_currentIndex]['upload_time']),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}