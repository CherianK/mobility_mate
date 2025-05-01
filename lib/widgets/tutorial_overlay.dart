import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialOverlay extends StatefulWidget {
  final Widget child;

  const TutorialOverlay({
    Key? key,
    required this.child,
  }) : super(key: key);

  static Future<void> resetTutorialState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_shown_tutorial', false);
    print('TutorialOverlay: Tutorial state reset');
  }

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> with SingleTickerProviderStateMixin {
  bool _showTutorial = true;
  int _currentStep = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: 'Search Locations',
      description: 'Find accessible features in Victoria. Type a location to search.',
      position: const Offset(0.5, 0.08),
      radius: 40,
      icon: Icons.search,
    ),
    TutorialStep(
      title: 'Home',
      description: 'View the map and find accessible features around you',
      position: const Offset(0.17, 0.95),
      radius: 30,
      icon: Icons.home,
    ),
    TutorialStep(
      title: 'Vote',
      description: 'Vote on accessibility features and help improve our data',
      position: const Offset(0.5, 0.95),
      radius: 30,
      icon: Icons.thumbs_up_down,
    ),
    TutorialStep(
      title: 'Events',
      description: 'Discover and join accessibility-related events',
      position: const Offset(0.83, 0.95),
      radius: 30,
      icon: Icons.event,
    ),
    TutorialStep(
      title: 'More Features',
      description: 'Upload new images, report issues, and share with others',
      position: const Offset(0.5, 0.5),
      radius: 40,
      icon: Icons.more_horiz,
      additionalIcons: [
        Icons.upload,
        Icons.report_problem,
        Icons.share,
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    print('TutorialOverlay: Initializing...');
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _markTutorialAsShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_shown_tutorial', true);
      print('TutorialOverlay: Marked tutorial as shown');
    } catch (e) {
      print('TutorialOverlay: Error marking tutorial as shown: $e');
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      print('TutorialOverlay: Moving to step $_currentStep');
    } else {
      setState(() {
        _showTutorial = false;
      });
      _markTutorialAsShown();
      print('TutorialOverlay: Tutorial completed');
    }
  }

  void _skipTutorial() {
    setState(() {
      _showTutorial = false;
    });
    _markTutorialAsShown();
    print('TutorialOverlay: Tutorial skipped');
  }

  @override
  Widget build(BuildContext context) {
    print('TutorialOverlay: Building with _showTutorial: $_showTutorial');
    return Stack(
      children: [
        widget.child,
        if (_showTutorial)
          Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                // Semi-transparent overlay
                GestureDetector(
                  onTap: () {}, // Prevent taps from passing through
                  child: Container(
                    color: Colors.black54,
                  ),
                ),
                // Highlight circle with animation
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: MediaQuery.of(context).size.width * _steps[_currentStep].position.dx - _steps[_currentStep].radius,
                  top: MediaQuery.of(context).size.height * _steps[_currentStep].position.dy - _steps[_currentStep].radius,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: _steps[_currentStep].radius * 2,
                          height: _steps[_currentStep].radius * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _steps[_currentStep].icon,
                            color: Colors.blue,
                            size: _steps[_currentStep].radius,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Tutorial card
                Positioned(
                  left: 20,
                  right: 20,
                  top: MediaQuery.of(context).size.height * 0.4,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _steps[_currentStep].title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _steps[_currentStep].description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        if (_steps[_currentStep].additionalIcons != null) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _steps[_currentStep].additionalIcons!.map((icon) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(
                                  icon,
                                  color: Colors.blue,
                                  size: 32,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _skipTutorial,
                              child: const Text('Skip Tutorial'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: _nextStep,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                _currentStep < _steps.length - 1 ? 'Next' : 'Got it!',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Progress indicators
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentStep ? Colors.blue : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class TutorialStep {
  final String title;
  final String description;
  final Offset position;
  final double radius;
  final IconData icon;
  final List<IconData>? additionalIcons;

  const TutorialStep({
    required this.title,
    required this.description,
    required this.position,
    required this.radius,
    required this.icon,
    this.additionalIcons,
  });
} 