import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'dart:ui';
import 'dart:math';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class SpotlightTutorialOverlay extends StatefulWidget {
  final Widget child;
  final Map<String, GlobalKey> navigationKeys;

  const SpotlightTutorialOverlay({
    Key? key,
    required this.child,
    required this.navigationKeys,
  }) : super(key: key);

  static Future<void> resetTutorialState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_shown_tutorial', false);
  }

  @override
  State<SpotlightTutorialOverlay> createState() => _SpotlightTutorialOverlayState();
}

class _SpotlightTutorialOverlayState extends State<SpotlightTutorialOverlay> with SingleTickerProviderStateMixin {
  bool _showTutorial = true;
  bool _showConfetti = false;
  int _currentStep = 0;
  bool _dontShowAgain = false;
  late ConfettiController _confettiController;
  Offset? _currentSpotlightPosition;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: 'Home',
      description: 'Explore accessible locations and features around you.',
      position: const Offset(0.17, 0.70),
      elementKey: 'home',
      radius: 30,
      icon: Icons.home,
      isNavigationItem: true,
    ),
    TutorialStep(
      title: 'Vote',
      description: 'Vote to help improve information for the community. Your input makes a difference!',
      position: const Offset(0.5, 0.70),
      elementKey: 'vote',
      radius: 30,
      icon: Icons.thumbs_up_down,
      isNavigationItem: true,
    ),
    TutorialStep(
      title: 'Events',
      description: 'Discover accessible events. Be part of the community and stay informed.',
      position: const Offset(0.83, 0.70),
      elementKey: 'events',
      radius: 30,
      icon: Icons.event,
      isNavigationItem: true,
    ),
    TutorialStep(
      title: 'Search',
      description: 'Find wheelchair-accessible locations and features in Victoria. Plan your trip with ease.',
      position: const Offset(0.12, 0.10),
      radius: 40,
      icon: Icons.search,
      isNavigationItem: false,
    ),
    TutorialStep(
      title: 'Dark Mode',
      description: 'Toggle between light and dark themes for comfortable viewing in any lighting condition.',
      position: const Offset(0.88, 0.10),
      radius: 40,
      icon: Icons.dark_mode,
      isNavigationItem: false,
    ),
    TutorialStep(
      title: 'Tap the Markers',
      description: 'Tap one of the below markers on the map to see accessibility information.',
      position: const Offset(0.5, 0.5),
      radius: 40,
      icon: Icons.touch_app,
      isNavigationItem: false,
      additionalIcons: [
        Icons.wc,
        Icons.train,
        Icons.tram,
        Icons.local_hospital,
      ],
    ),
    TutorialStep(
      title: 'Contribute & Share',
      description: 'Help improve our database by uploading photos, reporting issues & sharing accessible locations with others.',
      position: const Offset(0.5, 0.5),
      radius: 40,
      icon: Icons.more_horiz,
      isNavigationItem: false,
      additionalIcons: [
        Icons.upload,
        Icons.report_problem,
        Icons.share,
      ],
    ),
  ];

  Offset? _getElementPosition(String? elementKey) {
    if (elementKey == null) return null;
    
    final key = widget.navigationKeys[elementKey];
    if (key?.currentContext == null) return null;

    final RenderBox? box = key?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;

    final position = box.localToGlobal(Offset.zero);
    final size = box.size;

    // For navigation items, adjust the position to account for the navigation bar
    if (elementKey == 'home' || elementKey == 'vote' || elementKey == 'events') {
      final navBarKey = widget.navigationKeys['navBar'];
      if (navBarKey?.currentContext != null) {
        final navBox = navBarKey?.currentContext?.findRenderObject() as RenderBox?;
        if (navBox != null && navBox.hasSize) {
          final navPosition = navBox.localToGlobal(Offset.zero);
          final navSize = navBox.size;
          
          // Calculate the center of the navigation item
          final itemWidth = navSize.width / 3;
          final itemIndex = elementKey == 'home' ? 0 : elementKey == 'vote' ? 1 : 2;
          final x = navPosition.dx + (itemIndex * itemWidth) + (itemWidth / 2);
          // Adjust y position to be higher
          final y = navPosition.dy + (navSize.height / 2) - 20;
          
          return Offset(x, y);
        }
      }
    }

    return Offset(
      position.dx + size.width / 2,
      position.dy + size.height / 2,
    );
  }

  @override
  void initState() {
    super.initState();
    _checkTutorialPreference();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void didUpdateWidget(SpotlightTutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateSpotlightPosition();
  }

  void _updateSpotlightPosition() {
    if (!mounted) return;
    
    final currentStep = _steps[_currentStep];
    final size = MediaQuery.of(context).size;
    
    if (currentStep.elementKey != null) {
      final elementPosition = _getElementPosition(currentStep.elementKey);
      if (elementPosition != null) {
        setState(() {
          _currentSpotlightPosition = elementPosition;
        });
        return;
      }
    }
    
    setState(() {
      _currentSpotlightPosition = Offset(
        size.width * currentStep.position.dx,
        size.height * currentStep.position.dy,
      );
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _checkTutorialPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dontShowAgain = prefs.getBool('dont_show_tutorial_again') ?? false;
      if (dontShowAgain) {
        setState(() {
          _showTutorial = false;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _markTutorialAsShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_shown_tutorial', true);
      if (_dontShowAgain) {
        await prefs.setBool('dont_show_tutorial_again', true);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _currentSpotlightPosition = null; // Reset position to trigger recalculation
      });
      _updateSpotlightPosition();
    } else {
      setState(() {
        _showTutorial = false;
        _showConfetti = true;
      });
      _confettiController.play();
      _markTutorialAsShown();
      
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showConfetti = false;
          });
        }
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _currentSpotlightPosition = null; // Reset position to trigger recalculation
      });
      _updateSpotlightPosition();
    }
  }

  void _skipTutorial() {
    setState(() {
      _showTutorial = false;
    });
    _markTutorialAsShown();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final currentStep = _steps[_currentStep];
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);
    
    // Update spotlight position when the widget is first built or step changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSpotlightPosition();
    });

    return Stack(
      children: [
        widget.child,
        if (_showTutorial)
          // Dark overlay with spotlight hole
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {}, // Consume taps to prevent them from reaching the map
              child: Container(
                color: Colors.black.withOpacity(0.40),
                child: CustomPaint(
                  size: size,
                  painter: SpotlightPainter(
                    center: _currentSpotlightPosition ?? Offset(
                      size.width * currentStep.position.dx,
                      size.height * currentStep.position.dy,
                    ),
                    radius: currentStep.radius * 1.5,
                  ),
                ),
              ),
            ),
          ),
        if (_showTutorial)
          // Tutorial card
          Positioned(
            left: 20,
            right: 20,
            top: size.height * 0.35,
            child: SingleChildScrollView(
              child: Material(
                color: isDark ? theme.cardColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                elevation: 8,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? theme.primaryColor.withOpacity(0.5) : Colors.blue.shade100,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentStep > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: _previousStep,
                            icon: const Icon(Icons.arrow_back),
                            color: isDark ? Colors.white : Colors.blue.shade700,
                            style: IconButton.styleFrom(
                              backgroundColor: isDark ? theme.primaryColor.withOpacity(0.2) : Colors.blue.shade50,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ),
                      Text(
                        currentStep.title,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.blue.shade900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentStep.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: isDark ? Colors.white : Colors.grey.shade800,
                        ),
                      ),
                      if (currentStep.additionalIcons != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? theme.cardColor : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.3) : Colors.blue.shade100,
                              width: 1,
                            ),
                          ),
                          child: Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            alignment: WrapAlignment.center,
                            children: currentStep.additionalIcons!
                                .map((icon) => Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark ? Colors.white.withOpacity(0.2) : Colors.blue.shade100,
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        icon,
                                        size: 28,
                                        color: isDark ? Colors.white : Colors.blue.shade700,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _steps.length,
                          (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == _currentStep
                                  ? (isDark ? Colors.white : Colors.blue.shade700)
                                  : (isDark ? Colors.white.withOpacity(0.3) : Colors.blue.shade100),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentStep < _steps.length - 1)
                            TextButton(
                              onPressed: _skipTutorial,
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? Colors.white : Colors.grey.shade600,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text('Skip'),
                            ),
                          if (_currentStep == _steps.length - 1)
                            const SizedBox(width: 16), // Add spacing when Skip is hidden
                          ElevatedButton(
                            onPressed: _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : Colors.blue.shade700,
                              foregroundColor: isDark ? theme.primaryColor : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(_currentStep < _steps.length - 1 ? 'Next' : 'Finish'),
                          ),
                        ],
                      ),
                      if (_currentStep == _steps.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: CheckboxListTile(
                            title: Text(
                              'Don\'t show again',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                            value: _dontShowAgain,
                            onChanged: (value) {
                              setState(() {
                                _dontShowAgain = value ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            activeColor: isDark ? Colors.white : Colors.blue.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_showConfetti)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
            ),
          ),
      ],
    );
  }
}

class SpotlightPainter extends CustomPainter {
  final Offset center;
  final double radius;

  SpotlightPainter({
    required this.center,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Create a path for the entire screen
    var path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create a path for the spotlight hole
    final spotlightPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    // Cut out the spotlight hole from the main path
    path = Path.combine(PathOperation.difference, path, spotlightPath);

    // Draw the semi-transparent overlay
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(0.85)
        ..style = PaintingStyle.fill,
    );

    // Add a subtle glow effect around the spotlight
    canvas.drawCircle(
      center,
      radius + 2,
      Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) {
    return center != oldDelegate.center || radius != oldDelegate.radius;
  }
}

class TutorialStep {
  final String title;
  final String description;
  final Offset position;
  final String? elementKey;
  final double radius;
  final IconData icon;
  final List<IconData>? additionalIcons;
  final bool isNavigationItem;

  TutorialStep({
    required this.title,
    required this.description,
    required this.position,
    this.elementKey,
    required this.radius,
    required this.icon,
    this.additionalIcons,
    this.isNavigationItem = false,
  });
} 