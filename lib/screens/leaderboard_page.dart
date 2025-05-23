import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../utils/pattern_painters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/username_generator.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboardData = [];
  String? _errorMessage;
  String? _username;
  bool _isUserOnLeaderboard = false;

  @override
  void initState() {
    super.initState();
    _initUserData();
  }

  Future<void> _initUserData() async {
    await _getUserName();
    await _fetchLeaderboardData();
  }

  Future<void> _getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      if (deviceId != null) {
        final username = await UsernameGenerator.getUsername(deviceId);
        setState(() {
          _username = username;
        });
      }
    } catch (e) {
      print('Error getting username: $e');
    }
  }

  Future<void> _fetchLeaderboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/api/leaderboard'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _leaderboardData = data.map((item) => item as Map<String, dynamic>).toList();
          
          // Check if the user is on the leaderboard
          _isUserOnLeaderboard = _leaderboardData.any((item) => item['username'] == _username);
          
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load leaderboard data. Please try again later.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
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
              color: const Color(0xFF6C63FF),
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
                          // Back button
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Back',
                              iconSize: 22,
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'Leaderboard',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                          // Refresh button
                          Container(
                            margin: const EdgeInsets.only(left: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchLeaderboardData,
            tooltip: 'Refresh',
                              iconSize: 22,
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    ],
          ),
        ],
      ),
            ),
          ),
          // Main content
          Expanded(
            child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Oops!',
                              style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _fetchLeaderboardData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _leaderboardData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 64,
                            color: Colors.amber.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Data Yet',
                                  style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Be the first to contribute and appear on the leaderboard!',
                              textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        // Background pattern
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.1,
                            child: CustomPaint(
                              painter: HexagonPatternPainter(),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            // Header with explanation
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C63FF).withOpacity(isDark ? 0.3 : 0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6C63FF).withOpacity(0.2),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF6C63FF).withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.emoji_events,
                                          color: Color(0xFF6C63FF),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Community Contributors',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6C63FF).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Points are earned through voting (1 point) and uploading photos (5 points).',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Table header
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C63FF).withOpacity(isDark ? 0.3 : 0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        'Rank',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'Username',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        'Points',
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Leaderboard list
                            Expanded(
                              child: ListView.builder(
                                itemCount: _leaderboardData.length + (!_isUserOnLeaderboard && _username != null ? 1 : 0),
                                itemBuilder: (context, index) {
                                  // Check if we're at the end and should show the user's entry
                                  if (!_isUserOnLeaderboard && _username != null && index == _leaderboardData.length) {
                                    return _buildUserEntry(isDark);
                                  }
                                  
                                  final entry = _leaderboardData[index];
                                  final rank = entry['rank'];
                                  final username = entry['username'];
                                  final points = entry['points'];
                                  final isCurrentUser = username == _username;
                                  
                                  // Determine if this is a top 3 position
                                  final isTop3 = rank <= 3;
                                  final Color rankColor = rank == 1
                                      ? Colors.amber
                                      : rank == 2
                                          ? Colors.grey.shade400
                                          : rank == 3
                                              ? Colors.brown.shade300
                                              : isDark
                                                  ? const Color(0xFF616161)  // Colors.grey[700]
                                                  : const Color(0xFFE0E0E0); // Colors.grey[300]
                                  
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCurrentUser 
                                        ? (isDark ? const Color(0xFF183055) : const Color(0xFFE3F2FD))
                                        : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isCurrentUser
                                            ? Colors.blue.withOpacity(isDark ? 0.4 : 0.2)
                                            : const Color(0xFF6C63FF).withOpacity(isDark ? 0.3 : 0.1),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: isCurrentUser
                                          ? Colors.blue.withOpacity(0.5)
                                          : const Color(0xFF6C63FF).withOpacity(0.3),
                                        width: isCurrentUser ? 2 : 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: rankColor.withOpacity(0.2),
                                          border: Border.all(
                                            color: rankColor.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '#$rank',
                                            style: TextStyle(
                                              color: rankColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              username,
                                              style: TextStyle(
                                                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if (isCurrentUser)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              margin: const EdgeInsets.only(right: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.blue.withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: const Text(
                                                'YOU',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isCurrentUser
                                            ? Colors.blue.withOpacity(0.1)
                                            : const Color(0xFF6C63FF).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isCurrentUser
                                              ? Colors.blue.withOpacity(0.3)
                                              : const Color(0xFF6C63FF).withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          points.toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: isCurrentUser ? Colors.blue : const Color(0xFF6C63FF),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
  
  Widget _buildUserEntry(bool isDark) {
    // If the user isn't on the leaderboard, show their entry at the bottom with 0 points
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF183055) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(isDark ? 0.4 : 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.blue.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Your Position',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.blue[200] : Colors.blue[700],
              ),
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withOpacity(0.2),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '—',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    _username!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'YOU',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Text(
                '0',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Contribute by uploading photos and voting to earn points!',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 