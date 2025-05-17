import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboardData = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboardData();
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
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLeaderboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
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
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
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
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Be the first to contribute and appear on the leaderboard!',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Header with explanation
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: isDark ? Colors.blue.shade900.withOpacity(0.2) : Colors.blue.shade50,
                          child: Column(
                            children: [
                              const Text(
                                'Community Contributors',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Points are earned through voting (1 point) and uploading photos (5 points).',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            border: Border(
                              bottom: BorderSide(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: Text(
                                  'Rank',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Username',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  'Points',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Leaderboard list
                        Expanded(
                          child: ListView.builder(
                            itemCount: _leaderboardData.length,
                            itemBuilder: (context, index) {
                              final entry = _leaderboardData[index];
                              final rank = entry['rank'];
                              final username = entry['username'];
                              final points = entry['points'];
                              
                              // Determine if this is a top 3 position
                              final isTop3 = rank <= 3;
                              final rankColor = rank == 1
                                  ? Colors.amber
                                  : rank == 2
                                      ? Colors.grey.shade400
                                      : rank == 3
                                          ? Colors.brown.shade300
                                          : isDark
                                              ? Colors.grey[700]
                                              : Colors.grey[300];
                              
                              return Container(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[900] : Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: rankColor,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$rank',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: rank <= 3 ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    username,
                                    style: TextStyle(
                                      fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
                                      fontSize: isTop3 ? 16 : 14,
                                    ),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '$points',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
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
    );
  }
} 