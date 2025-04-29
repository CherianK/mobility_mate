import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialOverlay {
  static const String homeFeature = 'home_feature';
  static const String findToiletFeature = 'find_toilet_feature';
  static const String uploadFeature = 'upload_feature';
  static const String shareFeature = 'share_feature';
  static const String voteFeature = 'vote_feature';

  static Future<void> showTutorial(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenTutorial = prefs.getBool('has_seen_tutorial') ?? false;

      if (!hasSeenTutorial && context.mounted) {
        // Show the tutorial overlay
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const TutorialDialog(),
        );
        // Mark tutorial as seen
        await prefs.setBool('has_seen_tutorial', true);
      }
    } catch (e) {
      debugPrint('Error showing tutorial: $e');
    }
  }
}

class TutorialDialog extends StatefulWidget {
  const TutorialDialog({super.key});

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  int _currentStep = 0;
  final List<TutorialStep> _steps = [
    TutorialStep(
      title: 'Search Bar',
      description: 'Search for any location in Victoria to find accessible places nearby',
      icon: Icons.search,
    ),
    TutorialStep(
      title: 'Home',
      description: 'View your current or searched location and nearby accessible places',
      icon: Icons.home,
    ),
    TutorialStep(
      title: 'Find Toilet',
      description: 'Search for accessible toilets near you',
      icon: Icons.search,
    ),
    TutorialStep(
      title: 'Upload',
      description: 'Upload images of accessible places',
      icon: Icons.upload,
    ),
    TutorialStep(
      title: 'Share',
      description: 'Share your favorite accessible places with others',
      icon: Icons.share,
    ),
    TutorialStep(
      title: 'Vote',
      description: 'Rate and review images of accessible places',
      icon: Icons.thumbs_up_down,
    ),
  ];

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              step.icon,
              size: 60,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              step.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              step.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _steps.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _currentStep ? Colors.blue : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                _currentStep == _steps.length - 1 ? 'Get Started' : 'Next',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
  });
} 