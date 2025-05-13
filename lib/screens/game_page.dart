import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/mapbox_config.dart';
import '../models/marker_type.dart';
import '../utils/icon_utils.dart';

class VotePage extends StatefulWidget {
  const VotePage({super.key});

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> allImages = [];
  bool isLoading = true;
  int currentImageIndex = 0;
  
  // Swipe animation controllers
  late AnimationController _animationController;
  Animation<double>? _animation;
  double _dragPosition = 0;
  double _dragPercentage = 0;
  
  // Constants for swipe
  final double _swipeThreshold = 0.32; // 20% more sensitive (reduced from 0.4)
  final double _maxAngle = 30 * (pi / 180); // maximum rotation angle in radians

  @override
  void initState() {
    super.initState();
    loadAllImages();
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

      debugPrint('Loaded: ${hospitalsData.length} hospitals, ${toiletsData.length} toilets, ${trainsData.length} trains, ${tramsData.length} trams');

      // Process images from all datasets
      List<Map<String, dynamic>> allImages = [];

      // Process hospital images
      for (var hospital in hospitalsData) {
        final images = hospital['Images'];
        final name = hospital['name'] ?? hospital['Name'];
        debugPrint('Hospital $name: Images = $images');
        if (images != null) {
          if (images is List) {
            for (var imageUrl in images) {
              if (imageUrl != null && imageUrl is String && imageUrl.isNotEmpty) {
                allImages.add({
                  'url': imageUrl,
                  'locationName': name ?? 'Unknown Hospital',
                  'locationType': 'hospital',
                  'locationId': hospital['id'] ?? name ?? 'unknown',
                });
              }
            }
          } else if (images is String && images.isNotEmpty) {
            allImages.add({
              'url': images,
              'locationName': name ?? 'Unknown Hospital',
              'locationType': 'hospital',
              'locationId': hospital['id'] ?? name ?? 'unknown',
            });
          }
        }
      }
      debugPrint('Found ${allImages.length} hospital images');

      // Process toilet images
      for (var toilet in toiletsData) {
        final images = toilet['Images'];
        final name = toilet['name'] ?? toilet['Name'];
        debugPrint('Toilet $name: Images = $images');
        if (images != null) {
          if (images is List) {
            for (var imageUrl in images) {
              if (imageUrl != null && imageUrl is String && imageUrl.isNotEmpty) {
                allImages.add({
                  'url': imageUrl,
                  'locationName': name ?? 'Public Toilet',
                  'locationType': 'toilet',
                  'locationId': toilet['id'] ?? name ?? 'unknown',
                });
              }
            }
          } else if (images is String && images.isNotEmpty) {
            allImages.add({
              'url': images,
              'locationName': name ?? 'Public Toilet',
              'locationType': 'toilet',
              'locationId': toilet['id'] ?? name ?? 'unknown',
            });
          }
        }
      }
      debugPrint('Found ${allImages.length} total images after adding toilets');

      // Process train images
      for (var train in trainsData) {
        final images = train['Images'];
        final name = train['name'] ?? train['Name'];
        debugPrint('Train Station $name: Images = $images');
        if (images != null) {
          if (images is List) {
            for (var imageUrl in images) {
              if (imageUrl != null && imageUrl is String && imageUrl.isNotEmpty) {
                allImages.add({
                  'url': imageUrl,
                  'locationName': name ?? 'Train Station',
                  'locationType': 'train',
                  'locationId': train['id'] ?? name ?? 'unknown',
                });
              }
            }
          } else if (images is String && images.isNotEmpty) {
            allImages.add({
              'url': images,
              'locationName': name ?? 'Train Station',
              'locationType': 'train',
              'locationId': train['id'] ?? name ?? 'unknown',
            });
          }
        }
      }
      debugPrint('Found ${allImages.length} total images after adding trains');

      // Process tram images
      for (var tram in tramsData) {
        final images = tram['Images'];
        final name = tram['name'] ?? tram['Name'];
        debugPrint('Tram Stop $name: Images = $images');
        if (images != null) {
          if (images is List) {
            for (var imageUrl in images) {
              if (imageUrl != null && imageUrl is String && imageUrl.isNotEmpty) {
                allImages.add({
                  'url': imageUrl,
                  'locationName': name ?? 'Tram Stop',
                  'locationType': 'tram',
                  'locationId': tram['id'] ?? name ?? 'unknown',
                });
              }
            }
          } else if (images is String && images.isNotEmpty) {
            allImages.add({
              'url': images,
              'locationName': name ?? 'Tram Stop',
              'locationType': 'tram',
              'locationId': tram['id'] ?? name ?? 'unknown',
            });
          }
        }
      }

      setState(() {
        this.allImages = allImages;
        isLoading = false;
      });
      
      debugPrint('Total images loaded: ${allImages.length}');
      
      if (allImages.isEmpty) {
        debugPrint('Warning: No images found in any dataset');
      } else {
        debugPrint('First image URL: ${allImages[0]['url']}');
        // Print all image URLs for debugging
        for (var i = 0; i < allImages.length; i++) {
          debugPrint('Image $i: ${allImages[i]['url']} from ${allImages[i]['locationName']} (${allImages[i]['locationType']})');
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

  void _vote(bool isAccessible) {
    if (currentImageIndex < allImages.length - 1) {
      setState(() {
        currentImageIndex++;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have voted on all images!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vote on Images'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : allImages.isEmpty
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
              : (currentImageIndex >= allImages.length)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.celebration, size: 64, color: Colors.green),
                          const SizedBox(height: 16),
                          Text(
                            'You have voted on all images!',
                            style: TextStyle(fontSize: 20, color: Colors.green[800], fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        // Swipe indicators
                        Positioned.fill(
                          child: Container(
                            color: _dragPercentage == 0
                                ? Colors.transparent
                                : _dragPercentage < 0
                                    ? Colors.red.withOpacity(min(_dragPercentage.abs() * 0.5, 0.5))
                                    : Colors.green.withOpacity(min(_dragPercentage * 0.5, 0.5)),
                            child: Center(
                              child: Icon(
                                _dragPercentage == 0
                                    ? null
                                    : _dragPercentage < 0
                                        ? Icons.close
                                        : Icons.check,
                                color: Colors.white.withOpacity(
                                  _dragPercentage == 0 ? 0 : min(_dragPercentage.abs() * 2, 0.8),
                                ),
                                size: 120,
                              ),
                            ),
                          ),
                        ),
                        // Image card
                        Align(
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: Transform.translate(
                              offset: Offset(_dragPosition, 0),
                              child: Transform.rotate(
                                angle: _maxAngle * _dragPercentage,
                                child: Container(
                                  margin: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Location info header
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          color: Colors.white,
                                          child: Row(
                                            children: [
                                              Icon(
                                                allImages[currentImageIndex]['locationType'] == 'hospital'
                                                    ? Icons.local_hospital
                                                    : allImages[currentImageIndex]['locationType'] == 'toilet'
                                                        ? Icons.wc
                                                        : allImages[currentImageIndex]['locationType'] == 'train'
                                                            ? Icons.train
                                                            : Icons.tram,
                                                color: allImages[currentImageIndex]['locationType'] == 'hospital'
                                                    ? Colors.red
                                                    : Colors.blue,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  allImages[currentImageIndex]['locationName'] ?? 'Unknown Location',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Image
                                        SizedBox(
                                          height: MediaQuery.of(context).size.height * 0.6,
                                          width: double.infinity,
                                          child: Image.network(
                                            allImages[currentImageIndex]['url'] ?? '',
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              debugPrint('Error loading image: $error');
                                              return Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.broken_image, size: 48, color: Colors.grey.shade300),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Failed to load image',
                                                      style: TextStyle(color: Colors.grey.shade600),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Swipe instructions
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.arrow_back, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Not Accessible'),
                                ],
                              ),
                              Row(
                                children: const [
                                  Text('Accessible'),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, color: Colors.green),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Progress indicator
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: (currentImageIndex + 1) / allImages.length,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  '${currentImageIndex + 1} of ${allImages.length}',
                                  style: const TextStyle(fontSize: 14),
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