import 'package:flutter/material.dart';
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
import 'widgets/spotlight_tutorial_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // configure the SDK with your token:
  MapboxOptions.setAccessToken(MapboxConfig.accessToken);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobility Mate',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/main': (context) => const MainScreen(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  // Add GlobalKeys for navigation items
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _voteKey = GlobalKey();
  final GlobalKey _eventsKey = GlobalKey();
  final GlobalKey _navBarKey = GlobalKey();

  static const List<Widget> _pages = <Widget>[
    MapHomePage(),
    // FindToiletPage(),
    // UploadPage(venueData: {}),
    // SharePage(),
    VotePage(),
    EventsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                onDestinationSelected: _onItemTapped,
                destinations: [
                  NavigationDestination(
                    key: _homeKey,
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  // NavigationDestination(
                  //   icon: Icon(Icons.search_outlined),
                  //   selectedIcon: Icon(Icons.search),
                  //   label: 'Find Toilet',
                  // ),
                  // NavigationDestination(
                  //   icon: Icon(Icons.upload_outlined),
                  //   selectedIcon: Icon(Icons.upload),
                  //   label: 'Upload',
                  // ),
                  // NavigationDestination(
                  //   icon: Icon(Icons.share_outlined),
                  //   selectedIcon: Icon(Icons.share),
                  //   label: 'Share',
                  // ),
                  NavigationDestination(
                    key: _voteKey,
                    icon: Icon(Icons.thumbs_up_down_outlined),
                    selectedIcon: Icon(Icons.thumbs_up_down),
                    label: 'Vote',
                  ),
                  NavigationDestination(
                    key: _eventsKey,
                    icon: Icon(Icons.event_outlined),
                    selectedIcon: Icon(Icons.event),
                    label: 'Events',
                  ),
                ],
              ),
            ),
          ),
          // Top layer: Spotlight overlay
          Positioned.fill(
            child: SpotlightTutorialOverlay(
              navigationKeys: {
                'home': _homeKey,
                'vote': _voteKey,
                'events': _eventsKey,
                'navBar': _navBarKey,
              },
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }
}
