import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/username_generator.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      deviceId = prefs.getString('device_id');
      
      if (deviceId != null) {
        // Load username
        username = await UsernameGenerator.getUsername(deviceId!);

        // Load voting stats
        final response = await http.get(
          Uri.parse('https://mobility-mate.onrender.com/api/votes/device/$deviceId'),
        );

        if (response.statusCode == 200) {
          final List<dynamic> votes = json.decode(response.body);
          int accurateCount = 0;
          int inaccurateCount = 0;

          for (var vote in votes) {
            if (vote['is_accurate'] == true) {
              accurateCount++;
            } else {
              inaccurateCount++;
            }
          }

          setState(() {
            userStats = {
              'total_votes': votes.length,
              'accurate_votes': accurateCount,
              'inaccurate_votes': inaccurateCount,
            };
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.person, size: 50, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        username ?? 'Anonymous User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Voting Statistics',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildStatRow('Total Votes', userStats?['total_votes'] ?? 0),
                            const Divider(),
                            _buildStatRow('Accurate Votes', userStats?['accurate_votes'] ?? 0),
                            const Divider(),
                            _buildStatRow('Inaccurate Votes', userStats?['inaccurate_votes'] ?? 0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Mobility Mate',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Help improve accessibility information by voting on location images. Your contributions help make the world more accessible for everyone.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
} 