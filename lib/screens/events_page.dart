import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<dynamic> events = [];
  bool isLoading = true;
  String errorMessage = '';

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final now = DateTime.now();
      final response = await http.post(
        Uri.parse('https://mobility-mate.onrender.com/events'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "apikey": "QSJrHiQFNzBGD9iq7RYhgrnrbDuNqUCd",
          "postalcode": "3000",
          "radius": 15,
          "unit": "km",
          "countryCode": "AU",
          "stateCode": "VIC",
          "startDateTime": now.toIso8601String(),
          "endDateTime": now.add(const Duration(days: 180)).toIso8601String()
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('The connection has timed out, Please try again!');
        },
      );

      print('DEBUG: Response Status Code: ${response.statusCode}');
      print('DEBUG: Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG: Full Response Data: $data');
        print('DEBUG: Response Data Type: ${data.runtimeType}');
        print('DEBUG: Response Data Keys: ${data.keys}');
        
        // Check if data is directly an array
        if (data is List) {
          setState(() {
            events = data;
            print('DEBUG: Events List Length: ${events.length}');
            if (events.isNotEmpty) {
              print('DEBUG: First Event: ${events[0]}');
            }
            isLoading = false;
          });
        } else {
          // If data is an object, try to find the events array
          final eventsList = data['events'] ?? data['data'] ?? data['_embedded']?['events'] ?? [];
          setState(() {
            events = eventsList is List ? eventsList : [];
            print('DEBUG: Events List Length: ${events.length}');
            if (events.isNotEmpty) {
              print('DEBUG: First Event: ${events[0]}');
            }
            isLoading = false;
          });
        }
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
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
    return dates['localTime'] ?? _formatTime(dates['start']?['dateTime'] ?? '');
  }

  void _showAccessibilityInfo(BuildContext context, Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accessibility Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (event['accessibility']?['info'] != null)
              Text(
                'Accessibility Info: ${event['accessibility']['info']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (event['accessibility']?['adaCustomCopy'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Additional Info: ${event['accessibility']['adaCustomCopy']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
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
                  ? const Center(child: Text('No events found'))
                  : ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        final venue = event['_embedded']?['venues']?[0] ?? {};
                        final images = event['images'] ?? [];
                        
                        return Card(
                          margin: const EdgeInsets.all(8),
                          elevation: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Event images
                              if (images.isNotEmpty)
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
                                      Text(
                                        event['info'],
                                        style: Theme.of(context).textTheme.bodyMedium,
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
    );
  }
}