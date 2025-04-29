import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/mapbox_config.dart';
import '../models/marker_type.dart';
import '../utils/icon_utils.dart';
import '../screens/search_page.dart';

class VotePage extends StatefulWidget {
  const VotePage({super.key});

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  Map<String, dynamic>? selectedLocation;
  Map<String, List<Map<String, dynamic>>> locationPhotos = {};
  Map<String, Map<String, Map<String, int>>> locationPhotoVotes = {};
  Map<String, int> currentPhotoIndices = {};

  void _showLocationDetails(Map<String, dynamic> location) {
    final locationId = location['id'] ?? location['name'];
    setState(() {
      selectedLocation = location;
      // Initialize photos for this location if not already present
      if (!locationPhotos.containsKey(locationId)) {
        locationPhotos[locationId] = [
          {
            'id': '${locationId}_1', 
            'url': 'https://mobility-mate.s3.ap-southeast-2.amazonaws.com/photos/${locationId}_1.jpg',
            'uploadDate': '2024-03-15T14:30:00Z',
          },
          {
            'id': '${locationId}_2', 
            'url': 'https://mobility-mate.s3.ap-southeast-2.amazonaws.com/photos/${locationId}_2.jpg',
            'uploadDate': '2024-03-14T09:15:00Z',
          },
          {
            'id': '${locationId}_3', 
            'url': 'https://mobility-mate.s3.ap-southeast-2.amazonaws.com/photos/${locationId}_3.jpg',
            'uploadDate': '2024-03-13T16:45:00Z',
          },
        ];
        // Initialize votes for this location if not already present
        if (!locationPhotoVotes.containsKey(locationId)) {
          locationPhotoVotes[locationId] = {};
          // Initialize votes for each photo
          for (var photo in locationPhotos[locationId]!) {
            locationPhotoVotes[locationId]![photo['id']] = {
              'accurate': 0,
              'inaccurate': 0,
            };
          }
        }
        // Initialize current photo index for this location
        currentPhotoIndices[locationId] = 0;
      }
    });
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown date';
    }
  }

  void _voteOnPhoto(String photoId, bool isAccurate) {
    if (selectedLocation == null) return;
    
    final locationId = selectedLocation!['id'] ?? selectedLocation!['name'];
    final currentVotes = locationPhotoVotes[locationId] ?? {};
    final photoVotes = currentVotes[photoId] ?? {'accurate': 0, 'inaccurate': 0};
    
    setState(() {
      // If the user clicks the same vote again, remove their vote
      if (photoVotes[isAccurate ? 'accurate' : 'inaccurate']! > 0) {
        photoVotes[isAccurate ? 'accurate' : 'inaccurate'] = 0;
      } else {
        // Remove any existing vote of the other type
        photoVotes[isAccurate ? 'inaccurate' : 'accurate'] = 0;
        // Add the new vote
        photoVotes[isAccurate ? 'accurate' : 'inaccurate'] = 1;
      }
      
      // Update the votes for this photo
      currentVotes[photoId] = photoVotes;
      locationPhotoVotes[locationId] = currentVotes;
    });
  }

  MarkerType? _determineLocationType(Map<String, dynamic> location) {
    // Debug logging to see the location data
    debugPrint('Location data: ${location.toString()}');
    
    // Check if it's a local location
    if (location['isLocal'] == true) {
      final type = location['type']?.toString().toLowerCase() ?? '';
      
      if (type == 'hospital') {
        debugPrint('Identified as hospital: ${location['name']}');
        return MarkerType.hospital;
      }
      
      final name = location['name'].toString().toLowerCase();
      final locationType = location['Type']?.toString().toLowerCase() ?? '';
      
      // Check for tram-related keywords in both name and type
      if (name.contains('tram') || 
          name.contains('light rail') || 
          name.contains('lrt') ||
          name.contains('streetcar') ||
          name.contains('tram stop') ||
          locationType.contains('tram') ||
          locationType.contains('light rail') ||
          locationType.contains('lrt') ||
          // Check for route and stop number pattern
          RegExp(r'route\s+\d+:\s*stop\s+\d+').hasMatch(name) ||
          RegExp(r'route\s+\d+').hasMatch(name) ||
          RegExp(r'stop\s+\d+').hasMatch(name)) {
        debugPrint('Identified as tram station: $name');
        return MarkerType.tram;
      }
      debugPrint('Identified as train station: $name');
      return MarkerType.train;
    }
    
    // For Mapbox results, check the place type and name
    final placeType = location['place_type']?.toString().toLowerCase() ?? '';
    final name = location['name'].toString().toLowerCase();
    final properties = location['properties'] as Map<String, dynamic>? ?? {};
    final category = properties['category']?.toString().toLowerCase() ?? '';
    
    if (placeType.contains('toilet') || placeType.contains('restroom')) {
      return MarkerType.toilet;
    } else if (placeType.contains('hospital') || 
               placeType.contains('medical') ||
               name.contains('hospital') ||
               name.contains('medical') ||
               category.contains('hospital') ||
               category.contains('medical')) {
      return MarkerType.hospital;
    } else if (placeType.contains('tram') || 
               placeType.contains('light rail') || 
               placeType.contains('lrt') ||
               name.contains('tram') || 
               name.contains('light rail') || 
               name.contains('lrt') ||
               name.contains('streetcar') ||
               name.contains('tram stop') ||
               category.contains('tram') ||
               category.contains('light rail') ||
               category.contains('lrt') ||
               // Check for route and stop number pattern
               RegExp(r'route\s+\d+:\s*stop\s+\d+').hasMatch(name) ||
               RegExp(r'route\s+\d+').hasMatch(name) ||
               RegExp(r'stop\s+\d+').hasMatch(name)) {
      debugPrint('Identified as tram station (Mapbox): $name');
      return MarkerType.tram;
    }
    
    debugPrint('Defaulting to train station: $name');
    return MarkerType.train;
  }

  Widget _buildLocationDetails() {
    if (selectedLocation == null) return const SizedBox.shrink();

    final locationId = selectedLocation!['id'] ?? selectedLocation!['name'];
    final currentPhotos = locationPhotos[locationId] ?? [];
    final currentVotes = locationPhotoVotes[locationId] ?? {};
    final currentPhotoIndex = currentPhotoIndices[locationId] ?? 0;

    // Determine location type and icon
    final locationType = _determineLocationType(selectedLocation!);
    final iconGetter = locationType?.iconGetter ?? getTrainIcon;
    final displayName = locationType?.displayName ?? 'Location';

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location name and type
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: locationType?.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  locationType?.iconName == 'toilet' ? Icons.wc :
                  locationType?.iconName == 'rail' ? Icons.train :
                  locationType?.iconName == 'rail-light' ? Icons.tram :
                  locationType?.iconName == 'hospital' ? Icons.local_hospital :
                  Icons.location_on,
                  color: locationType?.iconName == 'toilet' ? Colors.blue :
                         locationType?.iconName == 'rail' ? Colors.blue :
                         locationType?.iconName == 'rail-light' ? Colors.blue :
                         locationType?.iconName == 'hospital' ? Colors.blue :
                         Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedLocation!['Name'] ?? selectedLocation!['name'],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      locationType == MarkerType.train ? 'Train Station' :
                      locationType == MarkerType.tram ? 'Tram Station' :
                      locationType == MarkerType.toilet ? 'Toilet' :
                      locationType == MarkerType.hospital ? 'Hospital' :
                      'Location',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: locationType?.iconName == 'toilet' ? Colors.blue :
                               locationType?.iconName == 'rail' ? Colors.blue :
                               locationType?.iconName == 'rail-light' ? Colors.blue :
                               locationType?.iconName == 'hospital' ? Colors.purple :
                               Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Photos section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Photos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'How accurate are these photos?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (currentPhotos.isEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_camera, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No photos available yet'),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // Photo slider
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: currentPhotos.length,
                    onPageChanged: (index) {
                      setState(() {
                        currentPhotoIndices[locationId] = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final photo = currentPhotos[index];
                      final vote = currentVotes[photo['id']];
                      
                      return Card(
                        margin: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            // Photo placeholder
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.photo, size: 48, color: Colors.grey),
                              ),
                            ),
                            // Voting buttons
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _voteOnPhoto(photo['id'], true),
                                    icon: Row(
                                      children: [
                                        Icon(
                                          Icons.thumb_up,
                                          color: (vote?['accurate'] ?? 0) > 0 ? Colors.white : null,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${vote?['accurate'] ?? 0}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: (vote?['accurate'] ?? 0) > 0 ? Colors.white : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    label: Text(
                                      'Accurate',
                                      style: TextStyle(
                                        color: (vote?['accurate'] ?? 0) > 0 ? Colors.white : null,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: (vote?['accurate'] ?? 0) > 0 ? Colors.green : null,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _voteOnPhoto(photo['id'], false),
                                    icon: Row(
                                      children: [
                                        Icon(
                                          Icons.thumb_down,
                                          color: (vote?['inaccurate'] ?? 0) > 0 ? Colors.white : null,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${vote?['inaccurate'] ?? 0}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: (vote?['inaccurate'] ?? 0) > 0 ? Colors.white : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    label: Text(
                                      'Inaccurate',
                                      style: TextStyle(
                                        color: (vote?['inaccurate'] ?? 0) > 0 ? Colors.white : null,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: (vote?['inaccurate'] ?? 0) > 0 ? Colors.red : null,
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
                const SizedBox(height: 8),
                // Photo description and indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(
                      currentPhotos.length,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: currentPhotoIndex == index
                              ? locationType?.color ?? Colors.grey
                              : Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Uploaded: ${_formatDateTime(currentPhotos[currentPhotoIndex]['uploadDate'])}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Accessibility features
          Text(
            'Accessibility Features',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _getAccessibilityFeatures(selectedLocation!).length,
            itemBuilder: (context, index) {
              final feature = _getAccessibilityFeatures(selectedLocation!)[index];
              return Card(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(iconGetter(feature['key'], feature['value']), size: 24),
                    const SizedBox(height: 4),
                    Text(
                      feature['label'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getAccessibilityFeatures(Map<String, dynamic> location) {
    // TODO: Implement logic to extract accessibility features from location data
    return [
      {'key': 'wheelchair', 'value': 'yes', 'label': 'Wheelchair Access'},
      {'key': 'tactile_paving', 'value': 'yes', 'label': 'Tactile Paving'},
      {'key': 'elevator', 'value': 'yes', 'label': 'Elevator'},
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vote'),
        leading: selectedLocation != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    selectedLocation = null;
                  });
                },
              )
            : null,
      ),
      body: selectedLocation != null
          ? _buildLocationDetails()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchPage()),
                      );

                      if (result != null && result is Map<String, dynamic>) {
                        _showLocationDetails(result);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Text(
                            'Search for a location...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Search for a location to vote on its photos',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 