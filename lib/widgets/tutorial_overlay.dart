import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

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
  bool _showConfetti = false;
  int _currentStep = 0;
  bool _dontShowAgain = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late ConfettiController _confettiController;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: 'Search',
      description: 'Find wheelchair-accessible locations and features in Victoria. Plan your trip with ease.',
      position: const Offset(0.12, 0.10),
      radius: 40,
      icon: Icons.search,
    ),
    TutorialStep(
      title: 'Home',
      description: 'Explore accessible locations and features around you.',
      position: const Offset(0.17, 0.90),
      radius: 30,
      icon: Icons.home,
    ),
    TutorialStep(
      title: 'Vote',
      description: 'Vote to help improve information for the community. Your input makes a difference!',
      position: const Offset(0.5, 0.90),
      radius: 30,
      icon: Icons.thumbs_up_down,
    ),
    TutorialStep(
      title: 'Events',
      description: 'Discover accessible events. Be part of the community and stay informed.',
      position: const Offset(0.83, 0.90),
      radius: 30,
      icon: Icons.event,
    ),
    TutorialStep(
      title: 'Tap the Markers',
      description: 'Tap one of the below markers on the map to see detailed accessibility information.',
      position: const Offset(0.5, 0.5),
      radius: 40,
      icon: Icons.touch_app,
      additionalIcons: [
        Icons.wc,
        Icons.train,
        Icons.tram,
        Icons.local_hospital,
      ],
    ),
    TutorialStep(
      title: 'Contribute & Share',
      description: 'Help build our accessibility database by uploading photos, reporting issues, and sharing accessible locations with others.',
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

  @override
  void initState() {
    super.initState();
    _checkTutorialPreference();
    
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

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
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
      });
    } else {
      setState(() {
        _showTutorial = false;
        _showConfetti = true;
      });
      _confettiController.play();
      _markTutorialAsShown();
      
      // Hide confetti after animation completes
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
      });
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);
    
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
                            color: isDark ? theme.primaryColor.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                            border: Border.all(
                              color: isDark ? theme.primaryColor : Colors.blue,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _steps[_currentStep].icon,
                            color: isDark ? theme.primaryColor : Colors.blue,
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
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? theme.cardColor : Colors.white,
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
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? theme.primaryColor : Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _steps[_currentStep].description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                          if (_steps[_currentStep].additionalIcons != null) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 16,
                              children: _steps[_currentStep].additionalIcons!.map((icon) {
                                return Icon(
                                  icon,
                                  color: isDark ? theme.primaryColor : Colors.blue,
                                  size: 28,
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 16),
                          // Progress bar and step counter
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? theme.primaryColor.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Step ${_currentStep + 1}',
                                      style: TextStyle(
                                        color: isDark ? theme.primaryColor : Colors.blue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${_steps.length} steps',
                                      style: TextStyle(
                                        color: isDark ? theme.primaryColor.withOpacity(0.7) : Colors.blue.withOpacity(0.7),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: (_currentStep + 1) / _steps.length,
                                    backgroundColor: isDark ? theme.primaryColor.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(isDark ? theme.primaryColor : Colors.blue),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_currentStep == _steps.length - 1) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Checkbox(
                                  value: _dontShowAgain,
                                  onChanged: (value) {
                                    setState(() {
                                      _dontShowAgain = value ?? false;
                                    });
                                  },
                                  activeColor: isDark ? theme.primaryColor : Colors.blue,
                                ),
                                Text(
                                  'Don\'t show this again',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_currentStep < _steps.length - 1)
                                TextButton(
                                  onPressed: _skipTutorial,
                                  style: TextButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white70 : Colors.blue,
                                  ),
                                  child: const Text('Skip Tutorial'),
                                ),
                              if (_currentStep < _steps.length - 1)
                                const SizedBox(width: 12),
                              if (_currentStep > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: IconButton(
                                    onPressed: _previousStep,
                                    icon: const Icon(Icons.arrow_back),
                                    color: isDark ? theme.primaryColor : Colors.blue,
                                  ),
                                ),
                              ElevatedButton(
                                onPressed: _nextStep,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? theme.primaryColor : Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  _currentStep < _steps.length - 1 ? 'Next' : 'Got it!',
                                  style: const TextStyle(
                                    fontSize: 15,
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
                ),
              ],
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
              shouldLoop: false,
              colors: const [
                Colors.blue,
                Colors.red,
                Colors.green,
                Colors.yellow,
                Colors.purple,
                Colors.orange,
                Colors.pink,
                Colors.teal,
                Colors.indigo,
                Colors.amber,
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