import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class ScoreRecord {
  const ScoreRecord({
    required this.score,
    required this.stageLevel,
    required this.characterLevel,
    required this.playedAtMillis,
    this.achievementScore = 0,
    this.playerName,
    this.uid,
  });

  final int score;
  final int stageLevel;
  final int characterLevel;
  final int playedAtMillis;
  final int achievementScore;
  final String? playerName;
  final String? uid;

  Map<String, Object?> toJson() {
    return {
      'score': score,
      'stageLevel': stageLevel,
      'characterLevel': characterLevel,
      'playedAtMillis': playedAtMillis,
      if (achievementScore > 0) 'achievementScore': achievementScore,
      if (playerName != null) 'playerName': playerName,
      if (uid != null) 'uid': uid,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static ScoreRecord fromJsonString(String value) {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, Object?>) {
      return fromJson(decoded);
    }
    throw const FormatException('Score record must be a JSON object.');
  }

  static ScoreRecord fromJson(Map<Object?, Object?> json) {
    return ScoreRecord(
      score: _readInt(json['score']),
      stageLevel: _readInt(json['stageLevel'], fallback: 1),
      characterLevel: _readInt(json['characterLevel'], fallback: 1),
      playedAtMillis: _readInt(json['playedAtMillis']),
      achievementScore: _readInt(json['achievementScore']),
      playerName: json['playerName'] is String
          ? json['playerName'] as String
          : null,
      uid: json['uid'] is String ? json['uid'] as String : null,
    );
  }

  static List<ScoreRecord> sorted(Iterable<ScoreRecord> records) {
    return records.toList(growable: false)..sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) {
        return scoreOrder;
      }
      return b.playedAtMillis.compareTo(a.playedAtMillis);
    });
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
    return other is ScoreRecord &&
        score == other.score &&
        stageLevel == other.stageLevel &&
        characterLevel == other.characterLevel &&
        playedAtMillis == other.playedAtMillis &&
        achievementScore == other.achievementScore &&
        playerName == other.playerName &&
        uid == other.uid;
  }

  @override
  int get hashCode => Object.hash(
    score,
    stageLevel,
    characterLevel,
    playedAtMillis,
    achievementScore,
    playerName,
    uid,
  );
}
