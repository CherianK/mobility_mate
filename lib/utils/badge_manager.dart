import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BadgeManager {
  static const String streakKey = 'voting_streak';
  static const String lastVoteDateKey = 'last_vote_date';
  static const String badgesKey = 'earned_badges';

  // Badge definitions
  static const Map<String, Map<String, dynamic>> badges = {
    'streak_3': {
      'name': '3-Day Streak',
      'description': 'Voted for 3 consecutive days',
      'icon': '🔥',
      'requiredStreak': 3,
    },
    'streak_7': {
      'name': 'Week Warrior',
      'description': 'Voted for 7 consecutive days',
      'icon': '⚡',
      'requiredStreak': 7,
    },
    'streak_14': {
      'name': 'Fortnight Fighter',
      'description': 'Voted for 14 consecutive days',
      'icon': '🌟',
      'requiredStreak': 14,
    },
    'streak_30': {
      'name': 'Monthly Master',
      'description': 'Voted for 30 consecutive days',
      'icon': '👑',
      'requiredStreak': 30,
    },
    'streak_100': {
      'name': 'Century Champion',
      'description': 'Voted for 100 consecutive days',
      'icon': '🏆',
      'requiredStreak': 100,
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
    } else {
      final lastVoteDay = DateTime(lastVoteDate.year, lastVoteDate.month, lastVoteDate.day);
      final yesterday = today.subtract(const Duration(days: 1));

      if (lastVoteDay.isAtSameMomentAs(yesterday)) {
        // Voted yesterday, increment streak
        currentStreak++;
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

  static Future<void> _checkAndAwardBadges(int currentStreak) async {
    final prefs = await SharedPreferences.getInstance();
    final earnedBadgesJson = prefs.getString(badgesKey);
    Set<String> earnedBadges = {};
    
    if (earnedBadgesJson != null) {
      earnedBadges = Set<String>.from(json.decode(earnedBadgesJson));
    }

    // Check each badge
    for (final badge in badges.entries) {
      if (currentStreak >= badge.value['requiredStreak'] && !earnedBadges.contains(badge.key)) {
        earnedBadges.add(badge.key);
      }
    }

    // Save updated badges
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

    return {
      'currentStreak': currentStreak,
      'earnedBadges': earnedBadges,
      'nextBadge': _getNextBadge(currentStreak),
    };
  }

  static Map<String, dynamic>? _getNextBadge(int currentStreak) {
    for (final badge in badges.entries) {
      if (currentStreak < badge.value['requiredStreak']) {
        return {
          'id': badge.key,
          ...badge.value,
          'progress': (currentStreak / badge.value['requiredStreak'] * 100).round(),
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
} 