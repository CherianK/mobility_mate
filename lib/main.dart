import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'config/mapbox_config.dart';
import 'config/theme.dart';
import 'screens/map_home_page.dart';
import 'screens/find_toilet_page.dart';
import 'screens/upload_page.dart';
import 'screens/share_page.dart';
import 'screens/splash_screen.dart';
import 'screens/vote_page.dart';
import 'screens/events_page.dart';
import 'screens/game_page.dart';
import 'widgets/spotlight_tutorial_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/theme_provider.dart';
import 'screens/report_issue_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Initialize SharedPreferences and get/create device ID
  final prefs = await SharedPreferences.getInstance();
  final deviceId = await getOrCreateDeviceId();
  
  // Configure Mapbox
  MapboxOptions.setAccessToken(MapboxConfig.accessToken);
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
    return MaterialApp(
      title: 'Mobility Mate',
      theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/main': (context) => const MainScreen(),
          },
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _showTutorial = false;
  bool _isFromMenu = false;
  bool _showConfetti = false;
  late ConfettiController _confettiController;
  
  // Add GlobalKeys for navigation items
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _voteKey = GlobalKey();
  final GlobalKey _eventsKey = GlobalKey();
  final GlobalKey _navBarKey = GlobalKey();

  static const List<Widget> _pages = <Widget>[
    MapHomePage(),
    GamePage(),
    EventsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAndShowTutorial();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final dontShowAgain = prefs.getBool('dont_show_tutorial_again') ?? false;
    
    // Show tutorial if "Don't show again" wasn't checked
    if (!dontShowAgain) {
      if (mounted) {
        setState(() {
          _showTutorial = true;
          _isFromMenu = false;
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Add method to show tutorial
  void showTutorial({bool fromMenu = false}) {
    setState(() {
      _showTutorial = true;
      _isFromMenu = fromMenu;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final theme = Theme.of(context);

    return Material(
      child: Stack(
        children: [
          // Bottom layer: Scaffold with map and navigation
          Scaffold(
            body: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
            bottomNavigationBar: RepaintBoundary(
              key: _navBarKey,
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.3),
                indicatorColor: isDark ? Colors.blue.shade900 : Colors.blue.shade100,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    key: _homeKey,
                    icon: Icon(
                      Icons.home_outlined,
                      color: isDark ? Colors.white.withOpacity(0.7) : Colors.grey[600],
                    ),
                    selectedIcon: Icon(
                      Icons.home,
                      color: isDark ? Colors.white : Colors.blue.shade700,
                    ),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    key: _voteKey,
                    icon: Icon(
                      Icons.sports_esports_outlined,
                      color: isDark ? Colors.white.withOpacity(0.7) : Colors.grey[600],
                    ),
                    selectedIcon: Icon(
                      Icons.sports_esports,
                      color: isDark ? Colors.white : Colors.blue.shade700,
                    ),
                    label: 'Game',
                  ),
                  NavigationDestination(
                    key: _eventsKey,
                    icon: Icon(
                      Icons.event_outlined,
                      color: isDark ? Colors.white.withOpacity(0.7) : Colors.grey[600],
                    ),
                    selectedIcon: Icon(
                      Icons.event,
                      color: isDark ? Colors.white : Colors.blue.shade700,
                    ),
                    label: 'Events',
                  ),
                ],
              ),
            ),
          ),
          // Top layer: Spotlight overlay
          if (_showTutorial)
            Positioned.fill(
              child: SpotlightTutorialOverlay(
                navigationKeys: {
                  'home': _homeKey,
                  'vote': _voteKey,
                  'events': _eventsKey,
                  'navBar': _navBarKey,
                },
                child: Container(),
                onTutorialComplete: (bool wasSkipped) {
                  setState(() {
                    _showTutorial = false;
                    _isFromMenu = false;
                    if (!wasSkipped) {
                      _showConfetti = true;
                      _confettiController.play();
                    }
                  });
                },
                showDontShowAgain: !_isFromMenu,  // Show checkbox when NOT from menu
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
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.green,
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }
}

Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  String? deviceId = prefs.getString('device_id');
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
  }
  return deviceId;
}
