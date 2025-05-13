import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEvents,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Wheelchair Accessible Events Available',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please check back later for new events',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          expandedHeight: 120,
                          floating: true,
                          pinned: false,
                          backgroundColor: const Color(0xFFE6F3FF),
                          flexibleSpace: FlexibleSpaceBar(
                            background: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Wheelchair Accessible Events in Melbourne',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Sort By:',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () => _handleSort('date'),
                                        icon: Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color: sortBy == 'date' 
                                              ? Colors.white 
                                              : Theme.of(context).primaryColor,
                                        ),
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('Date'),
                                            if (sortBy == 'date') ...[
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
                                          backgroundColor: sortBy == 'date' 
                                              ? Theme.of(context).primaryColor 
                                              : Colors.white,
                                          foregroundColor: sortBy == 'date' 
                                              ? Colors.white 
                                              : Theme.of(context).primaryColor,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: const Size(0, 32),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          if (currentPosition != null) {
                                            _handleSort('distance');
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Please enable location services to sort by distance'),
                                              ),
                                            );
                                          }
                                        },
                                        icon: Icon(
                                          Icons.near_me,
                                          size: 16,
                                          color: sortBy == 'distance' 
                                              ? Colors.white 
                                              : Theme.of(context).primaryColor,
                                        ),
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('Distance from me'),
                                            if (sortBy == 'distance') ...[
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
                                          backgroundColor: sortBy == 'distance' 
                                              ? Theme.of(context).primaryColor 
                                              : Colors.white,
                                          foregroundColor: sortBy == 'distance' 
                                              ? Colors.white 
                                              : Theme.of(context).primaryColor,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: const Size(0, 32),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index >= filteredEvents.length) return null;
                              final event = filteredEvents[index];
                              final venue = event['_embedded']?['venues']?[0] ?? {};
                              final images = event['images'] ?? [];
                              
                              return Card(
                                margin: const EdgeInsets.all(8),
                                elevation: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Event images
                                    if (images != null && images.isNotEmpty && images[0] != null && images[0]['url'] != null)
                                      Image.network(
                                        images[0]['url'],
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 200,
                                            color: Colors.grey[300],
                                            child: const Center(
                                              child: Icon(Icons.image_not_supported, size: 50),
                                            ),
                                          );
                                        },
                                      )
                                    else
                                      Container(
                                        height: 200,
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: Icon(Icons.image_not_supported, size: 50),
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
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          
                                          // Segment type
                                          if (event['segment']?['name'] != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                event['segment']['name'],
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: Colors.purple,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 12),
                                          
                                          // Venue
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on, size: 20, color: Colors.grey),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  venue['name'] ?? 'Venue not specified',
                                                  style: Theme.of(context).textTheme.bodyMedium,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          
                                          // Date and Time
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                                              const SizedBox(width: 8),
                                              Text(
                                                _getLocalDate(event['dates']),
                                                style: Theme.of(context).textTheme.bodyMedium,
                                              ),
                                              const SizedBox(width: 16),
                                              const Icon(Icons.access_time, size: 20, color: Colors.grey),
                                              const SizedBox(width: 8),
                                              Text(
                                                _getLocalTime(event['dates']),
                                                style: Theme.of(context).textTheme.bodyMedium,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          
                                          // Event info
                                          if (event['info'] != null) ...[
                                            Text(
                                              'About',
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _cleanEventInfo(event['info']),
                                                  style: Theme.of(context).textTheme.bodyMedium,
                                                  maxLines: expandedDescriptions.contains(index) ? null : 3,
                                                  overflow: expandedDescriptions.contains(index) ? null : TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
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
                                                  child: Text(
                                                    expandedDescriptions.contains(index) ? 'See less' : 'See more',
                                                    style: TextStyle(
                                                      color: Theme.of(context).primaryColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                          
                                          // Accessibility info button
                                          if (event['accessibility'] != null)
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: () => _showAccessibilityInfo(context, event),
                                                icon: const Icon(Icons.accessible),
                                                label: const Text('View Accessibility Information'),
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          
                                          // Ticketmaster button
                                          if (event['url'] != null)
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: () => _launchUrl(event['url']),
                                                icon: const Icon(Icons.shopping_cart),
                                                label: const Text('View on Ticketmaster'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Theme.of(context).primaryColor,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
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
                        ),
                      ],
                    ),
    );
  }
}