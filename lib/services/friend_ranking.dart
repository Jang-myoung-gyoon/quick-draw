import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class FriendRankingEntry {
  const FriendRankingEntry({
    required this.uid,
    required this.score,
    required this.achievementScore,
    required this.stageLevel,
    required this.characterLevel,
    required this.updatedAtMillis,
    this.displayName,
    this.photoUrl,
    this.isCurrentUser = false,
  });

  final String uid;
  final String? displayName;
  final String? photoUrl;
  final int score;
  final int achievementScore;
  final int stageLevel;
  final int characterLevel;
  final int updatedAtMillis;
  final bool isCurrentUser;

  Map<String, Object?> toJson() {
    return {
      'uid': uid,
      if (displayName != null) 'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'score': score,
      'achievementScore': achievementScore,
      'stageLevel': stageLevel,
      'characterLevel': characterLevel,
      'updatedAtMillis': updatedAtMillis,
      'isCurrentUser': isCurrentUser,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static FriendRankingEntry fromJsonString(String value) {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, Object?>) {
      return fromJson(decoded);
    }
    throw const FormatException('Friend ranking entry must be a JSON object.');
  }

  static FriendRankingEntry fromJson(Map<Object?, Object?> json) {
    return FriendRankingEntry(
      uid: json['uid'] is String ? json['uid'] as String : '',
      displayName: json['displayName'] is String
          ? json['displayName'] as String
          : null,
      photoUrl: json['photoUrl'] is String ? json['photoUrl'] as String : null,
      score: _readInt(json['score']),
      achievementScore: _readInt(json['achievementScore']),
      stageLevel: _readInt(json['stageLevel'], fallback: 1),
      characterLevel: _readInt(json['characterLevel'], fallback: 1),
      updatedAtMillis: _readInt(json['updatedAtMillis']),
      isCurrentUser: json['isCurrentUser'] == true,
    );
  }

  static int _readInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) {
    return other is FriendRankingEntry &&
        uid == other.uid &&
        displayName == other.displayName &&
        photoUrl == other.photoUrl &&
        score == other.score &&
        achievementScore == other.achievementScore &&
        stageLevel == other.stageLevel &&
        characterLevel == other.characterLevel &&
        updatedAtMillis == other.updatedAtMillis &&
        isCurrentUser == other.isCurrentUser;
  }

  @override
  int get hashCode => Object.hash(
    uid,
    displayName,
    photoUrl,
    score,
    achievementScore,
    stageLevel,
    characterLevel,
    updatedAtMillis,
    isCurrentUser,
  );
}

@immutable
class FriendRankingSnapshot {
  const FriendRankingSnapshot({
    required this.scoreRanking,
    required this.achievementRanking,
    required this.refreshedAtMillis,
    this.remoteUnavailable = false,
  });

  static const int refreshIntervalMillis = 20 * 60 * 1000;

  final List<FriendRankingEntry> scoreRanking;
  final List<FriendRankingEntry> achievementRanking;
  final int refreshedAtMillis;
  final bool remoteUnavailable;

  int? get currentUserScoreRank => _rankForCurrentUser(scoreRanking);
  int? get currentUserAchievementRank =>
      _rankForCurrentUser(achievementRanking);

  bool canRefreshAt(int nowMillis) {
    return canRefresh(
      refreshedAtMillis: refreshedAtMillis,
      nowMillis: nowMillis,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'refreshedAtMillis': refreshedAtMillis,
      'remoteUnavailable': remoteUnavailable,
      'entries': scoreRanking.map((entry) => entry.toJson()).toList(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static FriendRankingSnapshot fromJsonString(String value) {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, Object?>) {
      final entries = decoded['entries'] is Iterable
          ? (decoded['entries'] as Iterable)
                .whereType<Map<Object?, Object?>>()
                .map(FriendRankingEntry.fromJson)
                .toList()
          : const <FriendRankingEntry>[];
      return fromEntries(
        entries,
        refreshedAtMillis: FriendRankingEntry._readInt(
          decoded['refreshedAtMillis'],
        ),
        remoteUnavailable: decoded['remoteUnavailable'] == true,
      );
    }
    throw const FormatException('Friend ranking cache must be a JSON object.');
  }

  static FriendRankingSnapshot fromEntries(
    Iterable<FriendRankingEntry> entries, {
    required int refreshedAtMillis,
    bool remoteUnavailable = false,
  }) {
    final list = entries.toList(growable: false);
    return FriendRankingSnapshot(
      scoreRanking: _sortedByScore(list),
      achievementRanking: _sortedByAchievement(list),
      refreshedAtMillis: refreshedAtMillis,
      remoteUnavailable: remoteUnavailable,
    );
  }

  static FriendRankingSnapshot localFallback(
    FriendRankingEntry currentUser, {
    required int refreshedAtMillis,
  }) {
    return fromEntries(
      [currentUser],
      refreshedAtMillis: refreshedAtMillis,
      remoteUnavailable: true,
    );
  }

  static bool canRefresh({
    required int refreshedAtMillis,
    required int nowMillis,
  }) {
    if (refreshedAtMillis <= 0) {
      return true;
    }
    return nowMillis - refreshedAtMillis >= refreshIntervalMillis;
  }

  static int? _rankForCurrentUser(List<FriendRankingEntry> entries) {
    final index = entries.indexWhere((entry) => entry.isCurrentUser);
    return index < 0 ? null : index + 1;
  }

  static List<FriendRankingEntry> _sortedByScore(
    Iterable<FriendRankingEntry> entries,
  ) {
    return entries.toList(growable: false)..sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) {
        return scoreOrder;
      }
      return b.updatedAtMillis.compareTo(a.updatedAtMillis);
    });
  }

  static List<FriendRankingEntry> _sortedByAchievement(
    Iterable<FriendRankingEntry> entries,
  ) {
    return entries.toList(growable: false)..sort((a, b) {
      final scoreOrder = b.achievementScore.compareTo(a.achievementScore);
      if (scoreOrder != 0) {
        return scoreOrder;
      }
      return b.updatedAtMillis.compareTo(a.updatedAtMillis);
    });
  }
}
