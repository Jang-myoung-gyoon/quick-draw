import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/components/effects.dart';
import 'package:quick_draw/components/player.dart';
import 'package:quick_draw/components/target.dart';
import 'package:quick_draw/main.dart';

void main() {
  test('level up recommendations offer exactly three upgrades', () {
    final game = QuickDrawGame();

    final choices = game.recommendedUpgradeChoices();

    expect(choices, hasLength(3));
    expect(choices.map((choice) => choice.type).toSet(), hasLength(3));
  });

  test('blade power is always offered as an upgrade choice', () {
    final game = QuickDrawGame()..playerAttackPower = 4;

    final choices = game.recommendedUpgradeChoices();

    expect(
      choices.map((choice) => choice.type),
      contains(UpgradeType.bladePower),
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
          .firstWhere((choice) => choice.type == UpgradeType.bladePower)
          .currentValue,
      'CURRENT 4',
    );
  });

  test('rare upgrades already taken are removed from the rare pool', () {
    final game = QuickDrawGame()
      ..rareUpgradeCount = 0
      ..shadowCloneLevel = 1
      ..shieldUnlocked = true
      ..lightfootGaugeUnlocked = true
      ..chainStrikeUnlocked = true;

    expect(game.availableRareUpgradeOptionsForTest(), isEmpty);
    expect(game.rollRareUpgradeForTest(), isNull);
  });

  test('choosing upgrades mutates the matching player stat', () {
    final game = QuickDrawGame();

    game.chooseUpgrade(
      game.recommendedUpgradeChoices().firstWhere(
        (choice) => choice.type == UpgradeType.bladePower,
      ),
    );

    expect(game.playerAttackPower, 2);
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

  test(
    'luck upgrade increases bonus object spawn chance by half a percent',
    () {
      final game = QuickDrawGame();

      expect(game.bonusSpawnChance, closeTo(0.01, 0.0001));

      game.chooseUpgrade(
        const UpgradeOption(
          type: UpgradeType.luck,
          title: 'Luck',
          description: 'Bonus object spawn chance +0.5%.',
          color: Color(0xFFFFD166),
        ),
      );

      expect(game.luckLevel, 1);
      expect(game.bonusSpawnChance, closeTo(0.015, 0.0001));
    },
  );

  test('character experience requirement increases with character level', () {
    final game = QuickDrawGame();

    game.characterLevel = 1;
    final levelOneRequirement = game.experienceRequiredForCharacterLevel;

    game.characterLevel = 2;
    final levelTwoRequirement = game.experienceRequiredForCharacterLevel;

    game.characterLevel = 6;
    final levelSixRequirement = game.experienceRequiredForCharacterLevel;

    expect(levelTwoRequirement, greaterThan(levelOneRequirement));
    expect(levelSixRequirement, greaterThan(levelTwoRequirement));
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

  test('stage level increases freefall energy drain', () {
    final levelOneGame = QuickDrawGame()
      ..isPlaying = true
      ..health = 1.0
      ..player = PlayerComponent();
    levelOneGame.update(1.0);
    final levelOneHealth = levelOneGame.health;

    final highStageGame = QuickDrawGame()
      ..isPlaying = true
      ..health = 1.0
      ..player = PlayerComponent()
      ..stageLevel = 4
      ..inputDrainMultiplier = 1.0 + (4 - 1) * 0.28;
    highStageGame.update(1.0);

    expect(highStageGame.health, lessThan(levelOneHealth));
    expect(highStageGame.inputDrainMultiplier, closeTo(1.84, 0.001));
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

    expect(game.experience, closeTo(0.8, 0.0001));

    game.triggerTargetSliced(Vector2.zero(), target: SlashTarget());
    expect(game.experience, closeTo(0.8, 0.0001));

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
      target: SlashTarget(requiredHits: 3),
    );

    expect(game.experience, 0.0);

    game.collectPendingTargetExperience(animate: false);

    expect(game.experience, closeTo(0.6, 0.0001));
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
        target: SlashTarget(requiredHits: 2),
      );
      game.processLifecycleEvents();

      expect(game.experience, 0.0);
      final emitter =
          game.children.singleWhere((child) => child is ExperienceShardEmitter)
              as ExperienceShardEmitter;
      expect(emitter.origins, hasLength(3));

      game.collectPendingTargetExperience();

      expect(game.experience, closeTo(0.4, 0.0001));
    },
  );

  test('one hit targets spawn at least two experience shards', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = PlayerComponent();
    game.player.position = Vector2(200, 600);

    game.triggerTargetSliced(
      Vector2(160, 220),
      target: SlashTarget(requiredHits: 1),
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

  test(
    'lightfoot gauge is ten times harder to fill than the old threshold',
    () {
      final game = QuickDrawGame()
        ..player = PlayerComponent()
        ..lightfootGaugeUnlocked = true;

      game.addLightfootDistance(1600);

      expect(game.lightfootGauge, closeTo(0.1, 0.0001));
    },
  );

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
          isRare: true,
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

    expect(find.text('UPGRADE'), findsOneWidget);
    expect(find.text('CHARACTER LEVEL UP'), findsOneWidget);
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('CURRENT 1'), findsOneWidget);
    expect(find.text('Blade Power'), findsOneWidget);
    expect(find.text('Shadow Clone'), findsOneWidget);
    expect(find.text('Guard Seal'), findsOneWidget);
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

    final characterTitle = tester.widget<Text>(find.text('CHARACTER LEVEL UP'));
    final characterLevel = tester.widget<Text>(find.text('LEVEL 2'));

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

    final stageTitle = tester.widget<Text>(find.text('STAGE LEVEL UP'));
    final stageLevel = tester.widget<Text>(find.text('LEVEL 3'));

    expect(characterTitle.style?.color, isNot(stageTitle.style?.color));
    expect(characterLevel.style?.color, isNot(stageLevel.style?.color));
  });

  testWidgets('hud shows exactly two rare skill slots', (tester) async {
    final game = QuickDrawGame()
      ..score = 1200
      ..acquiredRareUpgrades.addAll([
        UpgradeType.shield,
        UpgradeType.shadowClone,
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
}
