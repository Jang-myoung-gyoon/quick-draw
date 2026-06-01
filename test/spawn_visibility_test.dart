import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/components/player.dart';
import 'package:quick_draw/components/target.dart';
import 'package:quick_draw/main.dart';

void main() {
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

  test('replacement spawn stays on the entering scroll boundary', () {
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

      final leftSpawn = game.replacementBoundarySpawnPosition(
        existingObjects: const [],
        cameraShift: Vector2(10, 0),
      );
      expect(leftSpawn.x, inInclusiveRange(48, 120));
      expect(leftSpawn.y, inInclusiveRange(48, 752));

      final rightSpawn = game.replacementBoundarySpawnPosition(
        existingObjects: const [],
        cameraShift: Vector2(-10, 0),
      );
      expect(rightSpawn.x, inInclusiveRange(280, 352));
      expect(rightSpawn.y, inInclusiveRange(48, 752));
    }
  });

  test('level one only spawns simple one-hit targets', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));

    for (var i = 0; i < 20; i++) {
      final object = game.spawnFloatingObjectForTest(120, 120);

      expect(object, isA<SlashTarget>());
      final target = object as SlashTarget;
      expect(target.armor, 1);
      expect(target.requiredHits, 1);
    }
  });

  test('higher levels can spawn stronger multi-hit targets', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));
    game.stageLevel = 5;

    var sawAdvancedTarget = false;
    for (var i = 0; i < 80; i++) {
      final object = game.spawnFloatingObjectForTest(120, 120);
      if (object is SlashTarget &&
          (object.armor > 1 || object.requiredHits > 1)) {
        sawAdvancedTarget = true;
        break;
      }
    }

    expect(sawAdvancedTarget, isTrue);
  });

  test('bonus objects can spawn after the first level', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));
    game.stageLevel = 2;

    var sawBonus = false;
    for (var i = 0; i < 2000; i++) {
      if (game.spawnFloatingObjectForTest(120, 120) is BonusTarget) {
        sawBonus = true;
        break;
      }
    }

    expect(sawBonus, isTrue);
  });

  test('bonus object spawn chance starts at one percent', () {
    final game = QuickDrawGame();

    expect(game.bonusSpawnChance, closeTo(0.01, 0.0001));
  });

  test('obstacle spawn chance starts at ten percent and caps at fifty', () {
    final game = QuickDrawGame();

    expect(game.obstacleSpawnChanceForStage(1), 0);
    expect(game.obstacleSpawnChanceForStage(2), closeTo(0.10, 0.001));
    expect(game.obstacleSpawnChanceForStage(3), closeTo(0.20, 0.001));
    expect(game.obstacleSpawnChanceForStage(4), closeTo(0.30, 0.001));
    expect(game.obstacleSpawnChanceForStage(5), closeTo(0.40, 0.001));
    expect(game.obstacleSpawnChanceForStage(6), closeTo(0.50, 0.001));
    expect(game.obstacleSpawnChanceForStage(9), closeTo(0.50, 0.001));
  });

  test('replacement spawns are capped by scrolled pixels', () {
    final game = QuickDrawGame()
      ..isPlaying = true
      ..player = (PlayerComponent()..position = Vector2(200, 680));
    game.onGameResize(Vector2(400, 800));

    game.maintainFloatingObjectCountForTest();
    game.processLifecycleEvents();
    expect(game.children.whereType<FloatingObject>(), isEmpty);

    game.addReplacementSpawnBudgetForTest(
      game.replacementSpawnPixelsPerObject - 1,
    );
    game.maintainFloatingObjectCountForTest();
    game.processLifecycleEvents();
    expect(game.children.whereType<FloatingObject>(), isEmpty);

    game.addReplacementSpawnBudgetForTest(1);
    game.maintainFloatingObjectCountForTest();
    game.processLifecycleEvents();

    expect(game.children.whereType<FloatingObject>(), hasLength(1));
    expect(game.replacementSpawnBudgetForTest(), lessThan(1.0));
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
}
