import 'package:shared_preferences/shared_preferences.dart';

import 'friend_ranking.dart';
import 'score_record.dart';

class ScoreRankingStore {
  const ScoreRankingStore();

  static const String scoreRecordsKey = 'quick_draw.scores.records';
  static const String friendRankingCacheKey =
      'quick_draw.rankings.friend_cache';
  static const int maxLocalRecords = 50;

  Future<List<ScoreRecord>> loadLocalScores() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedRecords = prefs.getStringList(scoreRecordsKey) ?? const [];
    final records = <ScoreRecord>[];
    for (final encoded in encodedRecords) {
      try {
        records.add(ScoreRecord.fromJsonString(encoded));
      } catch (_) {
        // Ignore malformed legacy entries.
      }
    }
    return ScoreRecord.sorted(records).take(maxLocalRecords).toList();
  }

  Future<List<ScoreRecord>> recordLocalScore(ScoreRecord record) async {
    final records = ScoreRecord.sorted([
      record,
      ...await loadLocalScores(),
    ]).take(maxLocalRecords).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      scoreRecordsKey,
      records.map((entry) => entry.toJsonString()).toList(growable: false),
    );
    return records;
  }

  Future<FriendRankingSnapshot?> loadFriendRankingCache() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(friendRankingCacheKey);
    if (encoded == null) {
      return null;
    }
    try {
      return FriendRankingSnapshot.fromJsonString(encoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveFriendRankingCache(FriendRankingSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(friendRankingCacheKey, snapshot.toJsonString());
  }
}
