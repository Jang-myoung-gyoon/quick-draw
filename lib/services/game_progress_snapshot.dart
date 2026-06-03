import 'package:flutter/foundation.dart';

@immutable
class GameProgressSnapshot {
  const GameProgressSnapshot({
    required this.bestStageLevel,
    required this.bestCharacterLevel,
    required this.bestScore,
    required this.selectedUpgrades,
    required this.maxedUpgrades,
    required this.acknowledgedAchievements,
    required this.tutorialCompleted,
  });

  const GameProgressSnapshot.initial()
    : bestStageLevel = 1,
      bestCharacterLevel = 1,
      bestScore = 0,
      selectedUpgrades = const {},
      maxedUpgrades = const {},
      acknowledgedAchievements = const {},
      tutorialCompleted = false;

  final int bestStageLevel;
  final int bestCharacterLevel;
  final int bestScore;
  final Set<String> selectedUpgrades;
  final Set<String> maxedUpgrades;
  final Set<String> acknowledgedAchievements;
  final bool tutorialCompleted;

  GameProgressSnapshot merge(GameProgressSnapshot other) {
    return GameProgressSnapshot(
      bestStageLevel: bestStageLevel > other.bestStageLevel
          ? bestStageLevel
          : other.bestStageLevel,
      bestCharacterLevel: bestCharacterLevel > other.bestCharacterLevel
          ? bestCharacterLevel
          : other.bestCharacterLevel,
      bestScore: bestScore > other.bestScore ? bestScore : other.bestScore,
      selectedUpgrades: {...selectedUpgrades, ...other.selectedUpgrades},
      maxedUpgrades: {...maxedUpgrades, ...other.maxedUpgrades},
      acknowledgedAchievements: {
        ...acknowledgedAchievements,
        ...other.acknowledgedAchievements,
      },
      tutorialCompleted: tutorialCompleted || other.tutorialCompleted,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'bestStageLevel': bestStageLevel,
      'bestCharacterLevel': bestCharacterLevel,
      'bestScore': bestScore,
      'selectedUpgrades': selectedUpgrades.toList(growable: false)..sort(),
      'maxedUpgrades': maxedUpgrades.toList(growable: false)..sort(),
      'acknowledgedAchievements': acknowledgedAchievements.toList(
        growable: false,
      )..sort(),
      'tutorialCompleted': tutorialCompleted,
      'schemaVersion': 1,
    };
  }

  static GameProgressSnapshot fromJson(Map<Object?, Object?> json) {
    return GameProgressSnapshot(
      bestStageLevel: _readInt(json['bestStageLevel'], fallback: 1),
      bestCharacterLevel: _readInt(json['bestCharacterLevel'], fallback: 1),
      bestScore: _readInt(json['bestScore']),
      selectedUpgrades: _readStringSet(json['selectedUpgrades']),
      maxedUpgrades: _readStringSet(json['maxedUpgrades']),
      acknowledgedAchievements: _readStringSet(
        json['acknowledgedAchievements'],
      ),
      tutorialCompleted: json['tutorialCompleted'] == true,
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

  static Set<String> _readStringSet(Object? value) {
    if (value is Iterable) {
      return value.whereType<String>().toSet();
    }
    return const {};
  }

  @override
  bool operator ==(Object other) {
    return other is GameProgressSnapshot &&
        bestStageLevel == other.bestStageLevel &&
        bestCharacterLevel == other.bestCharacterLevel &&
        bestScore == other.bestScore &&
        setEquals(selectedUpgrades, other.selectedUpgrades) &&
        setEquals(maxedUpgrades, other.maxedUpgrades) &&
        setEquals(acknowledgedAchievements, other.acknowledgedAchievements) &&
        tutorialCompleted == other.tutorialCompleted;
  }

  @override
  int get hashCode => Object.hash(
    bestStageLevel,
    bestCharacterLevel,
    bestScore,
    Object.hashAll(selectedUpgrades),
    Object.hashAll(maxedUpgrades),
    Object.hashAll(acknowledgedAchievements),
    tutorialCompleted,
  );
}
