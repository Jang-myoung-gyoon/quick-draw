import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/components/player.dart';
import 'package:quick_draw/components/target.dart';
import 'package:quick_draw/game/quick_draw_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('counts only screen-visible objects toward the spawn target', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));

    final objects = List<FloatingObject>.generate(
      game.targetFloatingObjectCount,
      (index) => SlashTarget()..position = Vector2(120, 80 + index * 48),
    );

    for (var i = 0; i < 4; i++) {
      objects[i].position = Vector2(-200, 120 + i * 80);
    }

    expect(
      game.visibleFloatingObjectCount(objects),
      game.targetFloatingObjectCount - 4,
    );
    expect(game.missingVisibleFloatingObjectCount(objects), 4);
  });

  test('stage level increases object limit by one each level', () {
    final game = QuickDrawGame();

    game.stageLevel = 1;
    expect(game.targetFloatingObjectCount, 9);

    game.stageLevel = 2;
    expect(game.targetFloatingObjectCount, 10);

    game.stageLevel = 5;
    expect(game.targetFloatingObjectCount, 13);
  });

  test('replacement spawn always stays on the top boundary', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));
    game.player = PlayerComponent()..position = Vector2(200, 680);

    for (var i = 0; i < 20; i++) {
      final topSpawn = game.replacementBoundarySpawnPosition(
        existingObjects: const [],
        cameraShift: Vector2(0, 10),
      );
      expect(topSpawn.x, inInclusiveRange(48, 352));
      expect(topSpawn.y, inInclusiveRange(48, 120));

      final horizontalSpawn = game.replacementBoundarySpawnPosition(
        existingObjects: const [],
        cameraShift: Vector2(10, 0),
      );
      expect(horizontalSpawn.x, inInclusiveRange(48, 352));
      expect(horizontalSpawn.y, inInclusiveRange(48, 120));

      final lowerSpawn = game.replacementBoundarySpawnPosition(
        existingObjects: const [],
        cameraShift: Vector2(0, -10),
      );
      expect(lowerSpawn.x, inInclusiveRange(48, 352));
      expect(lowerSpawn.y, inInclusiveRange(48, 120));
    }
  });

  test('level one only spawns simple one-durability targets', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));

    for (var i = 0; i < 20; i++) {
      final object = game.spawnFloatingObjectForTest(120, 120);

      expect(object, isA<SlashTarget>());
      final target = object as SlashTarget;
      expect(target.durability, 1);
      expect(target.remainingDurability, 1);
    }
  });

  test('higher levels can spawn stronger durable targets', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));
    game.stageLevel = 3;

    expect(game.maxTargetDurabilityForStage(1), 1);
    expect(game.maxTargetDurabilityForStage(2), 2);
    expect(game.maxTargetDurabilityForStage(3), 3);
    expect(game.maxTargetDurabilityForStage(4), 4);
    expect(game.maxTargetDurabilityForStage(5), 5);
    expect(game.maxTargetDurabilityForStage(6), 8);
    expect(game.maxTargetDurabilityForStage(13), 15);
    expect(game.laserTargetStageDurabilityBase(2), 1);
    expect(game.laserTargetStageDurabilityBase(3), 3);

    var sawThreeDurabilityTarget = false;
    for (var i = 0; i < 240; i++) {
      final object = game.spawnFloatingObjectForTest(120, 120);
      if (object is SlashTarget && object.durability == 3) {
        sawThreeDurabilityTarget = true;
        break;
      }
    }

    expect(sawThreeDurabilityTarget, isTrue);
  });

  test('stages two through five increase durability smoothly', () {
    final game = QuickDrawGame();

    expect([2, 3, 4, 5].map(game.maxTargetDurabilityForStage).toList(), [
      2,
      3,
      4,
      5,
    ]);
  });

  test('stage two only spawns targets up to two durability', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));
    game.stageLevel = 2;

    for (var i = 0; i < 240; i++) {
      final object = game.spawnFloatingObjectForTest(120, 120);
      if (object is SlashTarget) {
        expect(object.durability, inInclusiveRange(1, 2));
      }
    }
  });

  test('bonus objects use one slot per configured spawn interval', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));
    game.stageLevel = 2;

    for (var i = 0; i < game.bonusSpawnInterval - 1; i++) {
      expect(
        game.spawnFloatingObjectForTest(120, 120),
        isNot(isA<BonusTarget>()),
      );
    }

    expect(game.spawnsSinceLastBonusForTest, game.bonusSpawnInterval - 1);
    expect(game.spawnFloatingObjectForTest(120, 120), isA<BonusTarget>());
    expect(game.spawnsSinceLastBonusForTest, 0);
  });

  test('bonus object spawn interval starts at four hundred objects', () {
    final game = QuickDrawGame();

    expect(game.bonusSpawnInterval, 400);
  });

  test(
    'laser target spawn chance is thirty percent higher and scales by stage',
    () {
      final game = QuickDrawGame();

      game.stageLevel = 1;
      expect(game.laserTargetSpawnChance, 0.0);

      game.stageLevel = 2;
      expect(game.laserTargetSpawnChance, closeTo(0.013, 0.0001));

      game.stageLevel = 3;
      expect(game.laserTargetSpawnChance, closeTo(0.0195, 0.0001));

      game.stageLevel = 6;
      expect(game.laserTargetSpawnChance, closeTo(0.039, 0.0001));
    },
  );

  test('laser targets can spawn after the first level', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));
    game.stageLevel = 2;

    var sawLaserTarget = false;
    for (var i = 0; i < 3000; i++) {
      if (game.spawnFloatingObjectForTest(120, 120) is LaserTarget) {
        sawLaserTarget = true;
        break;
      }
    }

    expect(sawLaserTarget, isTrue);
  });

  test(
    'laser target durability varies from thirty percent lower to current max',
    () {
      final game = QuickDrawGame();
      const stageMaxDurability = 8;
      final minDurability = LaserTarget.minimumDurabilityForStageMax(
        stageMaxDurability,
      );
      final maxDurability = LaserTarget.durabilityForStageMax(
        stageMaxDurability,
      );

      var sawMinRange = false;
      var sawMax = false;
      for (var i = 0; i < 400; i++) {
        final durability = game.laserTargetDurabilityForStage(
          stageMaxDurability,
        );
        expect(durability, inInclusiveRange(minDurability, maxDurability));
        if (durability < maxDurability) {
          sawMinRange = true;
        }
        if (durability == maxDurability) {
          sawMax = true;
        }
      }

      expect(sawMinRange, isTrue);
      expect(sawMax, isTrue);
    },
  );

  test('laser target spawn is not disabled after one appears', () {
    final game = QuickDrawGame()..isPlaying = true;
    game.onGameResize(Vector2(400, 800));
    game.stageLevel = 2;

    for (var i = 0; i < 3000; i++) {
      if (game.spawnFloatingObjectForTest(120, 120) is LaserTarget) {
        break;
      }
    }

    expect(game.laserTargetSpawnChance, closeTo(0.013, 0.0001));

    game.onInputTurnCompleted();

    expect(game.laserTargetSpawnChance, closeTo(0.013, 0.0001));

    game.onInputTurnCompleted();

    expect(game.laserTargetSpawnChance, closeTo(0.013, 0.0001));
  });

  test('offscreen laser targets expose edge indicator positions', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));
    final target = LaserTarget(maxStageDurability: 7)
      ..position = Vector2(-160, 220);

    final indicator = game.laserTargetIndicatorOffsetForTest(target);

    expect(indicator, isNotNull);
    expect(indicator!.dx, 38);
    expect(indicator.dy, 220);

    target.position = Vector2(200, 220);

    expect(game.laserTargetIndicatorOffsetForTest(target), isNull);
  });

  test('long obstacles can spawn as soon as obstacles are available', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));
    game.stageLevel = 2;

    var sawLongObstacle = false;
    for (var i = 0; i < 5000; i++) {
      if (game.spawnFloatingObjectForTest(120, 120) is LongObstacleTarget) {
        sawLongObstacle = true;
        break;
      }
    }

    expect(sawLongObstacle, isTrue);
  });

  test('obstacle spawn chance starts at ten percent and caps at fifty', () {
    final game = QuickDrawGame();

    expect(game.obstacleSpawnChanceForStage(1), 0);
    expect(game.obstacleSpawnChanceForStage(2), closeTo(0.10, 0.001));
    expect(game.obstacleSpawnChanceForStage(3), closeTo(0.15, 0.001));
    expect(game.obstacleSpawnChanceForStage(4), closeTo(0.30, 0.001));
    expect(game.obstacleSpawnChanceForStage(5), closeTo(0.40, 0.001));
    expect(game.obstacleSpawnChanceForStage(6), closeTo(0.50, 0.001));
    expect(game.obstacleSpawnChanceForStage(9), closeTo(0.50, 0.001));
  });

  test('replacement spawns wait for the configured scroll distance', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = (PlayerComponent()..position = Vector2(200, 680));
    game.onGameResize(Vector2(400, 800));

    game.maintainFloatingObjectCountForTest();
    game.processLifecycleEvents();
    expect(game.children.whereType<FloatingObject>(), isEmpty);

    game.addReplacementScrollPixelsForTest(
      game.replacementSpawnPixelsPerObject - 1,
    );
    game.maintainFloatingObjectCountForTest();
    game.processLifecycleEvents();
    expect(game.children.whereType<FloatingObject>(), isEmpty);

    game.addReplacementScrollPixelsForTest(1);
    game.maintainFloatingObjectCountForTest();
    game.processLifecycleEvents();

    expect(game.children.whereType<FloatingObject>(), hasLength(1));
    expect(game.replacementSpawnScrollPixelsForTest(), 0.0);
  });

  test('replacement spawns only during camera scroll', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = (PlayerComponent()..position = Vector2(200, 680));
    game.onGameResize(Vector2(400, 800));

    game.addReplacementScrollPixelsForTest(
      game.replacementSpawnPixelsPerObject * 8,
    );
    game.update(1 / 60);
    game.processLifecycleEvents();

    expect(game.children.whereType<FloatingObject>(), isEmpty);

    game.processReplacementSpawnAfterScrollForTest(
      game.replacementSpawnPixelsPerObject,
    );
    game.processLifecycleEvents();

    expect(game.children.whereType<FloatingObject>(), isNotEmpty);
  });

  test('replacement spawns are blocked while the screen scrolls downward', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = (PlayerComponent()..position = Vector2(200, 680));
    game.onGameResize(Vector2(400, 800));

    game.setReplacementCameraShiftForTest(Vector2(0, -1));
    game.addReplacementScrollPixelsForTest(
      game.replacementSpawnPixelsPerObject,
    );
    game.maintainFloatingObjectCountForTest();
    game.processLifecycleEvents();

    expect(game.children.whereType<FloatingObject>(), isEmpty);
    expect(game.replacementSpawnScrollPixelsForTest(), 0.0);

    game.setReplacementCameraShiftForTest(Vector2(0, 1));
    game.processReplacementSpawnAfterScrollForTest(
      game.replacementSpawnPixelsPerObject,
    );
    game.processLifecycleEvents();

    expect(game.children.whereType<FloatingObject>(), isNotEmpty);
  });

  test('replacement spawns are blocked while the screen scrolls sideways', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = (PlayerComponent()..position = Vector2(200, 680));
    game.onGameResize(Vector2(400, 800));

    game.setReplacementCameraShiftForTest(Vector2(1, 0));
    game.addReplacementScrollPixelsForTest(
      game.replacementSpawnPixelsPerObject,
    );
    game.maintainFloatingObjectCountForTest();
    game.processLifecycleEvents();

    expect(game.children.whereType<FloatingObject>(), isEmpty);
  });

  test('replacement spawn pixel budget shrinks as object limit increases', () {
    final game = QuickDrawGame();

    game.stageLevel = 1;
    expect(game.replacementSpawnPixelsPerObject, 80.0);

    game.stageLevel = 5;
    expect(game.targetFloatingObjectCount, 13);
    expect(game.replacementSpawnPixelsPerObject, 64.0);

    game.stageLevel = 20;
    expect(game.replacementSpawnPixelsPerObject, 40.0);
  });

  test(
    'overlapping floating objects push each other away to limit overlap to 30%',
    () {
      final game = QuickDrawGame();
      game.onGameResize(Vector2(400, 800));

      final objA = SlashTarget()
        ..position = Vector2(200, 200); // size is 48x48, r = 24
      final objB = SlashTarget()
        ..position = Vector2(210, 200); // size is 48x48, r = 24

      game.add(objA);
      game.add(objB);
      game.processLifecycleEvents();

      // Trigger update tick
      game.update(0.016);

      // Bounding radius sum = 48.
      // 30% overlap allowed means distance must be >= 70% of 48 = 33.6.
      final distance = (objA.position - objB.position).length;
      expect(
        distance,
        greaterThanOrEqualTo(33.5),
      ); // using 33.5 to account for floating point
    },
  );
}
