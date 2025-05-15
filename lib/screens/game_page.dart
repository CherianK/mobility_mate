import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/mapbox_config.dart';
import '../models/marker_type.dart';
import '../utils/icon_utils.dart';
import 'package:uuid/uuid.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> allImages = [];
  List<Map<String, dynamic>> availableImages = [];  // Images user hasn't voted on
  bool isLoading = true;
  int currentImageIndex = 0;
  
  // Swipe animation controllers
  late AnimationController _animationController;
  Animation<double>? _animation;
  double _dragPosition = 0;
  double _dragPercentage = 0;
  
  // Constants for swipe
  final double _swipeThreshold = 0.32;
  final double _maxAngle = 30 * (pi / 180);

  String? deviceId;  // Tracks unique device identifier for voting

  @override
  void initState() {
    super.initState();
    _initializeDeviceId().then((_) {
      loadAllImages();
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId!);
    }
  }

  Future<void> loadAllImages() async {
    try {
      setState(() => isLoading = true);

      // Load all datasets
      final response = await Future.wait([
        http.get(Uri.parse('https://mobility-mate.onrender.com/medical-location-points')),
        http.get(Uri.parse('https://mobility-mate.onrender.com/toilet-location-points')),
        http.get(Uri.parse('https://mobility-mate.onrender.com/train-location-points')),
        http.get(Uri.parse('https://mobility-mate.onrender.com/tram-location-points')),
      ]);

      final List<dynamic> hospitalsData = json.decode(response[0].body);
      final List<dynamic> toiletsData = json.decode(response[1].body);
      final List<dynamic> trainsData = json.decode(response[2].body);
      final List<dynamic> tramsData = json.decode(response[3].body);

      //debugPrint('Loaded: ${hospitalsData.length} hospitals, ${toiletsData.length} toilets, ${trainsData.length} trains, ${tramsData.length} trams');

      // Process images from all datasets
      List<Map<String, dynamic>> allImages = [];

      // Process hospital images
      for (var hospital in hospitalsData) {
        final images = hospital['Images'];
        final name = hospital['name'] ?? hospital['Name'];
        debugPrint('Hospital $name: Images = $images');
        if (images != null && images is List) {
          for (var image in images) {
            if (image is Map && image['approved_status'] == true && image['image_url'] != null) {
              allImages.add({
                'url': image['image_url'],
                'locationName': name ?? 'Unknown Hospital',
                'locationType': 'hospital',
                'locationId': hospital['id'] ?? name ?? 'unknown',
              });
            }
          }
        }
      }
      debugPrint('Found ${allImages.length} hospital images');

      // Process toilet images
      for (var toilet in toiletsData) {
        final images = toilet['Images'];
        final name = toilet['name'] ?? toilet['Name'];
        debugPrint('Toilet $name: Images = $images');
        if (images != null && images is List) {
          for (var image in images) {
            if (image is Map && image['approved_status'] == true && image['image_url'] != null) {
              allImages.add({
                'url': image['image_url'],
                'locationName': name ?? 'Public Toilet',
                'locationType': 'toilet',
                'locationId': toilet['id'] ?? name ?? 'unknown',
              });
            }
          }
        }
      }
      debugPrint('Found ${allImages.length} total images after adding toilets');

      // Process train images
      for (var train in trainsData) {
        final images = train['Images'];
        final name = train['name'] ?? train['Name'];
        debugPrint('Train Station $name: Images = $images');
        if (images != null && images is List) {
          for (var image in images) {
            if (image is Map && image['approved_status'] == true && image['image_url'] != null) {
              allImages.add({
                'url': image['image_url'],
                'locationName': name ?? 'Train Station',
                'locationType': 'train',
                'locationId': train['id'] ?? name ?? 'unknown',
              });
            }
          }
        }
      }
      debugPrint('Found ${allImages.length} total images after adding trains');

      // Process tram images
      for (var tram in tramsData) {
        final images = tram['Images'];
        final name = tram['name'] ?? tram['Name'];
        debugPrint('Tram Stop $name: Images = $images');
        if (images != null && images is List) {
          for (var image in images) {
            if (image is Map && image['approved_status'] == true && image['image_url'] != null) {
              allImages.add({
                'url': image['image_url'],
                'locationName': name ?? 'Tram Stop',
                'locationType': 'tram',
                'locationId': tram['id'] ?? name ?? 'unknown',
              });
            }
          }
        }
      }

      // Filter out images the user has already voted on
      final availableImages = await _filterVotedImages(allImages);

      setState(() {
        this.allImages = allImages;
        this.availableImages = availableImages;
        isLoading = false;
      });
      
      debugPrint('Total images loaded: ${allImages.length}');
      
      if (allImages.isEmpty) {
        //debugPrint('Warning: No images found in any dataset');
      } else {
        //ebugPrint('First image URL: ${allImages[0]['url']}');
        // Print all image URLs for debugging
        for (var i = 0; i < allImages.length; i++) {
          //debugPrint('Image $i: ${allImages[i]['url']} from ${allImages[i]['locationName']} (${allImages[i]['locationType']})');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading images: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _filterVotedImages(List<Map<String, dynamic>> images) async {
    if (deviceId == null) {
      debugPrint('No device ID available for filtering votes');
      return images;
    }

    try {
      debugPrint('Fetching votes for device: $deviceId');
      // Get all votes for this device
      final response = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/api/votes/device/$deviceId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> votedImages = json.decode(response.body);
        debugPrint('Found ${votedImages.length} votes for this device');
        
        final votedUrls = votedImages.map((vote) => vote['image_url'] as String).toSet();
        debugPrint('Voted URLs: $votedUrls');
        
        // Filter out images the user has already voted on
        final filteredImages = images.where((image) => !votedUrls.contains(image['url'])).toList();
        debugPrint('Filtered from ${images.length} to ${filteredImages.length} images');
        
        return filteredImages;
      } else {
        debugPrint('Error fetching votes: ${response.statusCode}');
        return images;
      }
    } catch (e) {
      debugPrint('Error filtering voted images: $e');
      return images;
    }
  }

  void _onPanStart(DragStartDetails details) {
    _animation?.removeListener(_onAnimationUpdate);
    _animation = null;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition += details.delta.dx;
      _dragPercentage = _dragPosition / context.size!.width;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final percentage = _dragPosition / context.size!.width;
    
    if (percentage.abs() > _swipeThreshold || velocity.abs() > 1000) {
      final isRight = percentage > 0;
      var endPosition = context.size!.width * (isRight ? 1 : -1);
      
      _animation = Tween<double>(
        begin: _dragPosition,
        end: endPosition,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ));
      
      _animation!.addListener(_onAnimationUpdate);
      _animationController.forward(from: 0).then((_) {
        _vote(isRight);
        _resetPosition();
      });
    } else {
      _animation = Tween<double>(
        begin: _dragPosition,
        end: 0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ));
      
      _animation!.addListener(_onAnimationUpdate);
      _animationController.forward(from: 0);
    }
  }

  void _onAnimationUpdate() {
    setState(() {
      _dragPosition = _animation!.value;
      _dragPercentage = _dragPosition / context.size!.width;
    });
  }

  void _resetPosition() {
    setState(() {
      _dragPosition = 0;
      _dragPercentage = 0;
    });
  }

  void _vote(bool isAccessible) async {
    if (currentImageIndex < availableImages.length) {
      // Submit vote to backend
      await _submitVote(availableImages[currentImageIndex]['url'], isAccessible);
      
      // Remove the voted image from availableImages
      setState(() {
        availableImages.removeAt(currentImageIndex);
        // If we've removed the last image, stay at the current index
        if (currentImageIndex >= availableImages.length && availableImages.isNotEmpty) {
          currentImageIndex = availableImages.length - 1;
        }
      });

      if (availableImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have voted on all available images!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : availableImages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No images available for voting',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : (currentImageIndex >= availableImages.length)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.celebration, size: 64, color: Colors.green),
                            const SizedBox(height: 16),
                            Text(
                              'You have voted on all available images!',
                              style: TextStyle(fontSize: 20, color: Colors.green[800], fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Header row with avatar and title
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Icon(Icons.person, color: Colors.blue.shade700),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Is the photo\nwheelchair accessible?',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Swipe left or right to vote!',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 40), // To balance avatar space
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onPanStart: _onPanStart,
                                  onPanUpdate: _onPanUpdate,
                                  onPanEnd: (details) {
                                    final velocity = details.velocity.pixelsPerSecond.dx;
                                    final percentage = _dragPosition / context.size!.width;
                                    if (percentage.abs() > _swipeThreshold || velocity.abs() > 1000) {
                                      final isRight = percentage > 0;
                                      // Animate card off-screen
                                      _animation = Tween<double>(
                                        begin: _dragPosition,
                                        end: context.size!.width * (isRight ? 1 : -1),
                                      ).animate(CurvedAnimation(
                                        parent: _animationController,
                                        curve: Curves.easeOut,
                                      ));
                                      _animation!.addListener(_onAnimationUpdate);
                                      _animationController.forward(from: 0).then((_) {
                                        _vote(isRight);
                                        _resetPosition();
                                      });
                                    } else {
                                      // Animate card back to center
                                      _animation = Tween<double>(
                                        begin: _dragPosition,
                                        end: 0,
                                      ).animate(CurvedAnimation(
                                        parent: _animationController,
                                        curve: Curves.easeOut,
                                      ));
                                      _animation!.addListener(_onAnimationUpdate);
                                      _animationController.forward(from: 0);
                                    }
                                  },
                                  child: Transform.translate(
                                    offset: Offset(_dragPosition, 0),
                                    child: Transform.rotate(
                                      angle: _maxAngle * _dragPercentage,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Card with image and location info
                                          Container(
                                            width: MediaQuery.of(context).size.width * 0.88,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: Colors.grey.shade300, width: 1),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.05),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(height: 16),
                                                // Flexible image area
                                                ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxHeight: MediaQuery.of(context).size.height * 0.36,
                                                    minHeight: 120,
                                                  ),
                                                  child: Container(
                                                    width: double.infinity,
                                                    color: Colors.grey[200],
                                                    child: availableImages[currentImageIndex]['url'] != null
                                                        ? Image.network(
                                                            availableImages[currentImageIndex]['url'],
                                                            fit: BoxFit.contain,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return Center(
                                                                child: Icon(Icons.broken_image, size: 48, color: Colors.grey.shade300),
                                                              );
                                                            },
                                                          )
                                                        : Center(
                                                            child: Icon(Icons.image, size: 64, color: Colors.grey.shade300),
                                                          ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        availableImages[currentImageIndex]['locationType'] == 'hospital'
                                                            ? 'Hospital'
                                                            : availableImages[currentImageIndex]['locationType'] == 'toilet'
                                                                ? 'Toilet'
                                                                : availableImages[currentImageIndex]['locationType'] == 'train'
                                                                    ? 'Train Station'
                                                                    : 'Tram Stop',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          color: Colors.black87,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                      Text(
                                                        (availableImages[currentImageIndex]['locationName'] != null &&
                                                         (availableImages[currentImageIndex]['locationName'] as String).trim().isNotEmpty)
                                                          ? availableImages[currentImageIndex]['locationName']
                                                          : 'Unknown Location',
                                                        style: const TextStyle(
                                                          fontSize: 17,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.black,
                                                        ),
                                                        textAlign: TextAlign.left,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                              ],
                                            ),
                                          ),
                                          // Thumbs down button (left)
                                          Positioned(
                                            left: 0,
                                            child: GestureDetector(
                                              onTap: () => _vote(false),
                                              child: CircleAvatar(
                                                radius: 32,
                                                backgroundColor: Colors.red[300],
                                                child: const Icon(Icons.thumb_down, color: Colors.white, size: 32),
                                              ),
                                            ),
                                          ),
                                          // Thumbs up button (right)
                                          Positioned(
                                            right: 0,
                                            child: GestureDetector(
                                              onTap: () => _vote(true),
                                              child: CircleAvatar(
                                                radius: 32,
                                                backgroundColor: Colors.green[400],
                                                child: const Icon(Icons.thumb_up, color: Colors.white, size: 32),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Skip button
                                ElevatedButton.icon(
                                  onPressed: () {
                                    if (currentImageIndex < availableImages.length - 1) {
                                      setState(() {
                                        currentImageIndex++;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.skip_next, color: Colors.white),
                                  label: const Text('Skip', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.lightBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Progress indicator
                                LinearProgressIndicator(
                                  value: (currentImageIndex + 1) / availableImages.length,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    '${currentImageIndex + 1} of ${availableImages.length}',
                                    style: const TextStyle(fontSize: 14),
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

  Future<void> _submitVote(String imageUrl, bool isAccurate) async {
    if (deviceId == null) {
      await _initializeDeviceId();
    }

    try {
      final response = await http.post(
        Uri.parse('https://mobility-mate.onrender.com/api/vote'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': deviceId,
          'location_id': availableImages[currentImageIndex]['locationId'],
          'image_url': imageUrl,
          'is_accurate': isAccurate,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vote recorded! ${data['accurate_count']} accurate, ${data['inaccurate_count']} inaccurate'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'You have already voted on this image'),
            backgroundColor: Colors.orange,
          ),
        );
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
} 