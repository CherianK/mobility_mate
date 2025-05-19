import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BadgeManager {
  static const String streakKey = 'voting_streak';
  static const String lastVoteDateKey = 'last_vote_date';
  static const String badgesKey = 'earned_badges';
  static const String totalVotesKey = 'total_votes';
  static const String totalUploadsKey = 'total_uploads';
  static const String badgeDatesKey = 'badge_dates';

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
    'upload_50': {
      'name': 'Photo Expert',
      'description': 'Upload 50 photos',
      'icon': '📱',
      'type': 'uploads',
      'requiredUploads': 50,
    },
    'upload_100': {
      'name': 'Photo Legend',
      'description': 'Upload 100 photos',
      'icon': '🏆',
      'type': 'uploads',
      'requiredUploads': 100,
    },
    'upload_250': {
      'name': 'Photo Champion',
      'description': 'Upload 250 photos',
      'icon': '👑',
      'type': 'uploads',
      'requiredUploads': 250,
    },
    'upload_500': {
      'name': 'Photo Grandmaster',
      'description': 'Upload 500 photos',
      'icon': '⭐',
      'type': 'uploads',
      'requiredUploads': 500,
    },
    
    // Special achievement badges
    'first_vote': {
      'name': 'First Vote',
      'description': 'Cast your first vote',
      'icon': '🎉',
      'type': 'special',
      'oneTime': true,
    },
    'top_contributor': {
      'name': 'Top Contributor',
      'description': 'Reached rank #1 on the leaderboard',
      'icon': '👑',
      'type': 'special',
      'oneTime': false,
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

    // Try to get the saved upload count first
    int totalUploads = prefs.getInt(totalUploadsKey) ?? 0;

    // Use leaderboard endpoint to get approved uploads
    final leaderboardResponse = await http.get(
      Uri.parse('https://mobility-mate.onrender.com/api/leaderboard'),
    );

    if (leaderboardResponse.statusCode == 200) {
      final List<dynamic> leaderboardData = json.decode(leaderboardResponse.body);
      
      // Debug the leaderboard data
      print('Leaderboard data: $leaderboardData');
      
      // Find user entry by username
      dynamic userEntry;
      for (var entry in leaderboardData) {
        if (entry['username'] == username) {
          userEntry = entry;
          break;
        }
      }
      
      print('Found user entry: $userEntry');
      
      if (userEntry != null && userEntry['approved_uploads'] != null) {
        totalUploads = userEntry['approved_uploads'];
        // Save this value for future use
        await prefs.setInt(totalUploadsKey, totalUploads);
        print('Updated total uploads from leaderboard: $totalUploads');
      }

      // Print out badge info for debugging
      print('Checking for upload badges with count: $totalUploads');
      
      // Check for upload count badges
      if (totalUploads >= 1) {
        await _awardBadge('upload_1');
      }
      if (totalUploads >= 5) {
        await _awardBadge('upload_5');
      }
      if (totalUploads >= 10) {
        await _awardBadge('upload_10');
      }
      if (totalUploads >= 25) {
        await _awardBadge('upload_25');
      }
      if (totalUploads >= 50) {
        await _awardBadge('upload_50');
      }
      if (totalUploads >= 100) {
        await _awardBadge('upload_100');
      }
      if (totalUploads >= 250) {
        await _awardBadge('upload_250');
      }
      if (totalUploads >= 500) {
        await _awardBadge('upload_500');
      }

      // Check for top contributor badge
      if (leaderboardData.isNotEmpty && leaderboardData[0]['username'] == username) {
        await _awardBadge('top_contributor');
      }
      
      // Force a refresh of badge info after awarding new badges
      await getBadgeInfo();
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
    final uploadBadges = [
      'upload_1',
      'upload_5',
      'upload_10',
      'upload_25',
      'upload_50',
      'upload_100',
      'upload_250',
      'upload_500',
    ];
    
    for (final badgeId in uploadBadges) {
      final badge = badges[badgeId];
      if (badge != null && 
          badge['type'] == 'uploads' && 
          totalUploads >= badge['requiredUploads'] && 
          !earnedBadges.contains(badgeId)) {
        await _awardBadge(badgeId);
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
    
    // For top_contributor badge, we need to check if the user was previously at rank 1
    // and has since dropped and returned to rank 1
    bool shouldAward = true;
    if (badgeId == 'top_contributor') {
      // Get the last time this badge was awarded
      final lastTopRankKey = 'last_top_rank_date';
      final lastTopRankStr = prefs.getString(lastTopRankKey);
      
      if (lastTopRankStr != null) {
        final lastTopRank = DateTime.parse(lastTopRankStr);
        final now = DateTime.now();
        final difference = now.difference(lastTopRank).inDays;
        
        // Only award again if it's been at least 7 days since last time
        // This prevents awarding multiple times during the same "reign"
        if (difference < 7) {
          shouldAward = false;
          print('Not awarding top_contributor badge: last awarded $difference days ago');
        } else {
          print('Re-awarding top_contributor badge after $difference days');
        }
      }
      
      // Update the last top rank date
      await prefs.setString(lastTopRankKey, DateTime.now().toIso8601String());
    } else {
      // For other badges, only award if not already earned
      shouldAward = !earnedBadges.contains(badgeId);
    }
    
    if (shouldAward) {
      earnedBadges.add(badgeId);
      await prefs.setString(badgesKey, json.encode(earnedBadges.toList()));

      // Save date earned for this badge
      final now = DateTime.now();
      final dateStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      // For top_contributor, we want to track multiple dates
      Map<String, dynamic> badgeDates = {};
      final badgeDatesJson = prefs.getString(badgeDatesKey);
      if (badgeDatesJson != null) {
        badgeDates = Map<String, dynamic>.from(json.decode(badgeDatesJson));
      }
      
      if (badgeId == 'top_contributor') {
        // Store dates as a list for top_contributor
        List<String> topDates = [];
        if (badgeDates.containsKey(badgeId)) {
          if (badgeDates[badgeId] is List) {
            topDates = List<String>.from(badgeDates[badgeId]);
          } else if (badgeDates[badgeId] is String) {
            // Convert old format (single string) to list
            topDates = [badgeDates[badgeId]];
          }
        }
        topDates.add(dateStr);
        badgeDates[badgeId] = topDates;
      } else {
        // Regular single date for other badges
        badgeDates[badgeId] = dateStr;
      }
      
      await prefs.setString(badgeDatesKey, json.encode(badgeDates));
      
      print('Awarded badge: $badgeId on $dateStr');
    } else {
      print('Badge already earned: $badgeId');
    }
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
    int totalUploads = prefs.getInt(totalUploadsKey) ?? 0;
    final username = prefs.getString('username');
    if (username != null) {
      final leaderboardResponse = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/api/leaderboard'),
      );
      if (leaderboardResponse.statusCode == 200) {
        final List<dynamic> leaderboardData = json.decode(leaderboardResponse.body);
        
        // Debug the leaderboard data
        print('Leaderboard data in getBadgeInfo: $leaderboardData');
        
        // Find user entry by username
        dynamic userEntry;
        for (var entry in leaderboardData) {
          if (entry['username'] == username) {
            userEntry = entry;
            break;
          }
        }
        
        print('Found user entry in getBadgeInfo: $userEntry');
        
        if (userEntry != null && userEntry['approved_uploads'] != null) {
          totalUploads = userEntry['approved_uploads'];
          await prefs.setInt(totalUploadsKey, totalUploads);
          print('Updated totalUploads in getBadgeInfo: $totalUploads');
        }
        
        // Check if user is currently top ranked and update last top rank date if needed
        if (leaderboardData.isNotEmpty && leaderboardData[0]['username'] == username) {
          print('User is currently top ranked!');
          final lastTopRankKey = 'last_top_rank_date';
          final lastTopRankStr = prefs.getString(lastTopRankKey);
          final now = DateTime.now();
          
          if (lastTopRankStr == null) {
            // First time at top rank
            await prefs.setString(lastTopRankKey, now.toIso8601String());
          }
        }
      }
    }

    // Get badge dates
    Map<String, dynamic> badgeDates = {};
    final badgeDatesJson = prefs.getString(badgeDatesKey);
    if (badgeDatesJson != null) {
      badgeDates = Map<String, dynamic>.from(json.decode(badgeDatesJson));
      print('Retrieved badge dates: $badgeDates');
    } else {
      print('No badge dates found in storage');
    }

    final nextBadge = _getNextBadge(currentStreak, totalVotes, totalUploads);

    final badgeInfo = {
      'currentStreak': currentStreak,
      'totalVotes': totalVotes,
      'totalUploads': totalUploads,
      'earnedBadges': earnedBadges,
      'nextBadge': nextBadge,
      'badgeDates': badgeDates,
    };
    
    print('Returning badge info: $badgeInfo');
    return badgeInfo;
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

    // Ensure badge dates storage is initialized
    if (!prefs.containsKey(badgeDatesKey)) {
      await prefs.setString(badgeDatesKey, json.encode({}));
    }

    // Debug: Print current badge storage state
    print('Badge storage initialized:');
    print('Earned badges: ${prefs.getString(badgesKey)}');
    print('Badge dates: ${prefs.getString(badgeDatesKey)}');
  }

  // Debug method to check badge storage
  static Future<void> debugCheckBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final earnedBadgesJson = prefs.getString(badgesKey);
    // Removed unused variables to fix compile errors
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