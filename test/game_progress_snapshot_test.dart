import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/services/game_progress_snapshot.dart';

void main() {
  test('merges local and remote progress without losing unlocked state', () {
    final local = GameProgressSnapshot(
      bestStageLevel: 3,
      bestCharacterLevel: 2,
      bestScore: 1200,
      selectedUpgrades: {'chainLength'},
      maxedUpgrades: const {},
      acknowledgedAchievements: {'score-1000'},
      tutorialCompleted: true,
    );
    final remote = GameProgressSnapshot(
      bestStageLevel: 2,
      bestCharacterLevel: 5,
      bestScore: 900,
      selectedUpgrades: {'bladePower'},
      maxedUpgrades: {'chainLength'},
      acknowledgedAchievements: {'stage-2'},
      tutorialCompleted: false,
    );

    final merged = local.merge(remote);

    expect(merged.bestStageLevel, 3);
    expect(merged.bestCharacterLevel, 5);
    expect(merged.bestScore, 1200);
    expect(merged.selectedUpgrades, {'chainLength', 'bladePower'});
    expect(merged.maxedUpgrades, {'chainLength'});
    expect(merged.acknowledgedAchievements, {'score-1000', 'stage-2'});
    expect(merged.tutorialCompleted, true);
  });

  test('round trips progress through firebase safe json', () {
    final progress = GameProgressSnapshot(
      bestStageLevel: 4,
      bestCharacterLevel: 3,
      bestScore: 5000,
      selectedUpgrades: {'chainLength', 'bladePower'},
      maxedUpgrades: {'chainLength'},
      acknowledgedAchievements: {'score-3000'},
      tutorialCompleted: true,
    );

    final restored = GameProgressSnapshot.fromJson(progress.toJson());

    expect(restored, progress);
  });
}
