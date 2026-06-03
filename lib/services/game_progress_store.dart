import 'package:shared_preferences/shared_preferences.dart';

import 'game_progress_snapshot.dart';

class GameProgressStore {
  const GameProgressStore();

  static const String bestStageKey = 'quick_draw.achievements.best_stage';
  static const String bestCharacterKey =
      'quick_draw.achievements.best_character';
  static const String bestScoreKey = 'quick_draw.achievements.best_score';
  static const String selectedUpgradesKey =
      'quick_draw.achievements.selected_upgrades';
  static const String maxedUpgradesKey =
      'quick_draw.achievements.maxed_upgrades';
  static const String acknowledgedKey = 'quick_draw.achievements.acknowledged';
  static const String tutorialCompletedKey = 'quick_draw.tutorial.completed';
  static const String accountUidKey = 'quick_draw.account.uid';
  static const String accountProviderKey = 'quick_draw.account.provider';

  Future<GameProgressSnapshot> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return GameProgressSnapshot(
      bestStageLevel: prefs.getInt(bestStageKey) ?? 1,
      bestCharacterLevel: prefs.getInt(bestCharacterKey) ?? 1,
      bestScore: prefs.getInt(bestScoreKey) ?? 0,
      selectedUpgrades: (prefs.getStringList(selectedUpgradesKey) ?? const [])
          .toSet(),
      maxedUpgrades: (prefs.getStringList(maxedUpgradesKey) ?? const [])
          .toSet(),
      acknowledgedAchievements:
          (prefs.getStringList(acknowledgedKey) ?? const []).toSet(),
      tutorialCompleted: prefs.getBool(tutorialCompletedKey) ?? false,
    );
  }

  Future<void> saveLocal(GameProgressSnapshot progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(bestStageKey, progress.bestStageLevel);
    await prefs.setInt(bestCharacterKey, progress.bestCharacterLevel);
    await prefs.setInt(bestScoreKey, progress.bestScore);
    await prefs.setStringList(
      selectedUpgradesKey,
      progress.selectedUpgrades.toList(growable: false)..sort(),
    );
    await prefs.setStringList(
      maxedUpgradesKey,
      progress.maxedUpgrades.toList(growable: false)..sort(),
    );
    await prefs.setStringList(
      acknowledgedKey,
      progress.acknowledgedAchievements.toList(growable: false)..sort(),
    );
    await prefs.setBool(tutorialCompletedKey, progress.tutorialCompleted);
  }

  Future<void> saveAccount({
    required String uid,
    required String provider,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(accountUidKey, uid);
    await prefs.setString(accountProviderKey, provider);
  }
}
