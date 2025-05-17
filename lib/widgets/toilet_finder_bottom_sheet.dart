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
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        width: 1.0,
                      ),
                    ),
                    color: isDark ? Colors.grey[900] : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline, 
                        size: 24, 
                        color: isDark ? Colors.lightBlueAccent : theme.primaryColor
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Public Toilets Near You',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
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
                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _displayedToilets.isEmpty
                          ? _buildNoToiletsContent(context)
                          : _buildToiletList(context, scrollController),
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
  
  Widget _buildToiletList(BuildContext context, ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _displayedToilets.length,
      itemBuilder: (context, index) {
        final toilet = _displayedToilets[index];
        return _buildToiletItem(context, toilet);
      },
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
      margin: const EdgeInsets.only(bottom: 16),
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
          // Navigate to this toilet on the map
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
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(
                color: Colors.grey,
                thickness: 0.5,
              ),
              const SizedBox(height: 8),
              // Display important features
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFeatureItem(
                    context,
                    'Wheelchair',
                    Icons.wheelchair_pickup,
                    tags['Wheelchair'] == 'yes',
                    tags['Wheelchair'] == 'limited',
                  ),
                  const SizedBox(width: 40),
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