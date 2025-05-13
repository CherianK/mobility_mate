import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/mapbox_config.dart';
import '../models/marker_type.dart';
import '../utils/icon_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/custom_app_bar.dart';

class VotePage extends StatefulWidget {
  const VotePage({super.key});

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> mapboxResults = [];
  List<Map<String, dynamic>> localResults = [];
  List<Map<String, dynamic>> recentSearches = [];
  List<Map<String, dynamic>> allLocations = [];
  bool isLoading = false;
  Map<String, dynamic>? selectedLocation;
  Map<String, List<Map<String, dynamic>>> locationPhotos = {};
  Map<String, Map<String, Map<String, int>>> locationPhotoVotes = {};
  Map<String, int> currentPhotoIndices = {};

  static const _recentKey = 'vote_recent_searches';

  @override
  void initState() {
    super.initState();
    loadRecentSearches();
    loadLocalData();
  }

  Future<void> loadLocalData() async {
    try {
      // Load train data from API
      final trainResponse = await http.get(Uri.parse('https://mobility-mate.onrender.com/train-location-points'));
      if (trainResponse.statusCode != 200) {
        throw Exception('Failed to load train data: ${trainResponse.statusCode}');
      }
      final List<dynamic> trainData = json.decode(trainResponse.body);

      // Load tram data from API
      final tramResponse = await http.get(Uri.parse('https://mobility-mate.onrender.com/tram-location-points'));
      if (tramResponse.statusCode != 200) {
        throw Exception('Failed to load tram data: ${tramResponse.statusCode}');
      }
      final List<dynamic> tramData = json.decode(tramResponse.body);

      // Load hospital data from API
      final hospitalResponse = await http.get(Uri.parse('https://mobility-mate.onrender.com/medical-location-points'));
      if (hospitalResponse.statusCode != 200) {
        throw Exception('Failed to load hospital data: ${hospitalResponse.statusCode}');
      }
      final List<dynamic> hospitalData = json.decode(hospitalResponse.body);

      // Combine all datasets
      allLocations = [
        ...trainData.map((location) => {
          ...location,
          'isLocal': true,
          'type': 'train',
        }),
        ...tramData.map((location) => {
          ...location,
          'isLocal': true,
          'type': 'tram',
        }),
        ...hospitalData.map((location) => {
          ...location,
          'isLocal': true,
          'type': 'hospital',
        }),
      ];

      debugPrint('First few entries in allLocations: ${allLocations.take(5).toList()}');
      //debugPrint('Loaded ${allLocations.length} local locations');
      //debugPrint('All locations data: ${allLocations.map((location) => location['name'] ?? location['Name']).toList()}');
    } catch (e) {
      debugPrint('Error loading local data: $e');
    }
  }

  Future<void> searchLocations(String query) async {
    if (query.isEmpty) {
      setState(() {
        mapboxResults = [];
        localResults = [];
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    debugPrint('Search query: $query');
    debugPrint('All locations: ${allLocations.length}');

    // Ensure allLocations is populated correctly
    if (allLocations.isEmpty) {
      debugPrint('Error: allLocations is empty. Ensure data is loaded correctly from APIs.');
    }

    // Normalize search query and location names for better matching
    final normalizedQuery = query.toLowerCase().trim();

    debugPrint('Normalized query: $normalizedQuery');
    //debugPrint('Location names in allLocations: ${allLocations.map((location) => location['Name']?.toString().toLowerCase().trim() ?? location['name']?.toString().toLowerCase().trim() ?? '').toList()}');

    final filteredLocal = allLocations.where((location) {
      final name = location['Metadata']?['name']?.toString().toLowerCase().trim() ?? 
                  location['Tags']?['name']?.toString().toLowerCase().trim() ?? '';
      return name.contains(normalizedQuery);
    }).map((location) {
      return {
        'name': location['Metadata']?['name'] ?? location['Tags']?['name'] ?? 'Unknown Location',
        'lat': location['Location_Lat'],
        'lon': location['Location_Lon'],
        'isLocal': true,
        'type': location['type'],
        'images': (location['Images'] as List<dynamic>? ?? [])
          .where((img) => img is Map && img['approved_status'] == true)
          .map((img) => img['image_url'] as String)
          .toList(),
        'tags': location['Tags'] ?? {},
      };
    }).toList();

    debugPrint('Filtered local results: ${filteredLocal.length}');
    debugPrint('Filtered local results (names): ${filteredLocal.map((location) => location['name']).toList()}');

    setState(() {
      localResults = filteredLocal;
      isLoading = false;
    });
  }

  void _addToRecentSearches(Map<String, dynamic> location) async {
    recentSearches.removeWhere((loc) => loc['name'] == location['name']);
    recentSearches.insert(0, location);
    if (recentSearches.length > 5) {
      recentSearches = recentSearches.sublist(0, 5);
    }
    await saveRecentSearches();
  }

  Future<void> saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encoded =
        recentSearches.map((loc) => json.encode(loc)).toList();
    await prefs.setStringList(_recentKey, encoded);
  }

  Future<void> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? encoded = prefs.getStringList(_recentKey);
    if (encoded != null) {
      final List<Map<String, dynamic>> decoded = encoded
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
      setState(() {
        recentSearches = decoded;
      });
    }
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    final locationId = location['id'] ?? location['name'];
    setState(() {
      selectedLocation = location;
      // Use the image URLs from the `Images` array in the data
      if (!locationPhotos.containsKey(locationId)) {
        locationPhotos[locationId] = (selectedLocation!['images'] as List<dynamic>)
            .map((url) => {
                  'id': '${locationId}_${(selectedLocation!['images'] as List<dynamic>).indexOf(url)}',
                  'url': url,
                  //'uploadDate': 'Unknown', // Placeholder for upload date
                })
            .toList() as List<Map<String, dynamic>>;

        // Initialize votes for this location if not already present
        if (!locationPhotoVotes.containsKey(locationId)) {
          locationPhotoVotes[locationId] = {};
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

  Widget _buildPhotoVoting(String photoId) {
    final locationId = selectedLocation!['id'] ?? selectedLocation!['name'];
    final currentVotes = locationPhotoVotes[locationId] ?? {};
    final photoVotes = currentVotes[photoId] ?? {'accurate': 0, 'inaccurate': 0};

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: photoVotes['accurate']! > 0 ? Colors.blue : Colors.grey,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.thumb_up),
          label: Text('Accurate ${photoVotes['accurate']}'),
          onPressed: () => _voteOnPhoto(photoId, true),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: photoVotes['inaccurate']! > 0 ? Colors.blue : Colors.grey,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.thumb_down),
          label: Text('Inaccurate ${photoVotes['inaccurate']}'),
          onPressed: () => _voteOnPhoto(photoId, false),
        ),
      ],
    );
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

  List<Widget> _buildTagsList(Map<String, dynamic> tags) {
    return tags.entries.where((entry) => entry.key != 'Name').map((entry) {
      final key = entry.key.replaceAll('_', ' ').split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
      final value = entry.value.toString().toLowerCase();

      Color valueColor;
      String displayValue;

      if (value == 'yes') {
        valueColor = Colors.green;
        displayValue = 'Available';
      } else if (value == 'no') {
        valueColor = Colors.red;
        displayValue = 'Unavailable';
      } else {
        valueColor = Colors.blue;
        displayValue = entry.value.toString();
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                getTrainIcon(entry.key, 'yes'), // Use the icon logic for "yes" values regardless of availability
                color: valueColor, // Match the icon color to the value color
              ),
              const SizedBox(width: 8),
              Text(
                key,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: valueColor),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }).toList();
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

    final images = selectedLocation!['images'] as List<dynamic>? ?? [];
    final tags = selectedLocation!['tags'] as Map<String, dynamic>? ?? {};

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
                         locationType?.iconName == 'hospital' ? Colors.purple :
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
          if (images.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFE5E5EA)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Photos',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Photo slider with page dots
                  Column(
                    children: [
                      SizedBox(
                        height: 300, // Increased height for photos
                        child: PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (index) {
                            setState(() {
                              currentPhotoIndices[locationId] = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final imageUrl = images[index];
                            return Column(
                              children: [
                                Expanded(
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.contain, // Adjusted to accommodate both portrait and landscape photos
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                                _buildPhotoVoting(locationPhotos[locationId]![index]['id']),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...List.generate(
                            images.length,
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
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            const Divider(height: 1, color: Color(0xFFE5E5EA)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Photos',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No attached pictures',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Accessibility features
          Text(
            'Accessibility Features',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._buildTagsList(tags),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Vote',
      ),
      body: selectedLocation != null
          ? SingleChildScrollView(
              child: _buildLocationDetails(),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _controller,
                    onChanged: (value) {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (value == _controller.text) {
                          searchLocations(value);
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search for a location...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _controller.clear();
                                searchLocations('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                Expanded(
                  child: _controller.text.isEmpty
                      ? ListView(
                          children: [
                            if (recentSearches.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  'Recent Searches',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ...recentSearches.map((location) {
                              return ListTile(
                                leading: const Icon(Icons.history),
                                title: Text(location['name']),
                                onTap: () {
                                  _controller.text = location['name'];
                                  searchLocations(location['name']);
                                },
                              );
                            })
                          ],
                        )
                      : ListView(
                          children: [
                            if (localResults.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  'Stations & Suburbs',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              ...localResults.map((location) => ListTile(
                                    leading: Icon(
                                      location['type'] == 'hospital' ? Icons.local_hospital :
                                      location['type'] == 'pharmacy' ? Icons.local_pharmacy :
                                      location['type'] == 'tram' ? Icons.tram :
                                      Icons.health_and_safety_rounded,
                                      color: location['type'] == 'hospital' ? Colors.blue :
                                             location['type'] == 'pharmacy' ? Colors.blue :
                                             location['type'] == 'tram' ? Colors.blue :
                                             Colors.blue,
                                    ),
                                    title: Text(location['name']),
                                    onTap: () {
                                      _addToRecentSearches(location);
                                      _showLocationDetails(location);
                                    },
                                  )),
                            ],
                            if (mapboxResults.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  'Other Locations',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              ...mapboxResults.map((location) => ListTile(
                                    leading: const Icon(Icons.location_on),
                                    title: Text(location['name']),
                                    onTap: () {
                                      _addToRecentSearches(location);
                                      _showLocationDetails(location);
                                    },
                                  )),
                            ],
                            if (localResults.isEmpty && mapboxResults.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    'No results found',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}