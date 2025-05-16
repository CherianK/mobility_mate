import 'package:shared_preferences/shared_preferences.dart';

class UsernameGenerator {
  static const List<String> adjectives = [
    'Happy', 'Brave', 'Clever', 'Swift', 'Gentle', 'Wild', 'Calm', 'Bright',
    'Noble', 'Proud', 'Wise', 'Bold', 'Kind', 'Lively', 'Peaceful', 'Royal',
    'Silent', 'Mighty', 'Graceful', 'Daring'
  ];

  static const List<String> animals = [
    'Tiger', 'Eagle', 'Dolphin', 'Wolf', 'Lion', 'Bear', 'Fox', 'Hawk',
    'Dragon', 'Phoenix', 'Panther', 'Falcon', 'Lynx', 'Shark', 'Leopard',
    'Owl', 'Hawk', 'Whale', 'Jaguar', 'Falcon'
  ];

  static Future<String> getUsername(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    String? savedUsername = prefs.getString('username_$deviceId');

    if (savedUsername == null) {
      // Generate new username
      final random = DateTime.now().millisecondsSinceEpoch;
      final adjective = adjectives[random % adjectives.length];
      final animal = animals[(random ~/ adjectives.length) % animals.length];
      savedUsername = '$adjective $animal';

      // Save the username
      await prefs.setString('username_$deviceId', savedUsername);
    }

    return savedUsername;
  }
} 