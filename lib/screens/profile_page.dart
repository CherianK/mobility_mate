import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/username_generator.dart';
import '../utils/badge_manager.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'leaderboard_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;
  Map<String, dynamic>? userStats;
  String? deviceId;
  String? username;
  Map<String, dynamic>? badgeInfo;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Initialize badge storage
      await BadgeManager.initializeBadgeStorage();
      
      final prefs = await SharedPreferences.getInstance();
      deviceId = prefs.getString('device_id');
      
      if (deviceId != null) {
        // Load username
        username = await UsernameGenerator.getUsername(deviceId!);
        
        // Load badge info
        badgeInfo = await BadgeManager.getBadgeInfo();
        
        // Check badges
        await BadgeManager.debugCheckBadges();

        // Load leaderboard data to get user's stats (including uploads for badge system)
        final response = await http.get(
          Uri.parse('https://mobility-mate.onrender.com/api/leaderboard'),
        );

        int approvedPhotos = 0;
        int totalPoints = 0;
        if (response.statusCode == 200) {
          final List<dynamic> leaderboardData = json.decode(response.body);
          final userEntry = leaderboardData.firstWhere(
            (entry) => entry['username'] == username,
            orElse: () => null,
          );
          if (userEntry != null) {
            totalPoints = userEntry['points'] ?? 0;
            approvedPhotos = userEntry['total_uploads'] ?? 0;
          }
        }

        // Load voting stats
        final votesResponse = await http.get(
          Uri.parse('https://mobility-mate.onrender.com/api/votes/device/$deviceId'),
        );

        int totalVotes = 0;
        if (votesResponse.statusCode == 200) {
          final List<dynamic> votes = json.decode(votesResponse.body);
          totalVotes = votes.length;
          // Ensure badges are checked and awarded for votes
          await BadgeManager.updateStreak();
          // Reload badgeInfo after awarding
          badgeInfo = await BadgeManager.getBadgeInfo();
        }

        setState(() {
          userStats = {
            'total_points': totalPoints,
            'total_votes': totalVotes,
            'photo_uploads': approvedPhotos,
          };
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
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
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.blue,
                                  child: Icon(Icons.person, size: 50, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  username ?? 'Anonymous User',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (userStats != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.amber,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.stars, color: Colors.amber, size: 24),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${userStats?['total_points'] ?? 0} Points',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber,
                                          letterSpacing: -0.5,
                                        ),
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
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Streak Section
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange[700]!.withOpacity(isDark ? 0.3 : 0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.orange[700]!.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[700]?.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.orange[700]!.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.local_fire_department,
                                      color: Colors.orange[700],
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Current Streak',
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange[700]?.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.orange[700]!.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${badgeInfo?['currentStreak'] ?? 0} days',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                              if (badgeInfo?['nextBadge'] != null) ...[
                                const SizedBox(height: 20),
                                const Divider(height: 1),
                                const SizedBox(height: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Next Badge: ${badgeInfo!['nextBadge']['name']}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange[700]!.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: badgeInfo!['nextBadge']['progress'] / 100,
                                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[700]!),
                                          minHeight: 8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${badgeInfo!['nextBadge']['progress']}% complete',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Badges Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A2E).withOpacity(0.7) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? Colors.blue[700]!.withOpacity(0.3) : Colors.black.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: isDark ? Colors.blue[700]!.withOpacity(0.3) : Colors.blue[700]!.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[700]?.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.blue[700]!.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.emoji_events,
                                      color: Colors.blue[700],
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Earned Badges',
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
                              _BadgeDropdownSection(
                                earnedBadges: (badgeInfo?['earnedBadges'] is Set)
                                    ? (badgeInfo?['earnedBadges'] as Set<String>)
                                    : badgeInfo?['earnedBadges'] is List
                                        ? Set<String>.from(badgeInfo?['earnedBadges'] ?? [])
                                        : <String>{},
                                badgeInfo: badgeInfo,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 20),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6C63FF).withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LeaderboardPage(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6C63FF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'VIEW LEADERBOARD',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.5,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withOpacity(0.3),
                                              offset: const Offset(0, 2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 20,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.3),
                                            offset: const Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
    );
  }
}

class HexagonPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final hexSize = 20.0;
    final rows = (size.height / hexSize).ceil();
    final cols = (size.width / hexSize).ceil();

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final x = col * hexSize * 1.5;
        final y = row * hexSize * 1.3 + (col % 2) * hexSize * 0.65;

        final path = Path();
        for (var i = 0; i < 6; i++) {
          final angle = i * pi / 3;
          final pointX = x + hexSize * cos(angle);
          final pointY = y + hexSize * sin(angle);
          if (i == 0) {
            path.moveTo(pointX, pointY);
          } else {
            path.lineTo(pointX, pointY);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BadgeDropdownSection extends StatefulWidget {
  final Set<String> earnedBadges;
  final Map<String, dynamic>? badgeInfo;
  final bool isDark;
  const _BadgeDropdownSection({
    required this.earnedBadges,
    required this.badgeInfo,
    required this.isDark,
    Key? key,
  }) : super(key: key);

  @override
  State<_BadgeDropdownSection> createState() => _BadgeDropdownSectionState();
}

class _BadgeDropdownSectionState extends State<_BadgeDropdownSection> {
  bool _isExpanded = false;

  final List<Map<String, String>> _categories = [
    {'type': 'streak', 'label': 'Streak Badges', 'icon': '🔥'},
    {'type': 'votes', 'label': 'Voting Badges', 'icon': '👍'},
    {'type': 'uploads', 'label': 'Upload Badges', 'icon': '📸'},
    {'type': 'special', 'label': 'Special Achievements', 'icon': '✨'},
  ];

  @override
  Widget build(BuildContext context) {
    final earnedBadges = widget.earnedBadges;
    final badgeInfo = widget.badgeInfo;
    final isDark = widget.isDark;
    final hasAnyEarned = earnedBadges.isNotEmpty;

    // Earned badges section (always visible)
    Widget earnedBadgesSection = hasAnyEarned
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _categories.map((category) {
              final type = category['type']!;
              final label = category['label']!;
              final icon = category['icon']!;
              final badgesOfType = BadgeManager.badges.entries
                  .where((badge) => badge.value['type'] == type && earnedBadges.contains(badge.key))
                  .toList();
              if (badgesOfType.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...badgesOfType.map((badge) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blueGrey[900] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue[200]!, width: 2),
                      ),
                      child: Row(
                        children: [
                          Text(badge.value['icon'] ?? '', style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(badge.value['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(badge.value['description'] ?? '', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              );
            }).toList(),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No badges earned yet. Start contributing to earn achievements!',
              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
          );

    // Upcoming (unearned) badges dropdown
    Widget upcomingDropdown = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.blueGrey[900] : Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: isDark ? Colors.white : Colors.blue[900]),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Achievements',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.blue[900],
                  ),
                ),
                const Spacer(),
                Icon(Icons.emoji_events, color: isDark ? Colors.amber[200] : Colors.amber[800]),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _categories.map((category) {
                final type = category['type']!;
                final label = category['label']!;
                final icon = category['icon']!;
                final badgesOfType = BadgeManager.badges.entries
                    .where((badge) => badge.value['type'] == type && !earnedBadges.contains(badge.key))
                    .toList();
                if (badgesOfType.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(icon, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...badgesOfType.map((badge) {
                      // Progress calculation
                      int currentProgress = 0;
                      int requiredProgress = 0;
                      String progressText = '';
                      if (badge.value['type'] == 'streak') {
                        requiredProgress = badge.value['requiredStreak'] ?? 0;
                        currentProgress = badgeInfo?['currentStreak'] ?? 0;
                        progressText = '$currentProgress/$requiredProgress days';
                      } else if (badge.value['type'] == 'votes') {
                        requiredProgress = badge.value['requiredVotes'] ?? 0;
                        currentProgress = badgeInfo?['totalVotes'] ?? 0;
                        progressText = '$currentProgress/$requiredProgress votes';
                      } else if (badge.value['type'] == 'uploads') {
                        requiredProgress = badge.value['requiredUploads'] ?? 0;
                        currentProgress = badgeInfo?['totalUploads'] ?? 0;
                        progressText = '$currentProgress/$requiredProgress uploads';
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[400]!, width: 2),
                        ),
                        child: Row(
                          children: [
                            Text(badge.value['icon'] ?? '', style: const TextStyle(fontSize: 28, color: Colors.grey)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(badge.value['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[500], fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text(badge.value['description'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                  if (requiredProgress > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        progressText,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        earnedBadgesSection,
        const SizedBox(height: 12),
        upcomingDropdown,
      ],
    );
  }
}