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
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'profile_page.dart';
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
        final name = hospital['name'] ?? hospital['Name'];
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
        final name = toilet['name'] ?? toilet['Name'];
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
        final name = train['name'] ?? train['Name'];
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
        final name = tram['name'] ?? tram['Name'];
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

      // Submit vote to backend
      await _submitVote(availableImages[currentImageIndex]['url'], isAccessible);
      
      // Record the vote and update streak
      await VoteTracker.recordVote();
      await BadgeManager.updateStreak();
      await _updateRemainingVotes();
      
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.blue,
      body: SafeArea(
        child: Container(
          color: isDark ? Colors.grey[900] : Colors.white,
          child: Column(
            children: [
              // Blue header
              Container(
                width: double.infinity,
                color: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Stack(
                  children: [
                    // Gaming-style background pattern
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.1,
                        child: CustomPaint(
                          painter: HexagonPatternPainter(),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
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
                                          '$remainingVotes votes remaining',
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
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ProfilePage(),
                                    ),
                                  );
                                },
                                tooltip: 'View Profile',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  isDark ? Icons.light_mode : Icons.dark_mode,
                                  color: Colors.white,
                                  size: 24,
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
                        const SizedBox(height: 12),
                        // Swipe instructions
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.touch_app,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Swipe right if the image shows good accessibility, left if it doesn\'t',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
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
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ProfilePage(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.person, color: Colors.white),
                                    label: const Text(
                                      'View Profile',
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
                                                  const SizedBox(height: 16),
                                                  // Flexible image area
                                                  ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      maxHeight: MediaQuery.of(context).size.height * 0.32,
                                                      minHeight: 120,
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
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            color: isDark ? Colors.grey[300] : Colors.black87,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                        Text(
                                                          (availableImages[currentImageIndex]['locationName'] != null &&
                                                           (availableImages[currentImageIndex]['locationName'] as String).trim().isNotEmpty)
                                                              ? availableImages[currentImageIndex]['locationName']
                                                              : 'Unknown Location',
                                                          style: TextStyle(
                                                            fontSize: 17,
                                                            fontWeight: FontWeight.bold,
                                                            color: isDark ? Colors.white : Colors.black,
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
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Progress indicator
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
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
                                            minHeight: 8,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Progress',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '${currentImageIndex + 1} of ${availableImages.length}',
                                              style: TextStyle(
                                                fontSize: 14,
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