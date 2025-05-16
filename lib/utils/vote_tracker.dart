import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VoteTracker {
  static const int dailyVoteLimit = 30;
  static const String voteHistoryKey = 'vote_history';

  static Future<bool> canVote() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get vote history
    final voteHistoryJson = prefs.getString(voteHistoryKey);
    List<DateTime> voteHistory = [];
    
    if (voteHistoryJson != null) {
      final List<dynamic> decoded = json.decode(voteHistoryJson);
      voteHistory = decoded.map((timestamp) => 
        DateTime.fromMillisecondsSinceEpoch(timestamp as int)
      ).toList();
    }

    // Filter votes from today
    final todayVotes = voteHistory.where((vote) => 
      vote.year == today.year && 
      vote.month == today.month && 
      vote.day == today.day
    ).length;

    return todayVotes < dailyVoteLimit;
  }

  static Future<int> getRemainingVotes() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get vote history
    final voteHistoryJson = prefs.getString(voteHistoryKey);
    List<DateTime> voteHistory = [];
    
    if (voteHistoryJson != null) {
      final List<dynamic> decoded = json.decode(voteHistoryJson);
      voteHistory = decoded.map((timestamp) => 
        DateTime.fromMillisecondsSinceEpoch(timestamp as int)
      ).toList();
    }

    // Filter votes from today
    final todayVotes = voteHistory.where((vote) => 
      vote.year == today.year && 
      vote.month == today.month && 
      vote.day == today.day
    ).length;

    return dailyVoteLimit - todayVotes;
  }

  static Future<void> recordVote() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Get existing vote history
    final voteHistoryJson = prefs.getString(voteHistoryKey);
    List<DateTime> voteHistory = [];
    
    if (voteHistoryJson != null) {
      final List<dynamic> decoded = json.decode(voteHistoryJson);
      voteHistory = decoded.map((timestamp) => 
        DateTime.fromMillisecondsSinceEpoch(timestamp as int)
      ).toList();
    }

    // Add new vote
    voteHistory.add(now);

    // Keep only last 30 days of history to prevent storage bloat
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    voteHistory = voteHistory.where((vote) => vote.isAfter(thirtyDaysAgo)).toList();

    // Save updated history
    final encoded = json.encode(voteHistory.map((date) => 
      date.millisecondsSinceEpoch
    ).toList());
    await prefs.setString(voteHistoryKey, encoded);
  }

  static Future<void> clearVoteHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(voteHistoryKey);
  }
} 