import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/components/background.dart';
import 'package:quick_draw/components/effects.dart';
import 'package:quick_draw/components/player.dart';
import 'package:quick_draw/components/target.dart';
import 'package:quick_draw/game/quick_draw_game.dart';
import 'package:quick_draw/overlays/achievements_overlay.dart';
import 'package:quick_draw/overlays/community_overlay.dart';
import 'package:quick_draw/overlays/game_over_overlay.dart';
import 'package:quick_draw/overlays/hud_overlay.dart';
import 'package:quick_draw/overlays/settings_overlay.dart';
import 'package:quick_draw/overlays/start_overlay.dart';
import 'package:quick_draw/overlays/upgrade_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

Achievement? findAchievement(List<Achievement> achievements, String id) {
  for (final achievement in achievements) {
    if (achievement.id == id) {
      return achievement;
    }
  }
  return null;
}

void main() {
  test('level up recommendations offer exactly three upgrades', () {
    final game = QuickDrawGame();

    final choices = game.recommendedUpgradeChoices();

    expect(choices, hasLength(3));
    expect(choices.map((choice) => choice.type).toSet(), hasLength(3));
  });

  test('blade power can be displaced by higher priority choices', () {
    final game = QuickDrawGame()
      ..playerAttackPower = 4
      ..health = 0.2;

    final choices = game.recommendedUpgradeChoices();

    expect(
      choices.map((choice) => choice.type),
      isNot(contains(UpgradeType.bladePower)),
    );
  });

  test('basic upgrade choices show the current stat value', () {
    final game = QuickDrawGame()
      ..playerAttackPower = 4
      ..maxChainLength = 2
      ..scrollEnergyGainMultiplier = 1.25;

    final choices = game.recommendedUpgradeChoices();

    expect(
      choices
          .where((choice) => !choice.isRare)
          .every((choice) => choice.currentValue != null),
      isTrue,
    );
    expect(
      choices
          .firstWhere((choice) => choice.type == UpgradeType.criticalStrike)
          .currentValue,
      '${game.text.current} 0%',
    );
  });

  test('rare upgrades already taken are removed from the rare pool', () {
    final game = QuickDrawGame()
      ..rareUpgradeCount = 0
      ..shieldUnlocked = true
      ..lightfootGaugeUnlocked = true
      ..chainStrikeUnlocked = true;

    expect(game.availableRareUpgradeOptionsForTest(), isEmpty);
    expect(game.rollRareUpgradeForTest(), isNull);
  });

  test('choosing upgrades mutates the matching player stat', () {
    final game = QuickDrawGame();

    game.chooseUpgrade(
      const UpgradeOption(
        type: UpgradeType.bladePower,
        title: 'Blade Power',
        description: 'Increase attack power by 1.',
        color: Color(0xFFFF335F),
      ),
    );

    expect(game.playerAttackPower, 2);
  });

  test('critical strike upgrade adds fifteen percent double damage chance', () {
    final game = QuickDrawGame()..playerAttackPower = 3;

    game.chooseUpgrade(
      const UpgradeOption(
        type: UpgradeType.criticalStrike,
        title: 'Critical Draw',
        description: 'Add +15% chance to deal double damage.',
        color: Color(0xFFFF1744),
      ),
    );

    expect(game.criticalStrikeLevel, 1);
    expect(game.criticalStrikeChance, closeTo(0.15, 0.0001));
    expect(game.rollSlashDamage(roll: 0.14).damage, 6);
    expect(game.rollSlashDamage(roll: 0.14).isCritical, isTrue);
    expect(game.rollSlashDamage(roll: 0.15).damage, 3);
    expect(game.rollSlashDamage(roll: 0.15).isCritical, isFalse);
  });

  testWidgets('game over report shows final levels and upgrade progress', (
    tester,
  ) async {
    final game = QuickDrawGame()
      ..score = 1234
      ..stageLevel = 7
      ..characterLevel = 5
      ..playerAttackPower = 3
      ..criticalStrikeLevel = 2
      ..maxChainLength = 4
      ..shadowCloneLevel = 2
      ..shieldUnlocked = true;

    await tester.pumpWidget(MaterialApp(home: GameOverOverlay(game: game)));

    expect(find.text('Game Over'), findsOneWidget);
    expect(find.text('best ${game.bestScore}'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text(game.text.tryAgain), findsOneWidget);
    expect(
      find.byKey(const ValueKey('game-over-ranking-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('game-over-home-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('game-over-share-button')),
      findsOneWidget,
    );
    expect(find.text(game.text.home), findsNothing);
    expect(find.text(game.text.shareLink), findsNothing);
    expect(find.text('Lv.0'), findsNothing);
    expect(find.text('Lv.2'), findsAtLeastNWidgets(2));
    expect(find.text('Lv.3'), findsOneWidget);
    final bladePowerIcon = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              UpgradeType.bladePower.iconAssetPath,
    );
    expect(bladePowerIcon, findsOneWidget);
    expect(
      find.text(game.text.upgradeTitle(UpgradeType.bladePower)),
      findsNothing,
    );
    await tester.tap(bladePowerIcon);
    await tester.pumpAndSettle();
    expect(
      find.text(game.text.upgradeTitle(UpgradeType.bladePower)),
      findsOneWidget,
    );
    expect(
      find.text(game.text.upgradeDescription(UpgradeType.bladePower)),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                UpgradeType.luck.iconAssetPath,
      ),
      findsNothing,
    );
  });

  test('critical strike upgrade uses the critical icon asset', () {
    expect(
      UpgradeType.criticalStrike.iconAssetPath,
      'assets/images/icons/upgrades/critical_chance.png',
    );
  });

  test('critical hit spawns red critical message effect', () {
    final game = QuickDrawGame();

    game.triggerCriticalHit(Vector2(120, 240));
    game.processLifecycleEvents();

    expect(game.children.whereType<CriticalTextEffect>(), hasLength(1));
  });

  test('missed laser target attacks the player with a laser effect', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..health = 1.0
      ..player = (PlayerComponent()..position = Vector2(200, 680));

    final blockedByShield = game.triggerLaserTargetMissed(Vector2(160, 820));
    game.processLifecycleEvents();

    expect(blockedByShield, isFalse);
    expect(game.health, closeTo(0.7, 0.0001));
    expect(game.children.whereType<LaserBeamEffect>(), hasLength(1));
  });

  test('missed laser target damage waits until slash action resolves', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..health = 1.0
      ..player = (PlayerComponent()
        ..position = Vector2(200, 680)
        ..isDashing = true);

    final blockedByShield = game.triggerLaserTargetMissed(Vector2(160, 820));
    game.processLifecycleEvents();

    expect(blockedByShield, isFalse);
    expect(game.pendingLaserAttackCountForTest, 1);
    expect(game.health, 1.0);
    expect(game.children.whereType<LaserBeamEffect>(), isEmpty);

    game.player.isDashing = false;
    game.resolvePendingLaserAttacks();
    game.processLifecycleEvents();

    expect(game.pendingLaserAttackCountForTest, 0);
    expect(game.health, closeTo(0.7, 0.0001));
    expect(game.children.whereType<LaserBeamEffect>(), hasLength(1));
  });

  test('only rare upgrades are added to HUD skill slots', () {
    final game = QuickDrawGame();

    game.chooseUpgrade(
      const UpgradeOption(
        type: UpgradeType.bladePower,
        title: 'Blade Power',
        description: 'Increase attack power by 1.',
        color: Color(0xFFFF335F),
      ),
    );

    expect(game.acquiredRareUpgrades, isEmpty);

    game.chooseUpgrade(
      const UpgradeOption(
        type: UpgradeType.shield,
        title: 'Guard Seal',
        description: 'Block one collision hit.',
        color: Color(0xFFEAB308),
        isRare: true,
      ),
    );

    expect(game.acquiredRareUpgrades, [UpgradeType.shield]);
  });

  test('shadow clone is a basic upgrade with four levels', () {
    final game = QuickDrawGame();

    expect(
      game.availableRareUpgradeOptionsForTest().map((option) => option.type),
      isNot(contains(UpgradeType.shadowClone)),
    );

    for (var i = 0; i < 4; i++) {
      game.chooseUpgrade(
        const UpgradeOption(
          type: UpgradeType.shadowClone,
          title: 'Shadow Clone',
          description: 'Add one side clone to widen slash range.',
          color: Color(0xFF38BDF8),
        ),
      );
    }

    expect(game.shadowCloneLevel, 4);
    expect(game.rareUpgradeCount, 0);
    expect(game.acquiredRareUpgrades, isEmpty);

    game.chooseUpgrade(
      const UpgradeOption(
        type: UpgradeType.shadowClone,
        title: 'Shadow Clone',
        description: 'Add one side clone to widen slash range.',
        color: Color(0xFF38BDF8),
      ),
    );

    expect(game.shadowCloneLevel, 4);
  });

  test('shadow clone offsets alternate right then left up to two per side', () {
    expect(PlayerComponent.shadowCloneOffsetsForLevel(0), isEmpty);
    expect(PlayerComponent.shadowCloneOffsetsForLevel(1), [60.0]);
    expect(PlayerComponent.shadowCloneOffsetsForLevel(2), [60.0, -60.0]);
    expect(PlayerComponent.shadowCloneOffsetsForLevel(3), [60.0, -60.0, 120.0]);
    expect(PlayerComponent.shadowCloneOffsetsForLevel(4), [
      60.0,
      -60.0,
      120.0,
      -120.0,
    ]);
    expect(PlayerComponent.shadowCloneOffsetsForLevel(5), [
      60.0,
      -60.0,
      120.0,
      -120.0,
    ]);
  });

  test('shadow clone formation is perpendicular to the slash direction', () {
    final upwardOffsets = PlayerComponent.shadowCloneOffsetsForDirection(
      2,
      Vector2(0, -1),
    );
    expect(upwardOffsets[0].x, closeTo(60.0, 0.001));
    expect(upwardOffsets[0].y, closeTo(0.0, 0.001));
    expect(upwardOffsets[1].x, closeTo(-60.0, 0.001));
    expect(upwardOffsets[1].y, closeTo(0.0, 0.001));

    final rightwardOffsets = PlayerComponent.shadowCloneOffsetsForDirection(
      2,
      Vector2(1, 0),
    );
    expect(rightwardOffsets[0].x, closeTo(0.0, 0.001));
    expect(rightwardOffsets[0].y, closeTo(60.0, 0.001));
    expect(rightwardOffsets[1].x, closeTo(0.0, 0.001));
    expect(rightwardOffsets[1].y, closeTo(-60.0, 0.001));
  });

  test('scroll recovery upgrade increases energy gained from scroll', () {
    final game = QuickDrawGame();
    final before = game.energyRechargeForScroll(340, 680);

    game.chooseUpgrade(
      const UpgradeOption(
        type: UpgradeType.scrollRecovery,
        title: 'Aerial Flow',
        description: 'Gain more energy from upward scroll.',
        color: Color(0xFF00FFCC),
      ),
    );

    expect(game.energyRechargeForScroll(340, 680), greaterThan(before));
  });

  test('luck upgrade reduces bonus object spawn interval by ten percent', () {
    final game = QuickDrawGame();

    expect(game.bonusSpawnInterval, 400);

    game.chooseUpgrade(
      const UpgradeOption(
        type: UpgradeType.luck,
        title: 'Luck',
        description: 'Reduce the bonus object spawn interval by 10%.',
        color: Color(0xFFFFD166),
      ),
    );

    expect(game.luckLevel, 1);
    expect(game.bonusSpawnInterval, 360);

    for (var i = 0; i < 10; i++) {
      game.chooseUpgrade(
        const UpgradeOption(
          type: UpgradeType.luck,
          title: 'Luck',
          description: 'Reduce the bonus object spawn interval by 10%.',
          color: Color(0xFFFFD166),
        ),
      );
    }

    expect(game.bonusSpawnInterval, 200);
  });

  test('character experience requirement increases with character level', () {
    final game = QuickDrawGame();

    game.characterLevel = 1;
    final levelOneRequirement = game.experienceRequiredForCharacterLevel;

    game.characterLevel = 2;
    final levelTwoRequirement = game.experienceRequiredForCharacterLevel;

    game.characterLevel = 6;
    final levelSixRequirement = game.experienceRequiredForCharacterLevel;

    expect(levelOneRequirement, 6);
    expect(levelTwoRequirement, 12);
    expect(levelSixRequirement, 76);
    expect(levelTwoRequirement, greaterThan(levelOneRequirement));
    expect(levelSixRequirement, greaterThan(levelTwoRequirement));
    expect(
      levelSixRequirement - levelTwoRequirement,
      greaterThan(levelTwoRequirement - levelOneRequirement),
    );
  });

  test('higher stage targets grant more character experience', () {
    final game = QuickDrawGame();
    final basicTarget = SlashTarget();
    final durableTarget = SlashTarget(durability: 3);

    game.stageLevel = 1;
    expect(game.experienceRewardForTarget(basicTarget), 1);
    expect(game.experienceRewardForTarget(durableTarget), 3);

    game.stageLevel = 6;
    expect(game.experienceRewardForTarget(basicTarget), 2);
    expect(game.experienceRewardForTarget(durableTarget), 5);

    game.stageLevel = 20;
    expect(game.experienceRewardForTarget(basicTarget), 3);
    expect(game.experienceRewardForTarget(durableTarget), 8);
  });

  test('shield absorbs one obstacle hit without health damage', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..shieldUnlocked = true
      ..shieldCharges = 1
      ..health = 0.7;

    final blockedByShield = game.triggerObstacleHit(Vector2(120, 240));

    expect(blockedByShield, isTrue);
    expect(game.shieldCharges, 0);
    expect(game.health, 0.7);

    final unblocked = game.triggerObstacleHit(Vector2(120, 240));

    expect(unblocked, isFalse);
    expect(game.health, closeTo(0.4, 0.0001));
  });

  test('guard seal recharges shield for each slash start', () {
    final game = QuickDrawGame()
      ..shieldUnlocked = true
      ..shieldCharges = 0;

    game.rechargeShieldForSlash();

    expect(game.shieldCharges, 1);
  });

  test('input turns advance the stage level without filling experience', () {
    final game = QuickDrawGame()..isPlaying = true;

    for (var i = 0; i < game.turnsRequiredForNextStage; i++) {
      game.onInputTurnCompleted();
    }

    expect(game.characterLevel, 1);
    expect(game.stageLevel, 2);
    expect(game.isChoosingUpgrade, isFalse);
    expect(game.experience, 0.0);
    expect(game.inputDrainMultiplier, greaterThan(1.0));
  });

  test('stage level advances at a constant turn rate', () {
    final game = QuickDrawGame()..isPlaying = true;

    expect(game.turnsRequiredForNextStage, 5);

    for (var i = 0; i < 5; i++) {
      game.onInputTurnCompleted();
    }
    expect(game.stageLevel, 2);
    expect(game.turnsRequiredForNextStage, 5);

    for (var i = 0; i < 5; i++) {
      game.onInputTurnCompleted();
    }
    expect(game.stageLevel, 3);
    expect(game.turnsRequiredForNextStage, 5);
  });

  test(
    'stage background shifts from sky color toward space by level twenty',
    () {
      final levelOne = FallingBackground.backgroundColorForStage(1);
      final levelTen = FallingBackground.backgroundColorForStage(10);
      final levelTwenty = FallingBackground.backgroundColorForStage(20);
      final levelThirty = FallingBackground.backgroundColorForStage(30);

      expect(levelOne, FallingBackground.skyBackgroundColor);
      expect(levelTen, isNot(levelOne));
      expect(levelTwenty, isNot(levelOne));
      expect(levelThirty, levelTwenty);
      expect(
        levelTwenty,
        Color.lerp(
          FallingBackground.skyBackgroundColor,
          FallingBackground.spaceBackgroundColor,
          FallingBackground.maxSpaceBlendAmount,
        ),
      );
    },
  );

  test('background nearly pauses during slash movement', () {
    final background = FallingBackground();

    expect(background.normalSpeed, greaterThan(200));
    expect(background.dashSpeed, 0);
  });

  test('game loop forces background speed from current player state', () {
    final background = FallingBackground();
    final game = QuickDrawGame()
      ..background = background
      ..player = (PlayerComponent()..isDashing = true);

    game.update(0.016);
    expect(background.currentSpeed, background.dashSpeed);

    game.player.isDashing = false;
    game.update(0.016);
    expect(background.currentSpeed, background.normalSpeed);
  });

  test('achievement list includes upgrade stage character and score goals', () {
    final game = QuickDrawGame()
      ..bestStageLevel = 20
      ..bestCharacterLevel = 7
      ..bestScore = 5200
      ..maxChainLength = 6;

    final achievements = game.achievementsForDisplay();

    expect(
      achievements.where((item) => item.group == AchievementGroup.upgrade),
      hasLength(22),
    );
    expect(
      achievements.where((item) => item.group == AchievementGroup.stage),
      hasLength(5),
    );
    expect(
      achievements.where((item) => item.group == AchievementGroup.character),
      hasLength(5),
    );
    expect(
      achievements.where((item) => item.group == AchievementGroup.score),
      hasLength(6),
    );
    expect(
      achievements.firstWhere((item) => item.id == 'stage-20').unlocked,
      isTrue,
    );
    expect(
      achievements.firstWhere((item) => item.id == 'character-10').unlocked,
      isFalse,
    );
    expect(
      achievements.firstWhere((item) => item.id == 'score-5000').unlocked,
      isTrue,
    );
    expect(
      achievements
          .firstWhere((item) => item.id == 'upgrade-chainLength-maxed')
          .unlocked,
      isTrue,
    );
    expect(
      achievements
          .firstWhere((item) => item.id == 'upgrade-chainLength-selected')
          .unlocked,
      isTrue,
    );
  });

  test(
    'visible achievements wait for confirmation before showing next step',
    () {
      final game = QuickDrawGame()
        ..bestStageLevel = 3
        ..bestCharacterLevel = 4
        ..bestScore = 1200
        ..maxChainLength = 2;

      final visible = game.visibleAchievementsForDisplay();

      expect(findAchievement(visible, 'stage-3'), isNotNull);
      expect(findAchievement(visible, 'stage-5'), isNull);
      expect(findAchievement(visible, 'character-3'), isNotNull);
      expect(findAchievement(visible, 'character-5'), isNull);
      expect(findAchievement(visible, 'score-1000'), isNotNull);
      expect(findAchievement(visible, 'score-3000'), isNull);
      expect(
        findAchievement(visible, 'upgrade-chainLength-selected'),
        isNotNull,
      );
      expect(findAchievement(visible, 'upgrade-chainLength-maxed'), isNull);

      game.acknowledgeAchievement('stage-3');
      game.acknowledgeAchievement('character-3');
      game.acknowledgeAchievement('score-1000');
      game.acknowledgeAchievement('upgrade-chainLength-selected');
      final confirmedVisible = game.visibleAchievementsForDisplay();

      expect(findAchievement(confirmedVisible, 'stage-3'), isNull);
      expect(findAchievement(confirmedVisible, 'stage-5'), isNotNull);
      expect(findAchievement(confirmedVisible, 'character-3'), isNull);
      expect(findAchievement(confirmedVisible, 'character-5'), isNotNull);
      expect(findAchievement(confirmedVisible, 'score-1000'), isNull);
      expect(findAchievement(confirmedVisible, 'score-3000'), isNotNull);
      expect(
        findAchievement(confirmedVisible, 'upgrade-chainLength-selected'),
        isNull,
      );
      expect(
        findAchievement(confirmedVisible, 'upgrade-chainLength-maxed'),
        isNotNull,
      );
    },
  );

  test('achievement unlock shows a queued bottom message', () {
    final game = QuickDrawGame()..score = 900;

    game.triggerTargetSliced(Vector2.zero());
    expect(game.achievementToastMessage, isNull);

    game.update(0.016);

    expect(
      game.achievementToastMessage,
      game.text.achievementUnlocked(game.text.scoreAchievementTitle(1000)),
    );
    expect(game.achievementToastTimer, greaterThan(0));
  });

  test('achievement progress is recorded during gameplay updates', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = PlayerComponent()
      ..stageLevel = 3
      ..score = 5000
      ..characterLevel = 4;

    game.update(0.016);

    final achievements = game.achievementsForDisplay();
    expect(
      achievements.firstWhere((item) => item.id == 'stage-3').unlocked,
      isTrue,
    );
    expect(
      achievements.firstWhere((item) => item.id == 'character-3').unlocked,
      isTrue,
    );
    expect(
      achievements.firstWhere((item) => item.id == 'score-5000').unlocked,
      isTrue,
    );
    expect(game.achievementToastMessage, isNotNull);
  });

  test('achievement progress persists to local storage and restores', () async {
    SharedPreferences.setMockInitialValues({});
    final game = QuickDrawGame()
      ..stageLevel = 3
      ..characterLevel = 4
      ..score = 5000
      ..maxChainLength = 6;
    await game.loadAchievementProgress();

    game.achievementsForDisplay();
    await game.saveAchievementProgress();

    final restored = QuickDrawGame();
    await restored.loadAchievementProgress();
    final achievements = restored.achievementsForDisplay();

    expect(
      achievements.firstWhere((item) => item.id == 'stage-3').unlocked,
      isTrue,
    );
    expect(
      achievements.firstWhere((item) => item.id == 'character-3').unlocked,
      isTrue,
    );
    expect(
      achievements.firstWhere((item) => item.id == 'score-5000').unlocked,
      isTrue,
    );
    expect(
      achievements
          .firstWhere((item) => item.id == 'upgrade-chainLength-maxed')
          .unlocked,
      isTrue,
    );

    game.acknowledgeAchievement('stage-3');
    await game.saveAchievementProgress();
    final acknowledged = QuickDrawGame();
    await acknowledged.loadAchievementProgress();
    expect(acknowledged.acknowledgedAchievementIds.contains('stage-3'), isTrue);
  });

  testWidgets(
    'open achievements overlay refreshes when stage progress changes',
    (tester) async {
      final game = QuickDrawGame()
        ..isPlaying = true
        ..player = PlayerComponent()
        ..stageLevel = 2
        ..bestStageLevel = 2;
      final achievementCount = game.achievementsForDisplay().length;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 780,
            height: 1688,
            child: AchievementsOverlay(game: game),
          ),
        ),
      );

      expect(
        find.text(game.text.stageAchievementTitle(3), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('0 / $achievementCount'), findsOneWidget);

      game.stageLevel = 3;
      game.update(0.016);
      await tester.pump();

      expect(find.text('1 / $achievementCount'), findsOneWidget);
      expect(
        find.text(game.text.stageAchievementTitle(3), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text(game.text.achievementConfirm), findsOneWidget);
      expect(game.bestStageLevel, 3);
      expect(
        game
            .achievementsForDisplay()
            .firstWhere((item) => item.id == 'stage-3')
            .unlocked,
        isTrue,
      );

      final confirmButton = find.text(game.text.achievementConfirm).first;
      await tester.ensureVisible(confirmButton);
      await tester.pump();
      await tester.tap(confirmButton);
      await tester.pump();

      expect(game.acknowledgedAchievementIds.contains('stage-3'), isTrue);
      expect(
        find.text(game.text.stageAchievementTitle(5), skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  test('stage level increases freefall energy drain', () {
    expect(QuickDrawGame.initialPassiveDrainRate, closeTo(0.06435, 0.000001));
    expect(
      QuickDrawGame.inputDrainMultiplierForStage(1),
      closeTo(1.2, 0.000001),
    );
    expect(
      QuickDrawGame.inputDrainMultiplierForStage(20),
      closeTo(1.0 + (20 - 1) * 0.28, 0.000001),
    );

    final levelOneGame = QuickDrawGame()
      ..isPlaying = true
      ..health = 1.0
      ..inputDrainMultiplier = QuickDrawGame.inputDrainMultiplierForStage(1)
      ..player = PlayerComponent();
    levelOneGame.update(1.0);
    final levelOneHealth = levelOneGame.health;

    final highStageGame = QuickDrawGame()
      ..isPlaying = true
      ..health = 1.0
      ..player = PlayerComponent()
      ..stageLevel = 4
      ..inputDrainMultiplier = QuickDrawGame.inputDrainMultiplierForStage(4);
    highStageGame.update(1.0);

    expect(levelOneHealth, closeTo(0.92278, 0.0001));
    expect(highStageGame.health, closeTo(0.8707581, 0.0001));
    expect(highStageGame.health, lessThan(levelOneHealth));
    expect(highStageGame.inputDrainMultiplier, closeTo(2.0084211, 0.001));
  });

  test('removed target objects fill experience after slash completion', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = PlayerComponent();
    game.player.position = Vector2(200, 600);

    for (var i = 0; i < game.experienceRequiredForCharacterLevel - 1; i++) {
      game.triggerTargetSliced(Vector2.zero(), target: SlashTarget());
    }

    expect(game.characterLevel, 1);
    expect(game.stageLevel, 1);
    expect(game.isChoosingUpgrade, isFalse);
    expect(game.experience, 0.0);

    game.collectPendingTargetExperience(animate: false);

    expect(game.experience, closeTo(5 / 6, 0.0001));

    game.triggerTargetSliced(Vector2.zero(), target: SlashTarget());
    expect(game.experience, closeTo(5 / 6, 0.0001));

    game.collectPendingTargetExperience(animate: false);

    expect(game.characterLevel, 2);
    expect(game.stageLevel, 1);
    expect(game.levelUpAnnouncementLevel, 2);
    expect(game.levelUpAnnouncementTitle, 'CHARACTER LEVEL UP');
    expect(game.levelUpAnnouncementTimer, greaterThan(0));
    expect(game.isChoosingUpgrade, isTrue);
    expect(game.currentUpgradeChoices, hasLength(3));
  });

  test('multi hit targets grant extra experience when removed', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = PlayerComponent();
    game.player.position = Vector2(200, 600);

    game.triggerTargetSliced(
      Vector2.zero(),
      target: SlashTarget(durability: 3),
    );

    expect(game.experience, 0.0);

    game.collectPendingTargetExperience(animate: false);

    expect(game.experience, closeTo(0.5, 0.0001));
  });

  test('laser targets grant triple durability experience when removed', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = PlayerComponent()
      ..characterLevel = 6;
    game.player.position = Vector2(200, 600);

    game.triggerTargetSliced(
      Vector2.zero(),
      target: LaserTarget(maxStageDurability: 3),
    );

    expect(game.experience, 0.0);

    game.collectPendingTargetExperience(animate: false);

    expect(game.experience, closeTo(12 / 76, 0.0001));
    expect(game.characterLevel, 6);
  });

  test('laser targets drop yellow energy shards when removed', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = PlayerComponent()
      ..health = 0.4;
    game.player.position = Vector2(200, 600);

    game.triggerTargetSliced(
      Vector2(160, 220),
      target: LaserTarget(maxStageDurability: 3),
    );
    game.processLifecycleEvents();

    expect(game.children.whereType<EnergyShard>(), hasLength(2));

    final shard = game.children.whereType<EnergyShard>().first;
    game.triggerEnergyShardCollected(shard.position);

    expect(game.health, closeTo(0.48, 0.0001));
    expect(game.lastRequestedSoundForTest, GameSound.energyShardAbsorb);
  });

  test(
    'energy shards pause during upgrade choice then resume chasing player',
    () async {
      final game = QuickDrawGame()
        ..isPlaying = true
        ..isChoosingUpgrade = true
        ..player = PlayerComponent();
      game.onGameResize(Vector2(780, 1688));
      await game.add(game.player);
      game.processLifecycleEvents();
      game.player.position = Vector2(320, 620);
      final shard = EnergyShard(position: Vector2(120, 220));
      await game.add(shard);
      game.processLifecycleEvents();

      final pausedPosition = shard.position.clone();
      shard.update(0.3);
      game.update(0.3);

      expect(shard.position.x, closeTo(pausedPosition.x, 0.001));
      expect(shard.position.y, closeTo(pausedPosition.y, 0.001));

      game.isChoosingUpgrade = false;
      final beforeDistance = (shard.position - game.player.position).length;

      shard.update(0.3);

      final afterDistance = (shard.position - game.player.position).length;
      expect(afterDistance, lessThan(beforeDistance));
    },
  );

  test('energy shards wait during upgrade choices before absorption', () async {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..isChoosingUpgrade = true
      ..health = 0.4
      ..player = PlayerComponent();
    game.onGameResize(Vector2(780, 1688));
    await game.add(game.player);
    game.processLifecycleEvents();
    game.player.position = Vector2(320, 620);
    final shard = EnergyShard(position: Vector2(322, 622));
    await game.add(shard);
    game.processLifecycleEvents();

    shard.update(0.3);
    game.update(0.016);

    expect(game.health, closeTo(0.4, 0.0001));
    expect(game.lastRequestedSoundForTest, isNull);

    game.isChoosingUpgrade = false;
    shard.update(0.3);

    expect(game.health, closeTo(0.48, 0.0001));
    expect(game.lastRequestedSoundForTest, GameSound.energyShardAbsorb);
  });

  test('sliced normal targets request the slice sound effect', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = PlayerComponent();
    game.player.position = Vector2(200, 600);

    game.triggerTargetSliced(
      Vector2.zero(),
      target: SlashTarget(durability: 1),
    );

    expect(game.lastRequestedSoundForTest, GameSound.targetSlice);
  });

  test('executing a slash requests the empty slash swing sound', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = PlayerComponent();
    game.onGameResize(Vector2(780, 1688));
    game.add(game.player);
    game.processLifecycleEvents();
    game.player.resetToBasePosition();

    game.addToChain(Vector2(220, 520));

    expect(game.lastRequestedSoundForTest, GameSound.slashSwing);
  });

  test('chain input timer only starts from the first input', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..maxChainLength = 3
      ..player = PlayerComponent();
    game.onGameResize(Vector2(780, 1688));
    game.add(game.player);
    game.processLifecycleEvents();
    game.player.resetToBasePosition();

    game.addToChain(Vector2(220, 520));
    game.chainTimer = 0.8;

    game.addToChain(Vector2(260, 480));

    expect(game.chainTimer, 0.8);
  });

  test(
    'experience shards request the absorb sound when they reach the player',
    () {
      final game = QuickDrawGame()
        ..isPlaying = true
        ..player = PlayerComponent();
      game.player.position = Vector2(200, 600);

      final emitter = ExperienceShardEmitter(
        origins: [Vector2(160, 220), Vector2(180, 240)],
        burstDirection: Vector2(0, 1),
      );
      game.add(emitter);
      game.processLifecycleEvents();

      emitter.update(ExperienceShardEmitter.duration);
      game.processLifecycleEvents();

      expect(game.lastRequestedSoundForTest, GameSound.experienceShardAbsorb);
    },
  );

  test(
    'experience shards chase the current player position after bursting',
    () {
      final game = QuickDrawGame()
        ..isPlaying = true
        ..player = PlayerComponent();
      game.player.position = Vector2(200, 600);

      final emitter = ExperienceShardEmitter(
        origins: [Vector2(160, 220)],
        burstDirection: Vector2(0, 1),
      );
      game.add(emitter);
      game.processLifecycleEvents();

      emitter.update(ExperienceShardEmitter.duration * 0.35);
      game.player.position = Vector2(360, 620);
      final beforeDistance =
          (emitter.shardPositionsForTest.single - game.player.position).length;

      emitter.update(ExperienceShardEmitter.duration * 0.35);
      final afterDistance =
          (emitter.shardPositionsForTest.single - game.player.position).length;

      expect(afterDistance, lessThan(beforeDistance));
    },
  );

  test(
    'experience shards pause during upgrade choice then resume chasing player',
    () {
      final game = QuickDrawGame()
        ..isPlaying = true
        ..isChoosingUpgrade = true
        ..player = PlayerComponent();
      game.player.position = Vector2(200, 600);

      final emitter = ExperienceShardEmitter(
        origins: [Vector2(160, 220)],
        burstDirection: Vector2(0, 1),
      );
      game.add(emitter);
      game.processLifecycleEvents();

      final pausedPosition = emitter.shardPositionsForTest.single;
      emitter.update(ExperienceShardEmitter.duration * 0.6);

      final stillPosition = emitter.shardPositionsForTest.single;
      expect(stillPosition.x, closeTo(pausedPosition.x, 0.001));
      expect(stillPosition.y, closeTo(pausedPosition.y, 0.001));

      game.isChoosingUpgrade = false;
      game.player.position = Vector2(360, 620);

      emitter.update(ExperienceShardEmitter.duration * 0.35);
      final beforeDistance =
          (emitter.shardPositionsForTest.single - game.player.position).length;

      emitter.update(ExperienceShardEmitter.duration * 0.35);
      final afterDistance =
          (emitter.shardPositionsForTest.single - game.player.position).length;

      expect(afterDistance, lessThan(beforeDistance));
    },
  );

  test('experience shards ignore camera shifts during upgrade choice', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..isChoosingUpgrade = true
      ..player = PlayerComponent();
    game.player.position = Vector2(200, 600);

    final emitter = ExperienceShardEmitter(
      origins: [Vector2(160, 220)],
      burstDirection: Vector2(0, 1),
    );
    game.add(emitter);
    game.processLifecycleEvents();

    final pausedPosition = emitter.shardPositionsForTest.single;
    emitter.applyCameraShift(Vector2(0, 240));

    final shiftedPosition = emitter.shardPositionsForTest.single;
    expect(shiftedPosition.x, closeTo(pausedPosition.x, 0.001));
    expect(shiftedPosition.y, closeTo(pausedPosition.y, 0.001));

    game.isChoosingUpgrade = false;
    emitter.applyCameraShift(Vector2(0, 240));

    final resumedPosition = emitter.shardPositionsForTest.single;
    expect(resumedPosition.y, closeTo(pausedPosition.y + 240, 0.001));
  });

  test('default audio levels start at balanced volume', () {
    final game = QuickDrawGame();

    expect(game.masterVolume, 0.5);
    expect(game.bgmVolume, 0.7);
    expect(game.sfxVolume, 1.0);
    expect(game.effectiveBgmVolume, closeTo(0.35, 0.0001));
    expect(game.effectiveSfxVolume, closeTo(0.5, 0.0001));
  });

  test('sound volume multipliers balance UI and shard sounds', () {
    final game = QuickDrawGame()
      ..masterVolume = 0.8
      ..sfxVolume = 0.5;

    expect(game.effectiveSfxVolumeFor(GameSound.targetSlice), 0.4);
    expect(game.effectiveSfxVolumeFor(GameSound.bonusCollect), 0.52);
    expect(game.effectiveSfxVolumeFor(GameSound.uiSelect), 0.4);
    expect(
      game.effectiveSfxVolumeFor(GameSound.uiConfirm),
      closeTo(0.288, 0.0001),
    );
    expect(
      game.effectiveSfxVolumeFor(GameSound.energyShardAbsorb),
      closeTo(0.24, 0.0001),
    );
    expect(
      game.effectiveSfxVolumeFor(GameSound.experienceShardAbsorb),
      closeTo(0.24, 0.0001),
    );
  });

  test(
    'experience shards spawn immediately while experience waits for completion',
    () {
      final game = QuickDrawGame()
        ..isPlaying = true
        ..player = PlayerComponent();
      game.player.position = Vector2(200, 600);

      game.triggerTargetSliced(
        Vector2(160, 220),
        target: SlashTarget(durability: 2),
      );
      game.processLifecycleEvents();

      expect(game.experience, 0.0);
      final emitter =
          game.children.singleWhere((child) => child is ExperienceShardEmitter)
              as ExperienceShardEmitter;
      expect(emitter.origins, hasLength(3));

      game.collectPendingTargetExperience();

      expect(game.experience, closeTo(1 / 3, 0.0001));
    },
  );

  test('one hit targets spawn at least two experience shards', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = PlayerComponent();
    game.player.position = Vector2(200, 600);

    game.triggerTargetSliced(
      Vector2(160, 220),
      target: SlashTarget(durability: 1),
    );
    game.processLifecycleEvents();

    final emitter =
        game.children.singleWhere((child) => child is ExperienceShardEmitter)
            as ExperienceShardEmitter;

    expect(emitter.origins, hasLength(2));
  });

  test('guard seal unlocks a regenerating shield', () {
    final game = QuickDrawGame();
    const rare = UpgradeOption(
      type: UpgradeType.shield,
      title: 'Guard Seal',
      description: 'Block one collision hit.',
      color: Color(0xFFEAB308),
      isRare: true,
    );

    game.chooseUpgrade(rare);

    expect(game.rareUpgradeCount, 1);
    expect(game.shieldUnlocked, isTrue);
    expect(game.shieldCharges, 1);
  });

  test('ultimate protection ignores missed laser attacks', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..health = 0.6
      ..player = (PlayerComponent()..position = Vector2(200, 680));

    game.activateUltimate();
    final blockedByUltimate = game.triggerLaserTargetMissed(Vector2(160, 820));
    game.processLifecycleEvents();

    expect(blockedByUltimate, isTrue);
    expect(game.pendingLaserAttackCountForTest, 0);
    expect(game.health, game.maxHealth);
    expect(game.children.whereType<LaserBeamEffect>(), isEmpty);
  });

  test('lightfoot gauge triggers ultimate and resets when filled', () {
    final game = QuickDrawGame()
      ..player = PlayerComponent()
      ..lightfootGaugeUnlocked = true
      ..health = 0.25;
    game.player.position = Vector2.zero();

    game.addLightfootDistance(QuickDrawGame.lightfootGaugeDistance / 10);

    expect(game.lightfootGauge, closeTo(0.1, 0.0001));
    expect(game.health, 0.25);

    game.addLightfootDistance(QuickDrawGame.lightfootGaugeDistance);

    expect(game.lightfootGauge, 0.0);
    expect(game.health, game.maxHealth);
  });

  test('lightfoot gauge requires fifty percent more distance than before', () {
    final game = QuickDrawGame()
      ..player = PlayerComponent()
      ..lightfootGaugeUnlocked = true;

    game.addLightfootDistance(1600);

    expect(game.lightfootGauge, closeTo(0.0667, 0.0001));
  });

  test(
    'lightfoot ultimate removes floating objects and fills energy',
    () async {
      final game = QuickDrawGame()
        ..player = PlayerComponent()
        ..health = 0.2;
      game.player.position = Vector2(200, 700);
      final obstacle = ObstacleTarget()..position = Vector2(120, 240);

      await game.add(obstacle);
      game.processLifecycleEvents();

      expect(game.children.whereType<FloatingObject>(), isNotEmpty);

      game.activateUltimate();
      game.processLifecycleEvents();

      expect(game.health, game.maxHealth);
      expect(game.children.whereType<FloatingObject>(), isNotEmpty);

      game.executeUltimateCut();
      game.processLifecycleEvents();

      expect(game.children.whereType<FloatingObject>(), isEmpty);
    },
  );

  test(
    'ultimate protection keeps below-screen objects until the cut',
    () async {
      final game = QuickDrawGame()
        ..player = PlayerComponent()
        ..health = 0.4
        ..isPlaying = true;
      game.onGameResize(Vector2(400, 800));
      game.player.position = Vector2(200, 700);
      final obstacle = ObstacleTarget()..position = Vector2(120, 900);

      await game.add(obstacle);
      game.processLifecycleEvents();
      game.activateUltimate();
      obstacle.update(1 / 60);
      game.processLifecycleEvents();

      expect(game.health, game.maxHealth);
      expect(obstacle.parent, isNotNull);

      game.executeUltimateCut();
      game.processLifecycleEvents();

      expect(obstacle.parent, isNull);
    },
  );

  test('bonus object triggers the same vertical slash ultimate', () async {
    final game = QuickDrawGame()
      ..player = PlayerComponent()
      ..health = 0.35;
    game.player.position = Vector2(200, 700);
    final bonus = BonusTarget()..position = Vector2(180, 260);
    final obstacle = ObstacleTarget()..position = Vector2(120, 240);

    await game.add(bonus);
    await game.add(obstacle);
    game.processLifecycleEvents();

    game.triggerBonusCollected(bonus.position);
    game.processLifecycleEvents();

    expect(game.health, game.maxHealth);
    expect(game.children.whereType<FloatingObject>(), isNotEmpty);

    game.executeUltimateCut();
    game.processLifecycleEvents();

    expect(game.children.whereType<FloatingObject>(), isEmpty);
  });

  test('vertical ultimate slash uses a one point five second sprite sheet', () {
    expect(UltimateSlashEffect.frameCount, 24);
    expect(UltimateSlashEffect.columns, 6);
    expect(UltimateSlashEffect.duration, 1.5);
    expect(UltimateSlashEffect.sizeScale, 0.8);
    expect(UltimateSlashEffect.frameDuration, closeTo(1.5 / 24, 0.0001));
    expect(UltimateSlashEffect.frameSize, Vector2(360, 640));
  });

  test('ultimate waits half a second after camera pre-scroll before slash', () {
    expect(PlayerComponent.ultimatePreScrollDuration, 0.5);
  });

  test('camera movement speeds are thirty percent faster', () {
    expect(PlayerComponent.ultimatePreScrollDistance, 195);
    expect(PlayerComponent.cameraFollowSpeed, 3276);
  });

  test('ultimate pre-scroll moves the player to lower screen center', () {
    final viewportSize = Vector2(400, 800);
    final start = Vector2(120, 320);

    expect(
      PlayerComponent.ultimateAnchorForViewport(viewportSize),
      Vector2(200, 624),
    );
    expect(
      PlayerComponent.ultimatePreScrollPosition(
        start: start,
        viewportSize: viewportSize,
        elapsed: 0.25,
      ),
      Vector2(160, 472),
    );
    expect(
      PlayerComponent.ultimatePreScrollPosition(
        start: start,
        viewportSize: viewportSize,
        elapsed: 0.5,
      ),
      Vector2(200, 624),
    );
  });

  test('ultimate slash effect sits between slash start and end', () {
    final game = QuickDrawGame()
      ..player = PlayerComponent()
      ..health = 0.35;
    final start = Vector2(200, 624);
    final end = Vector2(200, -80);

    expect(
      UltimateSlashEffect.centerForSegment(start: start, end: end),
      Vector2(200, 272),
    );
    expect(
      UltimateSlashEffect.heightForSegment(start: start, end: end),
      closeTo(704, 0.001),
    );
    expect(
      UltimateSlashEffect.angleForSegment(start: start, end: end),
      closeTo(0, 0.001),
    );

    game.player.position = start.clone();
    game.player.startUltimateSequence();
    game.executeUltimateCut();
    game.processLifecycleEvents();

    final effects = game.children.whereType<UltimateSlashEffect>();
    expect(effects, hasLength(1));
    expect(effects.single.start, start);
    expect(effects.single.end, end);

    final shift = Vector2(0, 120);
    effects.single.applyCameraShift(shift);
    expect(effects.single.start, start + shift);
    expect(effects.single.end, end + shift);
    expect(effects.single.position, Vector2(200, 272) + shift);
  });

  test('bonus collection does not spawn green slice particles', () {
    final game = QuickDrawGame()
      ..player = PlayerComponent()
      ..health = 0.35;

    game.triggerBonusCollected(Vector2(180, 260));
    game.processLifecycleEvents();

    expect(game.children.whereType<SliceParticleEmitter>(), isEmpty);
    expect(game.health, game.maxHealth);
  });

  testWidgets('bonus attack sound plays one second after collection', (
    tester,
  ) async {
    final game = QuickDrawGame()
      ..player = PlayerComponent()
      ..health = 0.35;

    game.triggerBonusCollected(Vector2(180, 260));

    expect(QuickDrawGame.bonusCollectSoundDelay, const Duration(seconds: 1));
    expect(game.lastRequestedSoundForTest, isNull);

    await tester.pump(const Duration(milliseconds: 999));
    expect(game.lastRequestedSoundForTest, isNull);

    await tester.pump(const Duration(milliseconds: 1));
    expect(game.lastRequestedSoundForTest, GameSound.bonusCollect);
  });

  test('bonus object can be collected along a fast dash movement segment', () {
    expect(
      PlayerComponent.movementTouchesBonus(
        start: Vector2(100, 500),
        end: Vector2(500, 100),
        bonusPosition: Vector2(300, 300),
        radius: 64,
      ),
      isTrue,
    );
    expect(
      PlayerComponent.movementTouchesBonus(
        start: Vector2(100, 500),
        end: Vector2(500, 100),
        bonusPosition: Vector2(100, 100),
        radius: 48,
      ),
      isFalse,
    );
  });

  test(
    'ultimate activation stops the current slash and starts vertical action',
    () {
      final game = QuickDrawGame()
        ..player = PlayerComponent()
        ..health = 0.4;
      game.player.position = Vector2(200, 500);
      game.player.isDashing = true;

      expect(game.player.isDashing, isTrue);

      game.activateUltimate();

      expect(game.health, game.maxHealth);
      expect(game.player.isDashing, isFalse);
      expect(game.player.isPerformingUltimate, isTrue);
    },
  );

  test('battoujutsu sprites only flip when moving right', () {
    expect(
      PlayerComponent.shouldFlipBattoujutsuSpriteForDirection(Vector2(-10, 0)),
      isFalse,
    );
    expect(
      PlayerComponent.shouldFlipBattoujutsuSpriteForDirection(Vector2(10, 0)),
      isTrue,
    );
  });

  test('slash dash movement speed is thirty percent faster', () {
    expect(PlayerComponent.dashSpeed, closeTo(5590.0, 0.001));
  });

  test('game over delay animation uses 32 frames at triple speed', () {
    expect(PlayerComponent.gameOverDelayFrameCount, 32);
    expect(PlayerComponent.gameOverFrameDuration, closeTo(1 / 12, 0.0001));
    expect(PlayerComponent.gameOverDelayFrameIndexForElapsed(0), 0);
    expect(
      PlayerComponent.gameOverDelayFrameIndexForElapsed(
        PlayerComponent.gameOverFrameDuration * 12,
      ),
      12,
    );
    expect(
      PlayerComponent.gameOverDelayFrameIndexForElapsed(
        QuickDrawGame.gameOverDelayDuration,
      ),
      31,
    );
    expect(
      PlayerComponent.gameOverDelaySourceRectForFrame(0),
      const Rect.fromLTWH(0, 0, 212, 374),
    );
    expect(
      PlayerComponent.gameOverDelaySourceRectForFrame(31),
      const Rect.fromLTWH(1484, 1122, 212, 374),
    );
  });

  test('slash dash easing keeps duration but makes the middle fastest', () {
    expect(
      PlayerComponent.dashSegmentDurationForDistance(559),
      closeTo(0.1, 0.001),
    );

    final openingStep =
        PlayerComponent.dashMotionEase(0.1) -
        PlayerComponent.dashMotionEase(0.0);
    final middleStep =
        PlayerComponent.dashMotionEase(0.55) -
        PlayerComponent.dashMotionEase(0.45);
    final closingStep =
        PlayerComponent.dashMotionEase(1.0) -
        PlayerComponent.dashMotionEase(0.9);

    expect(PlayerComponent.dashMotionEase(0), 0);
    expect(PlayerComponent.dashMotionEase(1), 1);
    expect(middleStep, greaterThan(openingStep * 10));
    expect(middleStep, greaterThan(closingStep * 10));
  });

  test('upgrade choice ignores input during the initial lock window', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = PlayerComponent();
    const option = UpgradeOption(
      type: UpgradeType.bladePower,
      title: 'Blade Power',
      description: 'Increase attack power by 1.',
      color: Color(0xFFFF335F),
    );

    game.upgradeInputLockTimer = QuickDrawGame.upgradeInputLockDuration;

    game.chooseUpgrade(option);

    expect(game.playerAttackPower, 1);
    expect(game.lastRequestedSoundForTest, isNull);
    expect(QuickDrawGame.upgradeInputLockDuration, 0.7);

    game.update(0.69);
    expect(game.canChooseUpgrade, isFalse);
    game.update(0.011);
    expect(game.canChooseUpgrade, isTrue);

    game.upgradeInputLockTimer = 0.0;
    game.chooseUpgrade(option);

    expect(game.playerAttackPower, 2);
    expect(game.lastRequestedSoundForTest, GameSound.uiConfirm);
  });

  test('first run tutorial fixes target and chain upgrade flow', () async {
    SharedPreferences.setMockInitialValues({});
    final game = QuickDrawGame();
    await game.onLoad();
    game.onGameResize(Vector2(400, 800));
    game.processLifecycleEvents();
    await game.loadAchievementProgress();

    game.startGame();
    game.processLifecycleEvents();

    expect(game.isTutorialActive, isTrue);
    expect(game.tutorialPhaseForTest, TutorialPhase.firstSlash);
    expect(game.children.whereType<SlashTarget>(), hasLength(1));
    final firstTarget = game.children.whereType<SlashTarget>().single;
    expect(firstTarget.position, game.tutorialFirstTargetPositionForTest);
    expect(firstTarget.opacity, 1.0);
    expect(game.guidedTutorialTapPosition(Vector2.zero()), isNull);
    expect(
      game.guidedTutorialTapPosition(game.tutorialFirstTargetPositionForTest),
      game.tutorialFirstTargetPositionForTest,
    );

    final positionBeforeWait = firstTarget.position.clone();
    final healthBeforeWait = game.health;
    game.update(1);

    expect(firstTarget.position, positionBeforeWait);
    expect(game.health, healthBeforeWait);

    game.triggerTargetSliced(
      game.tutorialFirstTargetPositionForTest,
      target: firstTarget,
    );
    game.collectPendingTargetExperience(animate: false);

    expect(game.characterLevel, 2);
    expect(game.isChoosingUpgrade, isTrue);
    expect(game.tutorialPhaseForTest, TutorialPhase.upgradeChoice);
    expect(game.currentUpgradeChoices, hasLength(3));
    expect(
      game.currentUpgradeChoices.map((choice) => choice.type),
      contains(UpgradeType.chainLength),
    );
    expect(
      game.currentUpgradeChoices.where(game.canChooseUpgradeOption),
      hasLength(1),
    );
    expect(
      game.currentUpgradeChoices.singleWhere(game.canChooseUpgradeOption).type,
      UpgradeType.chainLength,
    );

    game.upgradeInputLockTimer = 0.0;
    game.player.isDashing = true;
    game.chooseUpgrade(
      game.currentUpgradeChoices.firstWhere(
        (choice) => choice.type != UpgradeType.chainLength,
      ),
    );
    expect(game.maxChainLength, 1);
    expect(game.isChoosingUpgrade, isTrue);
    expect(game.tutorialPhaseForTest, TutorialPhase.upgradeChoice);

    game.chooseUpgrade(
      game.currentUpgradeChoices.singleWhere(
        (choice) => choice.type == UpgradeType.chainLength,
      ),
    );
    game.processLifecycleEvents();

    expect(game.maxChainLength, 2);
    expect(game.isChoosingUpgrade, isFalse);
    expect(game.tutorialPhaseForTest, TutorialPhase.chainedSlash);
    expect(game.children.whereType<SlashTarget>(), isEmpty);

    game.player.isDashing = false;
    game.prepareTutorialInputTargetsIfReady();
    game.prepareTutorialInputTargetsIfReady();
    game.processLifecycleEvents();

    expect(game.children.whereType<SlashTarget>(), hasLength(3));
    expect(
      game.children.whereType<SlashTarget>().map((target) => target.position),
      game.tutorialChainTargetPositionsForTest,
    );
    expect(
      game.tutorialChainTargetPositionsForTest[1],
      (game.tutorialChainTapPositionsForTest.first +
              game.tutorialChainTapPositionsForTest.last) *
          0.5,
    );
    expect(
      game.children.whereType<SlashTarget>().map((target) => target.opacity),
      everyElement(1.0),
    );

    game.addToChain(game.tutorialChainTapPositionsForTest.first);
    expect(game.currentChainPoints, hasLength(1));
    expect(game.isTutorialWaitingForInput, isTrue);
    game.prepareTutorialInputTargetsIfReady();
    game.processLifecycleEvents();
    expect(game.children.whereType<SlashTarget>(), hasLength(3));
    expect(game.children.whereType<BonusTarget>(), isEmpty);

    game.addToChain(game.tutorialChainTapPositionsForTest.last);
    expect(game.currentChainPoints, isEmpty);

    game.player.isDashing = false;
    game.onInputTurnCompleted();
    expect(game.isTutorialActive, isTrue);
    expect(game.tutorialPhaseForTest, TutorialPhase.ultimateSlash);
    game.processLifecycleEvents();
    expect(game.children.whereType<SlashTarget>(), isEmpty);
    expect(game.children.whereType<BonusTarget>(), hasLength(1));
    expect(game.guidedTutorialTapPosition(Vector2.zero()), isNull);
    expect(
      game.guidedTutorialTapPosition(
        game.tutorialUltimateTapPositionsForTest.first,
      ),
      game.tutorialUltimateTapPositionsForTest.first,
    );
    expect(game.isTutorialWaitingForInput, isTrue);

    game.addToChain(game.tutorialUltimateTapPositionsForTest.first);
    expect(game.currentChainPoints, hasLength(1));
    expect(game.isTutorialWaitingForInput, isTrue);
    expect(
      game.guidedTutorialTapPosition(
        game.tutorialUltimateTapPositionsForTest.last,
      ),
      game.tutorialUltimateTapPositionsForTest.last,
    );
    expect(
      game.children.whereType<BonusTarget>().single.position,
      game.tutorialBonusTargetPositionForTest,
    );
    expect(
      PlayerComponent.movementTouchesBonus(
        start: game.tutorialUltimateTapPositionsForTest.first,
        end: game.tutorialUltimateTapPositionsForTest.last,
        bonusPosition: game.tutorialBonusTargetPositionForTest,
        radius: 64,
      ),
      isTrue,
    );

    game.addToChain(game.tutorialUltimateTapPositionsForTest.last);
    expect(game.currentChainPoints, isEmpty);
    game.processLifecycleEvents();

    game.triggerBonusCollected(game.tutorialBonusTargetPositionForTest);
    game.onInputTurnCompleted();

    expect(game.isTutorialActive, isFalse);
    expect(game.tutorialCompletedForTest, isTrue);
    expect(game.isPlaying, isTrue);
  });

  test('tutorial runs record half score only for ranking', () {
    final tutorialGame = QuickDrawGame()
      ..score = 1001
      ..resetTutorialStateForNewRun(tutorial: true);

    expect(tutorialGame.score, 1001);
    expect(tutorialGame.finalScoreForRecord, 500);

    tutorialGame.resetTutorialStateForNewRun(tutorial: false);

    expect(tutorialGame.finalScoreForRecord, 1001);
  });

  testWidgets('upgrade overlay renders three horizontal choices', (
    tester,
  ) async {
    final game = QuickDrawGame()
      ..currentUpgradeChoices = const [
        UpgradeOption(
          type: UpgradeType.bladePower,
          title: 'Blade Power',
          description: 'Increase attack power by 1.',
          color: Color(0xFFFF335F),
          currentValue: 'CURRENT 1',
        ),
        UpgradeOption(
          type: UpgradeType.shadowClone,
          title: 'Shadow Clone',
          description: 'Side clones widen slash range.',
          color: Color(0xFF38BDF8),
          currentValue: 'CURRENT 0 / 4',
        ),
        UpgradeOption(
          type: UpgradeType.shield,
          title: 'Guard Seal',
          description: 'Block one collision hit.',
          color: Color(0xFFEAB308),
          isRare: true,
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 780,
          height: 1688,
          child: UpgradeOverlay(game: game),
        ),
      ),
    );

    expect(find.text(game.text.upgrade), findsOneWidget);
    expect(find.text(game.text.characterLevelUp), findsOneWidget);
    expect(find.text(game.text.level(1)), findsOneWidget);
    expect(find.text('CURRENT 1'), findsOneWidget);
    expect(find.text('Blade Power'), findsOneWidget);
    expect(find.text('Shadow Clone'), findsOneWidget);
    expect(find.text('Guard Seal'), findsOneWidget);
  });

  testWidgets('upgrade overlay disables choices during input lock', (
    tester,
  ) async {
    final game = QuickDrawGame()
      ..upgradeInputLockTimer = QuickDrawGame.upgradeInputLockDuration
      ..currentUpgradeChoices = const [
        UpgradeOption(
          type: UpgradeType.bladePower,
          title: 'Blade Power',
          description: 'Increase attack power by 1.',
          color: Color(0xFFFF335F),
        ),
        UpgradeOption(
          type: UpgradeType.chainLength,
          title: 'Longer Chain',
          description: 'Add one more slash waypoint.',
          color: Color(0xFF00E5FF),
        ),
        UpgradeOption(
          type: UpgradeType.luck,
          title: 'Luck',
          description: 'Reduce the bonus object spawn interval by 10%.',
          color: Color(0xFFFFD166),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 780,
          height: 1688,
          child: UpgradeOverlay(game: game),
        ),
      ),
    );

    expect(
      tester
          .widgetList<ElevatedButton>(find.byType(ElevatedButton))
          .every((button) => button.onPressed == null),
      isTrue,
    );

    game.upgradeInputLockTimer = 0.0;
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester
          .widgetList<ElevatedButton>(find.byType(ElevatedButton))
          .every((button) => button.onPressed != null),
      isTrue,
    );
  });

  testWidgets('tutorial upgrade overlay enables only the chain upgrade', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final game = QuickDrawGame();
    await game.onLoad();
    game.onGameResize(Vector2(400, 800));
    game.processLifecycleEvents();
    await game.loadAchievementProgress();
    game.startGame();
    game.processLifecycleEvents();

    final firstTarget = game.children.whereType<SlashTarget>().single;
    game.triggerTargetSliced(
      game.tutorialFirstTargetPositionForTest,
      target: firstTarget,
    );
    game.collectPendingTargetExperience(animate: false);
    game.upgradeInputLockTimer = 0.0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 780,
          height: 1688,
          child: UpgradeOverlay(game: game),
        ),
      ),
    );

    final buttons = tester.widgetList<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(buttons.where((button) => button.onPressed != null), hasLength(1));
    expect(
      find.text(game.text.upgradeTitle(UpgradeType.chainLength)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tutorial-upgrade-choice-hint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tutorial-upgrade-focus')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tutorial-upgrade-disabled-mask')),
      findsNWidgets(2),
    );
  });

  testWidgets('start overlay shows game start and achievements buttons', (
    tester,
  ) async {
    final game = QuickDrawGame();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 780,
          height: 1688,
          child: StartOverlay(game: game),
        ),
      ),
    );

    expect(find.text(game.text.gameStart), findsOneWidget);
    expect(find.text(game.text.achievements), findsOneWidget);
    expect(find.byKey(const ValueKey('home-tutorial-button')), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(
      find.image(const AssetImage(StartOverlay.homeTitleAsset)),
      findsOneWidget,
    );

    final startButton = find.widgetWithText(
      ElevatedButton,
      game.text.gameStart,
    );
    final achievementsButton = find.widgetWithText(
      OutlinedButton,
      game.text.achievements,
    );
    expect(tester.getSize(startButton).width, 420);
    expect(tester.getSize(achievementsButton).width, 420);
    expect(
      tester.getCenter(achievementsButton).dy,
      greaterThan(tester.getCenter(startButton).dy),
    );
    expect(
      tester.getCenter(achievementsButton).dx,
      tester.getCenter(startButton).dx,
    );
  });

  testWidgets('home tutorial button starts a tutorial run', (tester) async {
    SharedPreferences.setMockInitialValues({
      'quick_draw.tutorial.completed': true,
    });
    final game = QuickDrawGame();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 780,
          height: 1688,
          child: GameWidget<QuickDrawGame>(
            game: game,
            overlayBuilderMap: {
              'StartScreen': (context, game) => StartOverlay(game: game),
            },
            initialActiveOverlays: const ['StartScreen'],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('home-tutorial-button')));
    await tester.pump();

    expect(game.lastRequestedSoundForTest, GameSound.uiConfirm);
    expect(game.isTutorialActive, isTrue);
    expect(game.tutorialPhaseForTest, TutorialPhase.firstSlash);
  });

  testWidgets('home achievement button requests the UI select sound', (
    tester,
  ) async {
    final game = QuickDrawGame();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 780,
          height: 1688,
          child: StartOverlay(game: game),
        ),
      ),
    );

    await tester.tap(find.text(game.text.achievements));
    await tester.pump();

    expect(game.lastRequestedSoundForTest, GameSound.uiSelect);
  });

  testWidgets('home mute button toggles master volume mute state', (
    tester,
  ) async {
    final game = QuickDrawGame();
    expect(game.isMuted, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 780,
          height: 1688,
          child: StartOverlay(game: game),
        ),
      ),
    );

    final muteButton = find.byKey(const ValueKey('home-mute-button'));
    expect(muteButton, findsOneWidget);

    // Tap to mute
    await tester.tap(muteButton);
    await tester.pump();
    expect(game.isMuted, isTrue);

    // Tap to unmute
    await tester.tap(muteButton);
    await tester.pump();
    expect(game.isMuted, isFalse);
  });

  testWidgets('community overlay shows nickname editor and Google login', (
    tester,
  ) async {
    final game = QuickDrawGame();

    await tester.pumpWidget(MaterialApp(home: CommunityOverlay(game: game)));

    expect(
      find.byKey(const ValueKey('community-display-name-field')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('community-google-login-button')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('community-apple-login-button')),
      findsOne,
    );
    expect(find.text(game.text.googleLogin), findsOne);
    expect(find.text(game.text.appleLogin), findsOne);
  });

  test('generated sound assets are registered', () {
    expect(GameSound.uiSelect.assetPath, 'elevenlabs/ui_select.mp3');
    expect(GameSound.uiConfirm.assetPath, 'elevenlabs/ui_confirm.mp3');
    expect(
      GameSound.bonusCollect.assetPath,
      'elevenlabs/bonus_ultimate_slash.mp3',
    );
    expect(
      GameSound.uiVolumePreview.assetPath,
      'elevenlabs/ui_volume_preview.mp3',
    );
    expect(GameSound.gameOver.assetPath, 'elevenlabs/game_over.wav');
  });

  test('game over requests the game over sound effect', () {
    final game = QuickDrawGame()..isPlaying = true;

    game.gameOver();

    expect(game.isGameOver, isTrue);
    expect(game.lastRequestedSoundForTest, GameSound.gameOver);
  });

  test('energy depletion delays game over by three seconds', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..health = 0.001
      ..passiveDrainRate = 1.0
      ..player = PlayerComponent();
    game.onGameResize(Vector2(400, 800));

    game.update(0.016);

    expect(game.health, 0.0);
    expect(game.isGameOverPending, isTrue);
    expect(game.isGameOver, isFalse);
    expect(game.isPlaying, isTrue);

    game.update(2.99);

    expect(game.isGameOver, isFalse);

    game.update(0.02);

    expect(game.isGameOverPending, isFalse);
    expect(game.isGameOver, isTrue);
    expect(game.isPlaying, isFalse);
    expect(game.lastRequestedSoundForTest, GameSound.gameOver);
  });

  test('lethal obstacle hit also delays game over', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..health = 0.2
      ..player = PlayerComponent();
    game.onGameResize(Vector2(400, 800));

    game.triggerObstacleHit(Vector2(200, 300));

    expect(game.health, 0.0);
    expect(game.isGameOverPending, isTrue);
    expect(game.isGameOver, isFalse);
  });

  test('shards stop chasing the player during game over delay', () async {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = (PlayerComponent()..position = Vector2(360, 360));
    game.onGameResize(Vector2(400, 800));
    final energyShard = EnergyShard(position: Vector2(40, 40));
    final experienceEmitter = ExperienceShardEmitter(
      origins: [Vector2(60, 60)],
      burstDirection: Vector2(0, 1),
    );
    await game.add(energyShard);
    await game.add(experienceEmitter);
    game.processLifecycleEvents();

    energyShard.update(0.4);
    experienceEmitter.update(0.4);
    final energyBefore = energyShard.position.clone();
    final experienceBefore = experienceEmitter.shardPositionsForTest.single;

    game.beginDelayedGameOver();
    energyShard.update(0.2);
    experienceEmitter.update(0.2);

    expect(energyShard.position, energyBefore);
    expect(experienceEmitter.shardPositionsForTest.single, experienceBefore);
  });

  test('starting a new game clears lingering gameplay effects', () async {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(780, 1688));
    game.player = PlayerComponent();
    await game.add(game.player);
    await game.add(EnergyShard(position: Vector2(100, 100)));
    await game.add(
      ExperienceShardEmitter(
        origins: [Vector2(140, 140)],
        burstDirection: Vector2(0, 1),
      ),
    );
    await game.add(
      LaserBeamEffect(start: Vector2(0, 0), end: Vector2(120, 120)),
    );
    await game.add(CriticalTextEffect(position: Vector2(200, 200)));
    await game.add(
      SliceParticleEmitter(
        position: Vector2(180, 180),
        color: const Color(0xFFFFFFFF),
      ),
    );
    await game.add(
      SlicedHalfComponent(
        position: Vector2(180, 180),
        angle: 0,
        isLeft: true,
        color: const Color(0xFFFFFFFF),
      ),
    );
    game.processLifecycleEvents();
    game.player.startChainDash([Vector2(300, 400)]);

    game.startGame();
    game.processLifecycleEvents();

    expect(game.children.whereType<EnergyShard>(), isEmpty);
    expect(game.children.whereType<ExperienceShardEmitter>(), isEmpty);
    expect(game.children.whereType<LaserBeamEffect>(), isEmpty);
    expect(game.children.whereType<CriticalTextEffect>(), isEmpty);
    expect(game.children.whereType<SliceParticleEmitter>(), isEmpty);
    expect(game.children.whereType<SlicedHalfComponent>(), isEmpty);
    expect(game.player.isResolvingAction, isFalse);
    expect(game.currentChainPoints, isEmpty);
    expect(game.health, game.maxHealth);
  });

  testWidgets('achievements overlay renders grouped achievement progress', (
    tester,
  ) async {
    final game = QuickDrawGame()
      ..bestStageLevel = 3
      ..bestCharacterLevel = 2
      ..bestScore = 1200
      ..shadowCloneLevel = 4;
    game.acknowledgedAchievementIds.add('upgrade-shadowClone-selected');

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 780,
          height: 1688,
          child: AchievementsOverlay(game: game),
        ),
      ),
    );

    expect(find.text(game.text.achievements), findsOneWidget);
    expect(find.text(game.text.upgrades), findsOneWidget);
    expect(
      find.text(game.text.stageLevel, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(game.text.characterLevel, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text(game.text.score, skipOffstage: false), findsOneWidget);
    expect(
      find.text(game.text.stageAchievementTitle(3), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(game.text.masteredAchievementTitle(UpgradeType.shadowClone)),
      findsOneWidget,
    );
  });

  testWidgets('hud renders achievement toast as one bottom line', (
    tester,
  ) async {
    final game = QuickDrawGame()
      ..achievementToastMessage = 'ACHIEVEMENT UNLOCKED: 1000 Score'
      ..achievementToastTimer = 3.0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 780,
          height: 1688,
          child: Stack(children: [HUDOverlay(game: game)]),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('achievement-toast')), findsOneWidget);
    expect(find.text('ACHIEVEMENT UNLOCKED: 1000 Score'), findsOneWidget);
  });

  testWidgets('settings button requests the UI select sound', (tester) async {
    final game = QuickDrawGame();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 780,
          height: 1688,
          child: Stack(children: [HUDOverlay(game: game)]),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pump();

    expect(game.lastRequestedSoundForTest, GameSound.uiSelect);
  });

  testWidgets('level up announcements use distinct colors by level type', (
    tester,
  ) async {
    final game = QuickDrawGame()
      ..levelUpAnnouncementTitle = 'CHARACTER LEVEL UP'
      ..levelUpAnnouncementLevel = 2
      ..currentUpgradeChoices = const [
        UpgradeOption(
          type: UpgradeType.bladePower,
          title: 'Blade Power',
          description: 'Raise attack power.',
          color: Color(0xFFFF335F),
          currentValue: 'CURRENT 1',
        ),
        UpgradeOption(
          type: UpgradeType.scrollRecovery,
          title: 'Wind Recovery',
          description: 'Recover more energy from scroll.',
          color: Color(0xFF38BDF8),
          currentValue: 'CURRENT 1.0x',
        ),
        UpgradeOption(
          type: UpgradeType.focusTime,
          title: 'Focus Time',
          description: 'More input time.',
          color: Color(0xFFEAB308),
          currentValue: 'CURRENT 1.0s',
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 780,
          height: 1688,
          child: UpgradeOverlay(game: game),
        ),
      ),
    );

    final characterTitle = tester.widget<Text>(
      find.text(game.text.characterLevelUp),
    );
    final characterLevel = tester.widget<Text>(find.text(game.text.level(2)));

    game.levelUpAnnouncementTitle = 'STAGE LEVEL UP';
    game.levelUpAnnouncementLevel = 3;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 780,
          height: 1688,
          child: UpgradeOverlay(game: game),
        ),
      ),
    );

    final stageTitle = tester.widget<Text>(find.text(game.text.stageLevelUp));
    final stageLevel = tester.widget<Text>(find.text(game.text.level(3)));

    expect(characterTitle.style?.color, isNot(stageTitle.style?.color));
    expect(characterLevel.style?.color, isNot(stageLevel.style?.color));
  });

  testWidgets('hud shows exactly two rare skill slots', (tester) async {
    final game = QuickDrawGame()
      ..score = 1200
      ..acquiredRareUpgrades.addAll([
        UpgradeType.shield,
        UpgradeType.lightfootGauge,
        UpgradeType.chainStrike,
      ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(children: [HUDOverlay(game: game)]),
      ),
    );

    expect(find.byKey(const ValueKey('rare-skill-slot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('rare-skill-slot-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('rare-skill-slot-2')), findsNothing);
  });

  testWidgets('settings overlay adjusts master bgm and sfx volume', (
    tester,
  ) async {
    final game = QuickDrawGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(children: [SettingsOverlay(game: game)]),
      ),
    );

    expect(find.text(game.text.settings), findsOneWidget);
    expect(find.text(game.text.master), findsOneWidget);
    expect(find.text(game.text.bgm), findsOneWidget);
    expect(find.text(game.text.sfx), findsOneWidget);
    expect(find.text(game.text.languageLabel), findsOneWidget);

    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders, hasLength(3));

    sliders[0].onChanged?.call(0.7);
    expect(game.lastRequestedSoundForTest, GameSound.uiVolumePreview);
    sliders[1].onChanged?.call(0.4);
    expect(game.lastRequestedSoundForTest, GameSound.uiVolumePreview);
    sliders[2].onChanged?.call(0.25);
    expect(game.lastRequestedSoundForTest, GameSound.uiVolumePreview);
    await tester.pump();

    expect(game.masterVolume, 0.7);
    expect(game.bgmVolume, 0.4);
    expect(game.sfxVolume, 0.25);
    expect(game.effectiveBgmVolume, closeTo(0.28, 0.001));
    expect(game.effectiveSfxVolume, closeTo(0.175, 0.001));
  });

  testWidgets('settings overlay switches text language packs', (tester) async {
    final game = QuickDrawGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(children: [SettingsOverlay(game: game)]),
      ),
    );

    expect(find.text('설정'), findsOneWidget);
    expect(find.text('SETTINGS'), findsNothing);

    await tester.tap(find.text('영어'));
    await tester.pump();

    expect(game.language, GameLanguage.en);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('설정'), findsNothing);
  });

  test('settings pause and close resumes an active run', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = PlayerComponent();

    game.openSettings();

    expect(game.paused, isTrue);

    game.closeSettings();

    expect(game.paused, isFalse);
  });

  test('system back only closes allowed UI overlays', () {
    final game = QuickDrawGame();
    game.overlays.addEntry(
      'AchievementsScreen',
      (context, game) => const SizedBox.shrink(),
    );
    game.overlays.addEntry(
      'SettingsScreen',
      (context, game) => const SizedBox.shrink(),
    );
    game.overlays.addEntry(
      'UpgradeScreen',
      (context, game) => const SizedBox.shrink(),
    );

    expect(game.handleSystemBack(), isFalse);

    game.overlays.add('AchievementsScreen');
    expect(game.handleSystemBack(), isTrue);
    expect(game.overlays.activeOverlays, isNot(contains('AchievementsScreen')));

    game.overlays.add('UpgradeScreen');
    expect(game.handleSystemBack(), isFalse);
    expect(game.overlays.activeOverlays, contains('UpgradeScreen'));

    game.overlays.add('SettingsScreen');
    expect(game.handleSystemBack(), isTrue);
    expect(game.overlays.activeOverlays, isNot(contains('SettingsScreen')));
    expect(game.overlays.activeOverlays, contains('UpgradeScreen'));
  });

  testWidgets('settings home button stops the run and returns home', (
    tester,
  ) async {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = PlayerComponent();
    game.pauseEngine();

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(children: [SettingsOverlay(game: game)]),
      ),
    );

    final homeButton = find.byKey(const ValueKey('settings-home-button'));
    await tester.ensureVisible(homeButton);
    await tester.tap(homeButton);
    await tester.pump();

    expect(game.isPlaying, isFalse);
    expect(game.isGameOver, isFalse);
    expect(game.paused, isFalse);
  });
}
