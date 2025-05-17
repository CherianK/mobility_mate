import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/marker_type.dart';
import '../utils/icon_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/custom_app_bar.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class VotePage extends StatefulWidget {
  final Map<String, dynamic>? initialLocation;
  const VotePage({super.key, this.initialLocation});

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  Map<String, dynamic>? selectedLocation;
  Map<String, List<Map<String, dynamic>>> locationPhotos = {};
  Map<String, Map<String, Map<String, int>>> locationPhotoVotes = {};
  Map<String, int> currentPhotoIndices = {};
  final PageController _pageController = PageController();
  String? deviceId;

  @override
  void initState() {
    super.initState();
    _initializeDeviceId();
    if (widget.initialLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLocationDetails(widget.initialLocation!);
        _loadExistingVotes(widget.initialLocation!);
        
        // Print location type information
        final locationType = _determineLocationType(widget.initialLocation!);
      });
    }
  }

  Future<void> _initializeDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId!);
    }
  }

  Future<String> getOrCreateDeviceId() async {
    if (deviceId == null) {
      await _initializeDeviceId();
    }
    return deviceId!;
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    final locationId = location['id'] ?? location['name'];
    setState(() {
      selectedLocation = location;
      
      // Debug print for location type when showing details
      final locationType = _determineLocationType(location);
      print('SHOWING LOCATION TYPE: ${location["type"]}');
      print('SHOWING MARKER TYPE: ${locationType?.name}');
      
      // Use the image URLs from the `Images` array in the data
      if (!locationPhotos.containsKey(locationId)) {
        locationPhotos[locationId] = (selectedLocation!['images'] as List<dynamic>)
            .map((url) => {
                  'id': '${locationId}_${(selectedLocation!['images'] as List<dynamic>).indexOf(url)}',
                  'url': url,
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

  void _voteOnPhoto(String photoId, bool isAccurate) async {
    if (selectedLocation == null) return;

    final locationId = selectedLocation!['id'] ?? selectedLocation!['name'];
    final currentVotes = locationPhotoVotes[locationId] ?? {};
    final photoVotes = currentVotes[photoId] ?? {'accurate': 0, 'inaccurate': 0};

    try {
      // Get device ID
      final deviceId = await getOrCreateDeviceId();
      
      // Get image URL from the photo ID
      final imageIndex = int.parse(photoId.split('_').last);
      final imageUrl = selectedLocation!['images'][imageIndex];

      // Send vote to backend
      final response = await http.post(
        Uri.parse('https://mobility-mate.onrender.com/api/vote'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': deviceId,
          'location_id': locationId,
          'image_url': imageUrl,
          'is_accurate': isAccurate,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          // Update local vote counts with server response
          photoVotes['accurate'] = data['accurate_count'];
          photoVotes['inaccurate'] = data['inaccurate_count'];
          
          // Update the votes for this photo
          currentVotes[photoId] = photoVotes;
          locationPhotoVotes[locationId] = currentVotes;
        });
      } else if (response.statusCode == 400) {
        // Handle case where user has already voted
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'You have already voted on this image'),
            backgroundColor: Colors.orange,
          ),
        );
        
        // Update vote counts from error response
        setState(() {
          photoVotes['accurate'] = data['accurate_count'];
          photoVotes['inaccurate'] = data['inaccurate_count'];
          currentVotes[photoId] = photoVotes;
          locationPhotoVotes[locationId] = currentVotes;
        });
      } else {
        throw Exception('Failed to submit vote');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting vote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          label: Text('Accurate (${photoVotes['accurate']})'),
          onPressed: () => _voteOnPhoto(photoId, true),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: photoVotes['inaccurate']! > 0 ? Colors.blue : Colors.grey,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.thumb_down),
          label: Text('Inaccurate (${photoVotes['inaccurate']})'),
          onPressed: () => _voteOnPhoto(photoId, false),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(int count, int currentIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentIndex == index ? Colors.blue : Colors.grey.withOpacity(0.3),
          ),
        );
      }),
    );
  }

  MarkerType? _determineLocationType(Map<String, dynamic> location) {
    // Just use the passed accessibility_type_name
    final accessibilityType = location['accessibility_type_name']?.toString().toLowerCase() ?? '';
    
    if (accessibilityType == 'trains') {
      return MarkerType.train;
    } else if (accessibilityType == 'trams') {
      return MarkerType.tram;
    } else if (accessibilityType == 'medical') {
      return MarkerType.hospital;
    } else if (accessibilityType.contains('toilet')) {
      return MarkerType.toilet;
    }
    
    // Default to a generic location if type unknown
    return null;
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
        valueColor = Colors.grey;
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
                getTrainIcon(entry.key, 'yes'),
                color: valueColor,
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

    // Debug print for location type during UI building
    print('BUILDING UI FOR LOCATION TYPE: ${selectedLocation!["type"]}');
    print('BUILDING UI FOR ACCESSIBILITY_TYPE_NAME: ${selectedLocation!["accessibility_type_name"]}');
    print('USING MARKER TYPE: ${locationType?.name ?? "unknown"}');
    print('ICON NAME: ${locationType?.iconName ?? "default"}');

    // If locationType is null, use a default icon
    final IconData iconData = locationType?.iconName == 'toilet' ? Icons.wc :
                   locationType?.iconName == 'rail' ? Icons.train :
                   locationType?.iconName == 'rail-light' ? Icons.tram :
                   locationType?.iconName == 'hospital' ? Icons.local_hospital :
                   Icons.location_on;
                 
    final Color iconColor = locationType?.iconName == 'toilet' ? Colors.blue :
                  locationType?.iconName == 'rail' ? Colors.blue :
                  locationType?.iconName == 'rail-light' ? Colors.blue :
                  locationType?.iconName == 'hospital' ? Colors.purple :
                  Colors.grey;

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
                  iconData,
                  color: iconColor,
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
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Photos Section
          if (images.isNotEmpty) ...[
            const Text(
              'Photos',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setState(() {
                        currentPhotoIndices[locationId] = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final photoId = '${locationId}_$index';
                      return Container(
                        width: MediaQuery.of(context).size.width * 0.7,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      child: Stack(
                                        children: [
                                          CachedNetworkImage(
                                            imageUrl: images[index],
                                            fit: BoxFit.contain,
                                            placeholder: (context, url) => const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                            errorWidget: (context, url, error) =>
                                                const Icon(Icons.error),
                                          ),
                                          Positioned(
                                            right: 8,
                                            top: 8,
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                              ),
                                              onPressed: () => Navigator.pop(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFE0E0E0),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: CachedNetworkImage(
                                      imageUrl: images[index],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.error),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPhotoVoting(photoId),
                          ],
                        ),
                      );
                    },
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _buildPageIndicator(images.length, currentPhotoIndices[locationId] ?? 0),
                    ),
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vote'),
        leading: selectedLocation != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            : null,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed: () {
                final themeProvider = context.read<ThemeProvider>();
                final newMode = themeProvider.themeMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark;
                themeProvider.setThemeMode(newMode);
              },
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            ),
          ),
        ],
      ),
      body: selectedLocation != null
          ? SingleChildScrollView(
              child: _buildLocationDetails(),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'Select a location from the map or bottom sheet to vote on its photos.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingVotes(Map<String, dynamic> location) async {
    try {
      final images = location['images'] as List<dynamic>;
      final locationId = location['id'] ?? location['name'];

      for (var i = 0; i < images.length; i++) {
        final imageUrl = images[i];
        final photoId = '${locationId}_$i';

        final response = await http.get(
          Uri.parse('https://mobility-mate.onrender.com/api/votes/${Uri.encodeComponent(imageUrl)}'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          setState(() {
            if (!locationPhotoVotes.containsKey(locationId)) {
              locationPhotoVotes[locationId] = {};
            }
            locationPhotoVotes[locationId]![photoId] = {
              'accurate': data['accurate_count'],
              'inaccurate': data['inaccurate_count'],
            };
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }
}