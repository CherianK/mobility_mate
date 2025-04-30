import 'package:flutter/material.dart';
import 'map_home_page.dart';
import 'find_toilet_page.dart';
import 'upload_page.dart';
import 'share_page.dart';
import 'vote_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const MapHomePage(),
    const FindToiletPage(),
    const UploadPage(venueData: {}),
    const SharePage(),
    const VotePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF007AFF), // iOS blue
            unselectedItemColor: const Color(0xFF8E8E93), // iOS gray
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600, // semibold
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Find Toilet',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.upload),
                label: 'Upload',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.share),
                label: 'Share',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.thumbs_up_down),
                label: 'Vote',
              ),
            ],
          ),
        ),
      ),
    );
  }
} 