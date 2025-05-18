import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/marker_type.dart';

class ToiletFinderBottomSheet extends StatefulWidget {
  final geo.Position userPosition;
  final List<Map<String, dynamic>> nearbyToilets;
  
  const ToiletFinderBottomSheet({
    super.key,
    required this.userPosition,
    required this.nearbyToilets,
  });

  @override
  State<ToiletFinderBottomSheet> createState() => _ToiletFinderBottomSheetState();
}

class _ToiletFinderBottomSheetState extends State<ToiletFinderBottomSheet> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _displayedToilets = [];
  
  @override
  void initState() {
    super.initState();
    _displayedToilets = widget.nearbyToilets;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);
    
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.extent <= 0.22) {
          Navigator.of(context).maybePop();
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
              boxShadow: isDark ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ] : null,
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
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[500] : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                  ],
                ),
                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _displayedToilets.isEmpty
                          ? _buildNoToiletsContent(context)
                          : ListView(
                              controller: scrollController,
                              padding: EdgeInsets.zero,
                              children: [
                                // Title and close button
                Container(
                                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 16.0),
                  decoration: BoxDecoration(
                                    color: isDark ? theme.cardColor : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark ? theme.primaryColor.withOpacity(0.2) : theme.primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.wc_outlined,
                        size: 24, 
                                          color: isDark ? Colors.lightBlueAccent : theme.primaryColor,
                                        ),
                      ),
                                      const SizedBox(width: 16),
                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                          'Public Toilets Near You',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_displayedToilets.length} ${_displayedToilets.length == 1 ? 'toilet' : 'toilets'} found nearby',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black87),
                        onPressed: () {
                          if (mounted && Navigator.of(context).canPop()) {
                            Navigator.of(context).maybePop();
                          }
                        },
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Nearest Toilets',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ..._displayedToilets.map((toilet) => Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _buildToiletItem(context, toilet),
                                      )).toList(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildNoToiletsContent(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.not_listed_location,
              size: 64,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No wheelchair-accessible toilets found nearby',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find any wheelchair-accessible toilets near your current location.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildToiletItem(BuildContext context, Map<String, dynamic> toilet) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);
    final tags = toilet['Tags'] as Map<String, dynamic>? ?? {};
    
    // Check for wheelchair accessibility
    final wheelchairValue = tags['Wheelchair']?.toString().toLowerCase() ?? '';
    final isWheelchairAccessible = wheelchairValue == 'yes' || wheelchairValue == 'limited';
    
    // Check for parking accessibility
    final parkingValue = tags['Parking_Accessible']?.toString().toLowerCase() ?? '';
    final hasParkingAccess = parkingValue == 'yes';
    
    // Format distance to show only 1 decimal place
    final distance = (toilet['distance'] as double).toStringAsFixed(1);
    
    return Card(
      elevation: isDark ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark 
            ? BorderSide(color: theme.primaryColor.withOpacity(0.3), width: 1)
            : BorderSide.none,
      ),
      color: isDark ? Color(0xFF2A2A2A) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _navigateToToilet(toilet);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isWheelchairAccessible 
                          ? (isDark ? theme.primaryColor.withOpacity(0.3) : theme.primaryColor.withOpacity(0.1))
                          : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: isDark ? Border.all(color: Colors.grey[700]!, width: 1) : null,
                    ),
                    child: Icon(
                      Icons.wc_outlined,
                      color: isWheelchairAccessible 
                          ? (isDark ? Colors.lightBlueAccent : theme.primaryColor)
                          : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getToiletName(toilet),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$distance km away',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey[300] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                    Icons.chevron_right,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(
                color: Colors.grey,
                thickness: 0.5,
              ),
              const SizedBox(height: 12),
              // Display important features
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFeatureItem(
                    context,
                    'Wheelchair',
                    Icons.wheelchair_pickup,
                    tags['Wheelchair'] == 'yes',
                    tags['Wheelchair'] == 'limited',
                  ),
                  _buildFeatureItem(
                    context,
                    'Accessible Parking',
                    Icons.local_parking,
                    tags['Parking_Accessible'] == 'yes',
                    false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getToiletName(Map<String, dynamic> toilet) {
    // Try to find a name from various possible fields
    final tags = toilet['Tags'] as Map<String, dynamic>? ?? {};
    final metadata = toilet['Metadata'] as Map<String, dynamic>? ?? {};
    
    // Check various name fields
    for (final field in ['name', 'Name', 'title', 'Title']) {
      final name = tags[field] ?? metadata[field];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }
    
    // If no name found, generate one based on location or id
    final id = toilet['id']?.toString() ?? '';
    return 'Public Toilet ${id.isNotEmpty ? '#$id' : ''}';
  }
  
  void _navigateToToilet(Map<String, dynamic> toilet) {
    // Get the toilet location data before popping
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop({
        'action': 'show_details',
        'toilet_data': toilet,
      });
    }
  }
  
  Widget _buildFeatureItem(
    BuildContext context,
    String label,
    IconData icon,
    bool isAvailable,
    bool isLimited,
  ) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);
    
    Color iconColor;
    if (isAvailable) {
      iconColor = isDark ? Colors.lightBlueAccent : theme.primaryColor;
    } else if (isLimited) {
      iconColor = Colors.orange;
    } else {
      iconColor = isDark ? Colors.grey[400]! : Colors.grey[400]!;
    }
    
    String displayValue;
    if (isAvailable) {
      displayValue = 'Available';
    } else if (isLimited) {
      displayValue = 'Limited';
    } else {
      displayValue = 'Unavailable';
    }
    
    return Column(
      children: [
        Icon(
          icon,
          size: 22,
          color: iconColor,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          displayValue,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isAvailable || isLimited ? FontWeight.bold : FontWeight.normal,
            color: isAvailable 
                ? (isDark ? Colors.greenAccent : Colors.green)
                : isLimited 
                    ? (isDark ? Colors.orangeAccent : Colors.orange)
                    : isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
} 