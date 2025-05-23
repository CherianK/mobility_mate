import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/mapbox_config.dart';
import '../models/marker_type.dart';
import '../utils/icon_utils.dart';
import '../utils/pattern_painters.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../utils/vote_tracker.dart';
import '../utils/badge_manager.dart';

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
  int remainingVotes = 30;
  
  // Queue to store votes that need to be submitted
  List<Map<String, dynamic>> _voteQueue = [];
  bool _isSubmittingVotes = false;
  
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
      _updateRemainingVotes();
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // Submit any remaining votes when the page is closed
    _submitQueuedVotes();
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

      // Process images from all datasets
      List<Map<String, dynamic>> allImages = [];

      // Process hospital images
      for (var hospital in hospitalsData) {
        final images = hospital['Images'];
        final name = hospital['Tags']?['name'] ?? hospital['name'] ?? hospital['Name'];
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

      // Process toilet images
      for (var toilet in toiletsData) {
        final images = toilet['Images'];
        final name = toilet['Tags']?['name'] ?? toilet['name'] ?? toilet['Name'];
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

      // Process train images
      for (var train in trainsData) {
        final images = train['Images'];
        final name = train['Tags']?['name'] ?? train['name'] ?? train['Name'];
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

      // Process tram images
      for (var tram in tramsData) {
        final images = tram['Images'];
        final name = tram['Tags']?['name'] ?? tram['name'] ?? tram['Name'];
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
      
    } catch (e, stackTrace) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _filterVotedImages(List<Map<String, dynamic>> images) async {
    if (deviceId == null) {
      return images;
    }

    try {
      final response = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/api/votes/device/$deviceId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> votedImages = json.decode(response.body);
        
        final votedUrls = votedImages.map((vote) => vote['image_url'] as String).toSet();
        
        final filteredImages = images.where((image) => !votedUrls.contains(image['url'])).toList();
        
        return filteredImages;
      } else {
        return images;
      }
    } catch (e) {
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

  // Helper to get a proper display name for locations
  String _getLocationDisplayName(Map<String, dynamic> imageData) {
    final locationName = imageData['locationName'] as String?;
    final locationType = imageData['locationType'] as String?;
    
    // Check if name is missing, empty, or just the generic type
    if (locationName == null || locationName.trim().isEmpty) {
      return 'Unnamed Location';
    }
    
    // Return name only if it's not the same as the generic type
    if ((locationType == 'hospital' && locationName == 'Unknown Hospital') ||
        (locationType == 'toilet' && locationName == 'Public Toilet') ||
        (locationType == 'train' && locationName == 'Train Station') ||
        (locationType == 'tram' && locationName == 'Tram Stop')) {
      return 'No specific name available';
    }
    
    return locationName;
  }

  Future<void> _updateRemainingVotes() async {
    final votes = await VoteTracker.getRemainingVotes();
    setState(() {
      remainingVotes = votes;
    });
  }

  void _vote(bool isAccessible) async {
    if (currentImageIndex < availableImages.length) {
      // Check if user can vote
      final canVote = await VoteTracker.canVote();
      if (!canVote) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily vote limit reached. Please try again tomorrow!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Add vote to queue
      _voteQueue.add({
        'image_url': availableImages[currentImageIndex]['url'],
        'location_id': availableImages[currentImageIndex]['locationId'],
        'is_accurate': isAccessible,
      });
      
      // Record the vote and update streak locally
      await VoteTracker.recordVote();
      await BadgeManager.updateStreak();
      await _updateRemainingVotes();
      
      // Update UI immediately
      setState(() {
        availableImages.removeAt(currentImageIndex);
        // If we've removed the last image, stay at the current index
        if (currentImageIndex >= availableImages.length && availableImages.isNotEmpty) {
          currentImageIndex = availableImages.length - 1;
        }
      });

      // Submit votes if we've reached a threshold or no more images
      if (_voteQueue.length >= 5 || availableImages.isEmpty || remainingVotes <= 0) {
        _submitQueuedVotes();
      }

      if (availableImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have voted on all available images!')),
        );
      }
    }
  }

  Future<void> _submitQueuedVotes() async {
    if (_voteQueue.isEmpty || _isSubmittingVotes) return;

    _isSubmittingVotes = true;
    final votesToSubmit = List<Map<String, dynamic>>.from(_voteQueue);
    _voteQueue.clear();

    try {
      // Get username from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username_$deviceId');

      // Submit votes in parallel
      final futures = votesToSubmit.map((vote) => http.post(
        Uri.parse('https://mobility-mate.onrender.com/api/vote'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': deviceId,
          'username': username,
          'location_id': vote['location_id'],
          'image_url': vote['image_url'],
          'is_accurate': vote['is_accurate'],
        }),
      ));

      await Future.wait(futures);
    } catch (e) {
      // If submission fails, add votes back to queue
      _voteQueue.addAll(votesToSubmit);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting votes. Will retry later.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      _isSubmittingVotes = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Column(
            children: [
              // Blue header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
            child: SafeArea(
              bottom: false,
                child: Stack(
                  children: [
                    // Hexagonal pattern
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.1,
                        child: CustomPaint(
                          painter: HexagonPatternPainter(),
                        ),
                      ),
                    ),
                    // Header content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Accessibility Game',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.local_fire_department,
                                          size: 16,
                                          color: Colors.orange[300],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$remainingVotes daily votes remaining',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
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
                              onPressed: isLoading ? null : loadAllImages,
                              tooltip: 'Refresh Images',
                            ),
                          ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Swipe prompt in header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.swipe,
                                color: Colors.white.withOpacity(0.9),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Swipe right for accessible, left for not',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
              ),
                ),
              ),
              // Add spacing between header and content
              const SizedBox(height: 24),
              // Main content
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : remainingVotes <= 0
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              margin: const EdgeInsets.symmetric(horizontal: 32),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[850] : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.orange[900]?.withOpacity(0.3) : Colors.orange[50],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.timer,
                                      size: 48,
                                      color: isDark ? Colors.orange[300] : Colors.orange[700],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Daily Voting Limit Reached!',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.orange[300] : Colors.orange[700],
                                      letterSpacing: -0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'You\'ve reached your daily limit of 30 votes. Come back tomorrow to continue helping improve accessibility information!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDark ? Colors.grey[300] : Colors.grey[600],
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 32),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.home, color: Colors.white),
                                    label: const Text(
                                      'Back to Home',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark ? Colors.blue[700] : Colors.lightBlue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                      elevation: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : availableImages.isEmpty
                            ? Column(
                                children: [
                                  // No images content
                                  Expanded(
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        margin: const EdgeInsets.symmetric(horizontal: 32),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.grey[850] : Colors.white,
                                          borderRadius: BorderRadius.circular(24),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.blue[900]?.withOpacity(0.3) : Colors.blue[50],
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.image_not_supported,
                                                size: 48,
                                                color: isDark ? Colors.blue[300] : Colors.blue[700],
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            Text(
                                              'No Images Available',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'We\'re currently out of images to vote on. Help us grow our database by uploading new images of accessible locations!',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: isDark ? Colors.grey[300] : Colors.grey[600],
                                                height: 1.4,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 24),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                setState(() {
                                                  loadAllImages();
                                                });
                                              },
                                              icon: Icon(
                                                Icons.refresh,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              label: const Text(
                                                'Refresh',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isDark ? Colors.blue[700] : Colors.lightBlue,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                                elevation: 2,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Check back later for more images!',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDark ? Colors.grey[400] : Colors.grey[500],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  GestureDetector(
                                    onPanStart: _onPanStart,
                                    onPanUpdate: _onPanUpdate,
                                    onPanEnd: _onPanEnd,
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
                                                color: isDark ? Colors.grey[800] : Colors.white,
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                                                  width: 1
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const SizedBox(height: 12),
                                                  // Flexible image area
                                                  ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      maxHeight: MediaQuery.of(context).size.height * 0.30,
                                                      minHeight: 100,
                                                    ),
                                                    child: Container(
                                                      width: double.infinity,
                                                      color: isDark ? Colors.grey[900] : Colors.grey[200],
                                                      child: availableImages[currentImageIndex]['url'] != null
                                                          ? Image.network(
                                                              availableImages[currentImageIndex]['url'],
                                                              fit: BoxFit.contain,
                                                              errorBuilder: (context, error, stackTrace) {
                                                                return Center(
                                                                  child: Icon(
                                                                    Icons.broken_image,
                                                                    size: 48,
                                                                    color: isDark ? Colors.grey[600] : Colors.grey.shade300
                                                                  ),
                                                                );
                                                              },
                                                            )
                                                          : Center(
                                                              child: Icon(
                                                                Icons.image,
                                                                size: 64,
                                                                color: isDark ? Colors.grey[600] : Colors.grey.shade300
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
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
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            color: isDark ? Colors.grey[300] : Colors.black87,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          _getLocationDisplayName(availableImages[currentImageIndex]),
                                                          style: TextStyle(
                                                            fontSize: 20,
                                                            fontWeight: FontWeight.bold,
                                                            color: isDark ? Colors.white : Colors.black,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                ],
                                              ),
                                            ),
                                            // Thumbs down button (left)
                                            Positioned(
                                              left: 0,
                                              child: GestureDetector(
                                                onTap: () => _vote(false),
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red[300]?.withOpacity(0.9),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.red[300]!.withOpacity(0.3),
                                                        blurRadius: 8,
                                                        spreadRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(Icons.thumb_down, color: Colors.white, size: 32),
                                                ),
                                              ),
                                            ),
                                            // Thumbs up button (right)
                                            Positioned(
                                              right: 0,
                                              child: GestureDetector(
                                                onTap: () => _vote(true),
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[400]?.withOpacity(0.9),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.green[400]!.withOpacity(0.3),
                                                        blurRadius: 8,
                                                        spreadRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(Icons.thumb_up, color: Colors.white, size: 32),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Progress indicator
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    margin: const EdgeInsets.fromLTRB(24, 0, 24, 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.grey[800] : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? Colors.grey[700]!.withOpacity(0.3) : Colors.grey[200]!,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: (currentImageIndex + 1) / availableImages.length,
                                            backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              isDark ? Colors.blue[400]! : Colors.blue[600]!,
                                            ),
                                            minHeight: 6,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Approved photos remaining',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '${currentImageIndex + 1} of ${availableImages.length}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
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
  }
} 