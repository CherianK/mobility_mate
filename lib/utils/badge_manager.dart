import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BadgeManager {
  static const String streakKey = 'voting_streak';
  static const String lastVoteDateKey = 'last_vote_date';
  static const String badgesKey = 'earned_badges';
  static const String totalVotesKey = 'total_votes';
  static const String totalUploadsKey = 'total_uploads';

  // Badge definitions
  static const Map<String, Map<String, dynamic>> badges = {
    // Streak badges
    'streak_3': {
      'name': '3-Day Streak',
      'description': 'Voted for 3 consecutive days',
      'icon': '🔥',
      'type': 'streak',
      'requiredStreak': 3,
    },
    'streak_7': {
      'name': 'Week Warrior',
      'description': 'Voted for 7 consecutive days',
      'icon': '⚡',
      'type': 'streak',
      'requiredStreak': 7,
    },
    'streak_14': {
      'name': 'Fortnight Fighter',
      'description': 'Voted for 14 consecutive days',
      'icon': '🌟',
      'type': 'streak',
      'requiredStreak': 14,
    },
    'streak_30': {
      'name': 'Monthly Master',
      'description': 'Voted for 30 consecutive days',
      'icon': '👑',
      'type': 'streak',
      'requiredStreak': 30,
    },
    'streak_100': {
      'name': 'Century Champion',
      'description': 'Voted for 100 consecutive days',
      'icon': '🏆',
      'type': 'streak',
      'requiredStreak': 100,
    },
    
    // Voting badges
    'votes_10': {
      'name': 'Voting Novice',
      'description': 'Cast 10 votes',
      'icon': '👍',
      'type': 'votes',
      'requiredVotes': 10,
    },
    'votes_50': {
      'name': 'Voting Enthusiast',
      'description': 'Cast 50 votes',
      'icon': '💪',
      'type': 'votes',
      'requiredVotes': 50,
    },
    'votes_100': {
      'name': 'Voting Veteran',
      'description': 'Cast 100 votes',
      'icon': '🎯',
      'type': 'votes',
      'requiredVotes': 100,
    },
    'votes_500': {
      'name': 'Voting Master',
      'description': 'Cast 500 votes',
      'icon': '🏅',
      'type': 'votes',
      'requiredVotes': 500,
    },
    
    // Upload badges
    'upload_1': {
      'name': 'First Upload',
      'description': 'Upload your first photo',
      'icon': '📸',
      'type': 'uploads',
      'requiredUploads': 1,
    },
    'upload_5': {
      'name': 'Photo Contributor',
      'description': 'Upload 5 photos',
      'icon': '📷',
      'type': 'uploads',
      'requiredUploads': 5,
    },
    'upload_10': {
      'name': 'Photo Enthusiast',
      'description': 'Upload 10 photos',
      'icon': '🎥',
      'type': 'uploads',
      'requiredUploads': 10,
    },
    'upload_25': {
      'name': 'Photo Master',
      'description': 'Upload 25 photos',
      'icon': '🎬',
      'type': 'uploads',
      'requiredUploads': 25,
    },
    
    // Special achievement badges
    'first_vote': {
      'name': 'First Vote',
      'description': 'Cast your first vote',
      'icon': '🎉',
      'type': 'special',
      'oneTime': true,
    },
    'first_upload': {
      'name': 'First Upload',
      'description': 'Upload your first photo',
      'icon': '📸',
      'type': 'special',
      'oneTime': true,
    },
    'perfect_week': {
      'name': 'Perfect Week',
      'description': 'Vote every day for a week',
      'icon': '✨',
      'type': 'special',
      'oneTime': true,
    },
  };

  static Future<void> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Get last vote date
    final lastVoteDateStr = prefs.getString(lastVoteDateKey);
    DateTime? lastVoteDate;
    if (lastVoteDateStr != null) {
      lastVoteDate = DateTime.parse(lastVoteDateStr);
    }

    // Get current streak
    int currentStreak = prefs.getInt(streakKey) ?? 0;


    if (lastVoteDate == null) {
      // First vote ever
      currentStreak = 1;
      await _awardBadge('first_vote');
    } else {
      final lastVoteDay = DateTime(lastVoteDate.year, lastVoteDate.month, lastVoteDate.day);
      final yesterday = today.subtract(const Duration(days: 1));

      if (lastVoteDay.isAtSameMomentAs(yesterday)) {
        // Voted yesterday, increment streak
        currentStreak++;
        
        // Check for perfect week achievement
        if (currentStreak == 7) {
          await _awardBadge('perfect_week');
        }
      } else if (!lastVoteDay.isAtSameMomentAs(today)) {
        // Didn't vote yesterday, reset streak to 0
        currentStreak = 0;

      }
    }

    // Save updated streak and last vote date
    await prefs.setInt(streakKey, currentStreak);
    await prefs.setString(lastVoteDateKey, today.toIso8601String());

    // Check for new badges
    await _checkAndAwardBadges(currentStreak);
  }

  static Future<void> recordUpload() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    if (username == null) return;

    // Use leaderboard endpoint to get approved uploads
    final leaderboardResponse = await http.get(
      Uri.parse('https://mobility-mate.onrender.com/api/leaderboard'),
    );

    if (leaderboardResponse.statusCode == 200) {
      final List<dynamic> leaderboardData = json.decode(leaderboardResponse.body);
      final userEntry = leaderboardData.firstWhere(
        (entry) => entry['username'] == username,
        orElse: () => null,
      );
      final totalUploads = userEntry != null ? (userEntry['approved_uploads'] ?? 0) : 0;

      if (totalUploads == 1) {
        await _awardBadge('first_upload');
      }
      // Check for upload-based badges
      await _checkAndAwardUploadBadges(totalUploads);
    }
  }

  static Future<void> _checkAndAwardBadges(int currentStreak) async {
    final prefs = await SharedPreferences.getInstance();
    final earnedBadgesJson = prefs.getString(badgesKey);
    Set<String> earnedBadges = {};
    
    if (earnedBadgesJson != null) {
      earnedBadges = Set<String>.from(json.decode(earnedBadgesJson));
    }


    // Get total votes from API
    final deviceId = prefs.getString('device_id');
    if (deviceId != null) {
      final votesResponse = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/api/votes/device/$deviceId'),
      );

      if (votesResponse.statusCode == 200) {
        final List<dynamic> votes = json.decode(votesResponse.body);
        final totalVotes = votes.length;


        // Check for first vote badge if not already earned
        if (totalVotes > 0 && !earnedBadges.contains('first_vote')) {

          await _awardBadge('first_vote');
        }

        // Check voting badges
        for (final badge in badges.entries) {
          if (badge.value['type'] == 'votes' && 
              totalVotes >= badge.value['requiredVotes'] && 
              !earnedBadges.contains(badge.key)) {
            await _awardBadge(badge.key);
          }
        }
      }
    }

    // Check streak badges
    for (final badge in badges.entries) {
      if (badge.value['type'] == 'streak' && 
          currentStreak >= badge.value['requiredStreak'] && 
          !earnedBadges.contains(badge.key)) {
        await _awardBadge(badge.key);
      }
    }
  }

  static Future<void> _checkAndAwardUploadBadges(int totalUploads) async {
    final prefs = await SharedPreferences.getInstance();
    final earnedBadgesJson = prefs.getString(badgesKey);
    Set<String> earnedBadges = {};
    
    if (earnedBadgesJson != null) {
      earnedBadges = Set<String>.from(json.decode(earnedBadgesJson));
    }

    // Check upload badges
    for (final badge in badges.entries) {
      if (badge.value['type'] == 'uploads' && 
          totalUploads >= badge.value['requiredUploads'] && 
          !earnedBadges.contains(badge.key)) {
        await _awardBadge(badge.key);
      }
    }
  }

  static Future<void> _awardBadge(String badgeId) async {
    final prefs = await SharedPreferences.getInstance();
    final earnedBadgesJson = prefs.getString(badgesKey);
    Set<String> earnedBadges = {};
    
    if (earnedBadgesJson != null) {
      earnedBadges = Set<String>.from(json.decode(earnedBadgesJson));
    }


    
    earnedBadges.add(badgeId);
    await prefs.setString(badgesKey, json.encode(earnedBadges.toList()));
    

  }

  static Future<Map<String, dynamic>> getBadgeInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final currentStreak = prefs.getInt(streakKey) ?? 0;
    final earnedBadgesJson = prefs.getString(badgesKey);
    Set<String> earnedBadges = {};
    if (earnedBadgesJson != null) {
      earnedBadges = Set<String>.from(json.decode(earnedBadgesJson));
    }

    // Get total votes from API
    int totalVotes = 0;
    final deviceId = prefs.getString('device_id');
    if (deviceId != null) {
      final votesResponse = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/api/votes/device/$deviceId'),
      );

      if (votesResponse.statusCode == 200) {
        final List<dynamic> votes = json.decode(votesResponse.body);
        totalVotes = votes.length;

      }
    }

    // Get total uploads from leaderboard API
    int totalUploads = 0;
    final username = prefs.getString('username');
    if (username != null) {
      final leaderboardResponse = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/api/leaderboard'),
      );
      if (leaderboardResponse.statusCode == 200) {
        final List<dynamic> leaderboardData = json.decode(leaderboardResponse.body);
        final userEntry = leaderboardData.firstWhere(
          (entry) => entry['username'] == username,
          orElse: () => null,
        );
        totalUploads = userEntry != null ? (userEntry['approved_uploads'] ?? 0) : 0;
      }
    }

    final nextBadge = _getNextBadge(currentStreak, totalVotes, totalUploads);


    return {
      'currentStreak': currentStreak,
      'totalVotes': totalVotes,
      'totalUploads': totalUploads,
      'earnedBadges': earnedBadges,
      'nextBadge': nextBadge,
    };
  }

  static Map<String, dynamic>? _getNextBadge(int currentStreak, int totalVotes, int totalUploads) {


    // Check streak badges
    for (final badge in badges.entries) {
      if (badge.value['type'] == 'streak' && 
          currentStreak < badge.value['requiredStreak']) {
        final progress = (currentStreak / badge.value['requiredStreak'] * 100).round();
        return {
          'id': badge.key,
          ...badge.value,
          'progress': progress,
        };
      }
    }

    // Check voting badges
    for (final badge in badges.entries) {
      if (badge.value['type'] == 'votes' && 
          totalVotes < badge.value['requiredVotes']) {
        final progress = (totalVotes / badge.value['requiredVotes'] * 100).round();
        return {
          'id': badge.key,
          ...badge.value,
          'progress': progress,
        };
      }
    }

    // Check upload badges
    for (final badge in badges.entries) {
      if (badge.value['type'] == 'uploads' && 
          totalUploads < badge.value['requiredUploads']) {
        final progress = (totalUploads / badge.value['requiredUploads'] * 100).round();
        return {
          'id': badge.key,
          ...badge.value,
          'progress': progress,
        };
      }
    }

    return null;
  }

  static Future<void> resetStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(streakKey);
    await prefs.remove(lastVoteDateKey);
  }

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(streakKey);
    await prefs.remove(lastVoteDateKey);
    await prefs.remove(badgesKey);
    await prefs.remove(totalVotesKey);
    await prefs.remove(totalUploadsKey);
  }

  // Initialize badge storage
  static Future<void> initializeBadgeStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final earnedBadgesJson = prefs.getString(badgesKey);
    
    if (earnedBadgesJson == null) {
      await prefs.setString(badgesKey, json.encode([]));
    }
    
    // Ensure streak is initialized
    if (!prefs.containsKey(streakKey)) {
      await prefs.setInt(streakKey, 0);
    }
    
    // Ensure last vote date is initialized
    if (!prefs.containsKey(lastVoteDateKey)) {
      await prefs.setString(lastVoteDateKey, DateTime.now().toIso8601String());
    }
  }

  // Debug method to check badge storage
  static Future<void> debugCheckBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final earnedBadgesJson = prefs.getString(badgesKey);
    final currentStreak = prefs.getInt(streakKey) ?? 0;
    final lastVoteDate = prefs.getString(lastVoteDateKey);
    

    
    if (earnedBadgesJson != null) {
      final earnedBadges = Set<String>.from(json.decode(earnedBadgesJson));
      
      for (final badgeId in earnedBadges) {
        final badge = badges[badgeId];
        if (badge != null) {
        }
      }
    }
  }
}