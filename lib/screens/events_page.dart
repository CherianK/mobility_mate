import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<dynamic> events = [];
  bool isLoading = true;
  String errorMessage = '';

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
      // Humanitix API key
      const apiKey = '70cd9168ac4dc1c7f2b89b0e312a761ec679dd17c0747a4d4389dc118d2647bd60847191e1468129a128ddf0814ba8c27c9b59cbf57bf13d3a286e84aee97a360f840f41d4bc218b4973d11aa90c5658589821f861e42c6547670f81b7695bb366af4da18f24c2ab1cceff0b129288'; // Replace with your actual Humanitix API key
      
      // Humanitix API endpoint for Melbourne events
      final response = await http.get(
        Uri.parse(
          'https://api.humanitix.com/v1/events'
          '?location=Melbourne'
          '&accessibility=wheelchair'
          '&sort=date'
          '&limit=20'
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          events = data['events'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load events: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Events'),
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
                        final venue = event['venue'] ?? {};
                        
                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Event image
                              if (event['imageUrl'] != null)
                                Image.network(
                                  event['imageUrl'],
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Event name
                                    Text(
                                      event['name'] ?? 'Untitled Event',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    // Date and time
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatDate(event['startDate']),
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                        const SizedBox(width: 16),
                                        const Icon(Icons.access_time, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTime(event['startDate']),
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Venue
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 16),
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
                                    // Description
                                    if (event['description'] != null)
                                      Text(
                                        event['description'],
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    const SizedBox(height: 16),
                                    // Accessibility badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.accessible,
                                            color: Colors.blue,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Wheelchair Accessible',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: Colors.blue),
                                          ),
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
} 