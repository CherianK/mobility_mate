import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_app_bar.dart';
import '../providers/theme_provider.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<dynamic> events = [];
  List<dynamic> filteredEvents = [];
  bool isLoading = true;
  String errorMessage = '';
  Set<int> expandedDescriptions = {};
  String sortBy = 'date'; // 'date', 'location', or 'distance'
  bool isAscending = true;
  Position? currentPosition;

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      currentPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      print('DEBUG: Error getting location: $e');
      setState(() {
        errorMessage = 'Unable to get current location. Please enable location services.';
      });
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to kilometers
  }

  void _sortEvents() {
    setState(() {
      if (sortBy == 'date') {
        filteredEvents.sort((a, b) {
          final dateA = DateTime.parse(a['dates']?['start']?['dateTime'] ?? '');
          final dateB = DateTime.parse(b['dates']?['start']?['dateTime'] ?? '');
          return isAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        });
      } else if (sortBy == 'distance' && currentPosition != null) {
        filteredEvents.sort((a, b) {
          final venueA = a['_embedded']?['venues']?[0];
          final venueB = b['_embedded']?['venues']?[0];
          
          if (venueA == null || venueB == null) return 0;
          
          final latA = double.tryParse(venueA['location']?['latitude']?.toString() ?? '0') ?? 0;
          final lonA = double.tryParse(venueA['location']?['longitude']?.toString() ?? '0') ?? 0;
          final latB = double.tryParse(venueB['location']?['latitude']?.toString() ?? '0') ?? 0;
          final lonB = double.tryParse(venueB['location']?['longitude']?.toString() ?? '0') ?? 0;
          
          final distanceA = _calculateDistance(
            currentPosition!.latitude,
            currentPosition!.longitude,
            latA,
            lonA,
          );
          
          final distanceB = _calculateDistance(
            currentPosition!.latitude,
            currentPosition!.longitude,
            latB,
            lonB,
          );
          
          return isAscending ? distanceA.compareTo(distanceB) : distanceB.compareTo(distanceA);
        });
      }
    });
  }

  void _handleSort(String newSortBy) {
    setState(() {
      if (sortBy == newSortBy) {
        // Toggle ascending/descending if clicking the same sort button
        isAscending = !isAscending;
      } else {
        // Reset to ascending when changing sort type
        sortBy = newSortBy;
        isAscending = true;
      }
      _sortEvents();
    });
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation().then((_) {
      _fetchEvents().then((_) {
        sortBy = 'date';
        _sortEvents();
      });
    });
  }

  Future<void> _fetchEvents() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final response = await http.post(
        Uri.parse('https://mobility-mate.onrender.com/events'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "postalcode": "3000",
          "radius": 80,
          "unit": "km",
          "countryCode": "AU",
          "stateCode": "VIC",
          "startDateTime": tomorrow.toIso8601String(),
          "endDateTime": now.add(const Duration(days: 180)).toIso8601String(),
          "size": 100
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('The connection has timed out, Please try again!');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> allEvents = [];
        
        if (data is List) {
          allEvents = data;
        } else {
          allEvents = data['events'] ?? data['data'] ?? data['_embedded']?['events'] ?? [];
        }

        // Filter for wheelchair-accessible events
        final accessibleEvents = allEvents.where((event) {
          final accessibility = event['accessibility'];
          return accessibility != null && 
                 (accessibility['info'] != null || 
                  accessibility['adaCustomCopy'] != null);
        }).toList();

        setState(() {
          events = accessibleEvents;
          filteredEvents = accessibleEvents;
          isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          errorMessage = 'Events service is currently unavailable. Please try again later.';
          isLoading = false;
        });
      } else if (response.statusCode == 500) {
        setState(() {
          errorMessage = 'Server error. Please try again later.';
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load events. Please check your connection and try again.';
          isLoading = false;
        });
      }
    } on TimeoutException {
      setState(() {
        errorMessage = 'Connection timed out. Please check your internet connection and try again.';
        isLoading = false;
      });
    } on SocketException {
      setState(() {
        errorMessage = 'No internet connection. Please check your network settings and try again.';
        isLoading = false;
      });
    } catch (e) {
      print('DEBUG: Error fetching events: $e');
      setState(() {
        errorMessage = 'An unexpected error occurred. Please try again later.';
        isLoading = false;
      });
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Date not available';
    }
  }

  String _formatTime(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final hour = date.hour;
      final minute = date.minute;
      final period = hour < 12 ? 'AM' : 'PM';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return 'Time not available';
    }
  }

  String _getLocalDate(Map<String, dynamic>? dates) {
    if (dates == null) return 'Date not available';
    return dates['localDate'] ?? _formatDate(dates['start']?['dateTime'] ?? '');
  }

  String _getLocalTime(Map<String, dynamic>? dates) {
    if (dates == null) return 'Time not available';
    
    // Try to get the time from various possible fields in order of preference
    final time = dates['start']?['localTime'] ?? 
                dates['start']?['time'] ?? 
                dates['localTime'] ?? 
                dates['time'];
    
    if (time != null) {
      return time;
    }
    
    // If no time field is found, try to format the dateTime
    return _formatTime(dates['start']?['dateTime'] ?? '');
  }

  String _cleanEventInfo(String? info) {
    if (info == null) return '';
    
    // Split the text by newlines
    final lines = info.split('\n');
    
    // Find the line containing "Finish - X:XXpm"
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains(RegExp(r'Finish\s*-\s*\d{1,2}:\d{2}\s*[AaPp][Mm]'))) {
        // Get the text after "Finish - X:XXpm" in the same line
        final finishTimeMatch = RegExp(r'Finish\s*-\s*\d{1,2}:\d{2}\s*[AaPp][Mm]').firstMatch(line);
        if (finishTimeMatch != null) {
          final textAfterFinish = line.substring(finishTimeMatch.end).trim();
          // If there's text after the finish time in the same line, include it
          if (textAfterFinish.isNotEmpty) {
            return [textAfterFinish, ...lines.skip(i + 1)].join('\n').trim();
          }
        }
        // If no text after finish time in the same line, start from next line
        return lines.skip(i + 1).join('\n').trim();
      }
    }
    
    // If no finish time found, return the original text
    return info;
  }

  void _showAccessibilityInfo(BuildContext context, Map<String, dynamic> event) {
    final venues = event['_embedded']?['venues'] as List<dynamic>?;
    final accessibleSeatingDetail = venues != null && venues.isNotEmpty
        ? (venues[0]['accessibleSeatingDetail'] ?? '')
        : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Centered drag handle with animation
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated indicator
                      Positioned(
                        top: 2,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(seconds: 3),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: (1 - value).clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, 6 * value),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
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
                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Accessibility Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if ((event['accessibility']?['info'] ?? '').toString().trim().isNotEmpty) ...[
                  Text(
                    'General Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event['accessibility']['info'],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                ],
                if ((event['accessibility']?['adaCustomCopy'] ?? '').toString().trim().isNotEmpty) ...[
                  Text(
                    'Additional Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event['accessibility']['adaCustomCopy'],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                ],
                if (accessibleSeatingDetail.toString().trim().isNotEmpty) ...[
                  Text(
                    'Accessible Seating Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    accessibleSeatingDetail,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshEvents() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    
    await _getCurrentLocation();
    await _fetchEvents();
    if (mounted) {
      setState(() {
        sortBy = 'date';
        _sortEvents();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? Colors.blue.shade900 : Colors.blue.shade600,
      body: Container(
        color: isDark ? Colors.grey[900] : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header with refresh button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark 
                    ? [Colors.blue, Colors.blue]
                    : [Colors.blue.shade600, Colors.blue.shade500],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 24,
                  20,
                  24,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.event_available,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Wheelchair Accessible',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Events in Melbourne',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                        ),
                        onPressed: isLoading ? null : _refreshEvents,
                        tooltip: 'Refresh Events',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Rest of the content
            if (isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (errorMessage.isNotEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red[400],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshEvents,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (events.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No events found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    // Fixed Sort by section
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : const Color(0xFFE6F3FF),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sort,
                              size: 18,
                              color: isDark ? Colors.white70 : Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sort By:',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: isDark ? Colors.white : Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildSortButton(
                              context,
                              'date',
                              Icons.calendar_today,
                              'Date',
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildSortButton(
                              context,
                              'distance',
                              Icons.near_me,
                              'Distance',
                              isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Events list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredEvents.length,
                        itemBuilder: (context, index) {
                          if (index >= filteredEvents.length) return null;
                          final event = filteredEvents[index];
                          final venue = event['_embedded']?['venues']?[0] ?? {};
                          final images = event['images'] ?? [];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Event images
                                if (images != null && images.isNotEmpty && images[0] != null && images[0]['url'] != null)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    child: Image.network(
                                      images[0]['url'],
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 200,
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.image_not_supported,
                                              size: 50,
                                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                else
                                  Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 50,
                                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Event name
                                      Text(
                                        event['name'] ?? 'Untitled Event',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Segment type
                                      if (event['segment']?['name'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.purple.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            event['segment']['name'],
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.purple,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 16),
                                      
                                      // Venue
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey[800] : Colors.grey[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.location_on,
                                              size: 20,
                                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              venue['name'] ?? 'Venue not specified',
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: isDark ? Colors.white : Colors.grey[800],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Date and Time
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey[800] : Colors.grey[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.calendar_today,
                                              size: 20,
                                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _getLocalDate(event['dates']),
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: isDark ? Colors.white : Colors.grey[800],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey[800] : Colors.grey[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.access_time,
                                              size: 20,
                                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _getLocalTime(event['dates']),
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: isDark ? Colors.white : Colors.grey[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Event info
                                      if (event['info'] != null) ...[
                                        Text(
                                          'About',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.grey[800] : Colors.grey[50],
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _cleanEventInfo(event['info']),
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: isDark ? Colors.white70 : Colors.grey[800],
                                                  height: 1.5,
                                                ),
                                                maxLines: expandedDescriptions.contains(index) ? null : 3,
                                                overflow: expandedDescriptions.contains(index) ? null : TextOverflow.ellipsis,
                                              ),
                                              if (_cleanEventInfo(event['info']).length > 150) ...[
                                                const SizedBox(height: 8),
                                                TextButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      if (expandedDescriptions.contains(index)) {
                                                        expandedDescriptions.remove(index);
                                                      } else {
                                                        expandedDescriptions.add(index);
                                                      }
                                                    });
                                                  },
                                                  style: TextButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    minimumSize: const Size(0, 0),
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  child: Text(
                                                    expandedDescriptions.contains(index) ? 'Show less' : 'Read more',
                                                    style: TextStyle(
                                                      color: Theme.of(context).primaryColor,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 16),
                                      
                                      // Action buttons
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _showAccessibilityInfo(context, event),
                                              icon: const Icon(Icons.info_outline),
                                              label: const Text('Accessibility Info'),
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          if (event['url'] != null)
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _launchUrl(event['url']),
                                                icon: const Icon(Icons.open_in_new),
                                                label: const Text('Book Tickets'),
                                                style: ElevatedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton(
    BuildContext context,
    String type,
    IconData icon,
    String label,
    bool isDark,
  ) {
    final isSelected = sortBy == type;
    return ElevatedButton.icon(
      onPressed: () {
        if (type == 'distance' && currentPosition == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable location services to sort by distance'),
            ),
          );
          return;
        }
        _handleSort(type);
      },
      icon: Icon(
        icon,
        size: 16,
        color: isSelected 
            ? Colors.white 
            : (isDark ? Colors.white70 : Theme.of(context).primaryColor),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isSelected) ...[
            const SizedBox(width: 4),
            Icon(
              isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: Colors.white,
            ),
          ],
        ],
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected 
            ? Theme.of(context).primaryColor 
            : (isDark ? Colors.grey[800] : Colors.white),
        foregroundColor: isSelected 
            ? Colors.white 
            : (isDark ? Colors.white70 : Theme.of(context).primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: isSelected ? 2 : 0,
      ),
    );
  }
}