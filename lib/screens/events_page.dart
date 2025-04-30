import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;

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
      // Mock data for testing
      final mockData = {
        '_embedded': {
          'events': [
            {
              'name': 'Melbourne Comedy Festival',
              'dates': {
                'start': {
                  'dateTime': '2024-04-01T19:30:00Z'
                }
              },
              '_embedded': {
                'venues': [
                  {
                    'name': 'Melbourne Town Hall'
                  }
                ]
              },
              'images': [
                {
                  'url': 'https://images.unsplash.com/photo-1540039155733-5bb30b53aa14?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80'
                }
              ],
              'priceRanges': [
                {
                  'min': 25.00
                }
              ]
            },
            {
              'name': 'Australian Open 2024',
              'dates': {
                'start': {
                  'dateTime': '2024-01-15T10:00:00Z'
                }
              },
              '_embedded': {
                'venues': [
                  {
                    'name': 'Melbourne Park'
                  }
                ]
              },
              'images': [
                {
                  'url': 'https://images.unsplash.com/photo-1622279457486-62dcc4a431d6?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80'
                }
              ],
              'priceRanges': [
                {
                  'min': 45.00
                }
              ]
            },
            {
              'name': 'Melbourne Food & Wine Festival',
              'dates': {
                'start': {
                  'dateTime': '2024-03-15T11:00:00Z'
                }
              },
              '_embedded': {
                'venues': [
                  {
                    'name': 'Federation Square'
                  }
                ]
              },
              'images': [
                {
                  'url': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80'
                }
              ],
              'priceRanges': [
                {
                  'min': 35.00
                }
              ]
            }
          ]
        }
      };

      setState(() {
        events = mockData['_embedded']?['events'] ?? [];
        isLoading = false;
      });
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
                        final venue = event['_embedded']?['venues']?[0] ?? {};
                        final images = event['images'] ?? [];
                        final imageUrl = images.isNotEmpty ? images[0]['url'] : null;
                        
                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Event image
                              if (imageUrl != null)
                                Image.network(
                                  imageUrl,
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
                                          _formatDate(event['dates']?['start']?['dateTime'] ?? ''),
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                        const SizedBox(width: 16),
                                        const Icon(Icons.access_time, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTime(event['dates']?['start']?['dateTime'] ?? ''),
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
                                    // Price range
                                    if (event['priceRanges'] != null && event['priceRanges'].isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.attach_money,
                                              color: Colors.green,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'From \$${event['priceRanges'][0]['min']}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(color: Colors.green),
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