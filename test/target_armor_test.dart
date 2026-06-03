import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/components/player.dart';
import 'package:quick_draw/components/target.dart';
import 'package:quick_draw/game/quick_draw_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('durability requires separate rearmed hits to slice', () {
    final target = SlashTarget(durability: 2);
    final hitPosition = Vector2(100, 100);

    expect(target.durability, 2);
    expect(target.remainingDurability, 2);
    expect(target.hit(hitPosition), TargetHitOutcome.damaged);
    expect(target.remainingDurability, 1);

    expect(target.hit(hitPosition), TargetHitOutcome.ignored);
    expect(target.remainingDurability, 1);

    target.rearmDamageIfFarFrom(
      hitPosition + Vector2(SlashTarget.damageRearmDistance, 0),
    );

    expect(target.hit(hitPosition), TargetHitOutcome.sliced);
    expect(target.remainingDurability, 0);
  });

  test('attack power reduces durability by damage amount', () {
    final target = SlashTarget(durability: 3);
    final hitPosition = Vector2(100, 100);

    expect(target.hit(hitPosition, attackPower: 2), TargetHitOutcome.damaged);
    expect(target.remainingDurability, 1);

    target.rearmDamageIfFarFrom(
      hitPosition + Vector2(SlashTarget.damageRearmDistance, 0),
    );

    expect(target.hit(hitPosition, attackPower: 2), TargetHitOutcome.sliced);
    expect(target.remainingDurability, 0);
  });

  test('obstacles are larger with matching hit radius', () {
    final obstacle = ObstacleTarget();

    expect(obstacle.size.x, 72);
    expect(obstacle.size.y, 72);
    expect(ObstacleTarget.collisionRadius, 60);
  });

  test('long obstacles use elongated size and matching collision radius', () {
    final obstacle = LongObstacleTarget();

    expect(obstacle.size.x, 54);
    expect(obstacle.size.y, closeTo(LongObstacleTarget.longHeight, 0.001));
    expect(
      obstacle.pathCollisionRadius,
      closeTo(LongObstacleTarget.longHeight / 2, 0.001),
    );
    expect(
      obstacle.touchCollisionRadius,
      closeTo(LongObstacleTarget.longHeight / 2, 0.001),
    );
  });

  test('long obstacles do not rotate after spawn', () {
    final obstacle = LongObstacleTarget();

    expect(obstacle.rotationSpeed, 0.0);
  });

  test(
    'laser targets have thirty percent more durability than stage maximum',
    () {
      final target = LaserTarget(maxStageDurability: 7);

      expect(target.durability, 10);
      expect(LaserTarget.minimumDurabilityForStageMax(7), 7);
      expect(LaserTarget.durabilityForStageMax(15), 20);
      expect(LaserTarget.durabilityForStageMax(30), 20);
    },
  );

  test('laser targets grant triple experience value', () {
    final target = LaserTarget(maxStageDurability: 7);

    expect(target.experienceValue, 30);
    expect(target.experienceValue, target.durability * 3);
  });

  test('laser target sprite animation uses eight frames over two seconds', () {
    final target = LaserTarget(maxStageDurability: 7);

    expect(LaserTarget.spriteAnimationFrameCount, 8);
    expect(LaserTarget.spriteAnimationSheetColumns, 4);
    expect(LaserTarget.spriteAnimationSheetRows, 2);
    expect(LaserTarget.spriteAnimationDuration, 2.0);
    expect(LaserTarget.spriteFrameStepTime, closeTo(0.25, 0.0001));
    expect(target.size.x, closeTo(LaserTarget.laserDrawSize, 0.0001));
    expect(target.size.y, closeTo(LaserTarget.laserDrawSize, 0.0001));
    expect(target.pathHitRadius, LaserTarget.laserHitRadius);
    expect(target.currentSliceSpritePath, LaserTarget.spriteAnimationSheetPath);
  });

  test('laser target health bar segments follow required hit count', () {
    final target = LaserTarget(maxStageDurability: 7, durability: 10);

    expect(target.healthBarSegmentCountForAttackPower(2), 5);
    expect(target.filledHealthBarSegmentsForAttackPower(2), 5);

    target.hit(Vector2.zero(), attackPower: 2);
    expect(target.remainingDurability, 8);
    expect(target.filledHealthBarSegmentsForAttackPower(2), 4);

    target.rearmDamageIfFarFrom(Vector2(SlashTarget.damageRearmDistance, 0));
    target.hit(Vector2(SlashTarget.damageRearmDistance, 0), attackPower: 2);
    expect(target.remainingDurability, 6);
    expect(target.filledHealthBarSegmentsForAttackPower(2), 3);
  });

  test('laser targets ignore normal side drift within half-screen margin', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));
    final target = LaserTarget(maxStageDurability: 7);
    game.add(target);
    game.processLifecycleEvents();

    target.position = Vector2(-200, 100);
    expect(target.shouldRemoveAsMissed(), isFalse);

    target.position = Vector2(600, 100);
    expect(target.shouldRemoveAsMissed(), isFalse);
  });

  test('laser targets miss outside side, top, and bottom bounds', () {
    final game = QuickDrawGame();
    game.onGameResize(Vector2(400, 800));
    final target = LaserTarget(maxStageDurability: 7);
    game.add(target);
    game.processLifecycleEvents();

    target.position = Vector2(-201, 100);
    expect(target.shouldRemoveAsMissed(), isTrue);

    target.position = Vector2(601, 100);
    expect(target.shouldRemoveAsMissed(), isTrue);

    target.position = Vector2(200, -401);
    expect(target.shouldRemoveAsMissed(), isTrue);

    target.position = Vector2(200, 900);
    expect(target.shouldRemoveAsMissed(), isTrue);
  });

  test('targets use the same path hit radius regardless of durability', () {
    final weakTarget = SlashTarget(durability: 1);
    final strongTarget = SlashTarget(durability: 4);

    expect(weakTarget.size.x, closeTo(SlashTarget.targetDrawSize, 0.0001));
    expect(weakTarget.size.y, closeTo(SlashTarget.targetDrawSize, 0.0001));
    expect(weakTarget.pathHitRadius, 60);
    expect(strongTarget.pathHitRadius, 60);
  });

  test('target rotation speed is randomized in either direction', () {
    final clockwise = SlashTarget.randomSignedRotationSpeed(random: Random(0));
    final counterClockwise = SlashTarget.randomSignedRotationSpeed(
      random: Random(1),
    );

    expect(clockwise.abs(), inInclusiveRange(0.35, 1.2));
    expect(counterClockwise.abs(), inInclusiveRange(0.35, 1.2));
    expect(clockwise.sign, isNot(counterClockwise.sign));
  });

  test('target color follows hits required by current attack power', () {
    final target = SlashTarget(durability: 3);
    final hitPosition = Vector2(100, 100);

    expect(target.coreColor, const Color(0xFFA855F7));
    expect(target.coreColorForAttackPower(2), const Color(0xFFFF335F));
    expect(target.coreColorForAttackPower(3), const Color(0xFF00E5FF));

    expect(target.hit(hitPosition), TargetHitOutcome.damaged);
    expect(target.coreColor, const Color(0xFFFF335F));

    target.rearmDamageIfFarFrom(
      hitPosition + Vector2(SlashTarget.damageRearmDistance, 0),
    );

    expect(target.hit(hitPosition), TargetHitOutcome.damaged);
    expect(target.coreColor, const Color(0xFF00E5FF));
  });

  test('target sprite follows hits required by current attack power', () {
    final target = SlashTarget(durability: 3);
    final hitPosition = Vector2(100, 100);

    expect(target.stageForAttackPower(1), 3);
    expect(
      target.targetSpritePathForAttackPower(1),
      SlashTarget.stageThreeSpritePath,
    );
    expect(target.stageForAttackPower(2), 2);
    expect(
      target.targetSpritePathForAttackPower(2),
      SlashTarget.stageTwoSpritePath,
    );
    expect(target.stageForAttackPower(3), 1);
    expect(
      target.targetSpritePathForAttackPower(3),
      SlashTarget.stageOneSpritePath,
    );

    expect(target.hit(hitPosition), TargetHitOutcome.damaged);
    expect(target.stageForAttackPower(1), 2);
    expect(
      target.targetSpritePathForAttackPower(1),
      SlashTarget.stageTwoSpritePath,
    );
  });

  test(
    'chain strike sends damaged target to a random point on the next path',
    () {
      final currentPosition = Vector2(120, 300);
      final nextPathStart = Vector2(220, 260);
      final nextPathEnd = Vector2(420, 140);

      final launch = PlayerComponent.chainStrikeLaunch(
        currentPosition: currentPosition,
        nextPathStart: nextPathStart,
        nextPathEnd: nextPathEnd,
        random: Random(1),
      );
      final expectedDestination =
          nextPathStart + (nextPathEnd - nextPathStart) * launch.pathT;

      expect(launch.pathT, greaterThanOrEqualTo(0.25));
      expect(launch.pathT, lessThanOrEqualTo(0.85));
      expect(
        (launch.destination - expectedDestination).length,
        lessThan(0.0001),
      );
    },
  );

  test(
    'chain strike fallback launches target upward within a forty five degree cone',
    () {
      final origin = Vector2(200, 300);

      final launch = PlayerComponent.chainStrikeLaunch(
        currentPosition: origin,
        nextPathStart: null,
        nextPathEnd: null,
        random: Random(7),
      );
      final destination = launch.destination;
      final offset = destination - origin;
      final angle = atan2(offset.y, offset.x);

      expect(launch.pathT, 1.0);
      expect(offset.length, moreOrLessEquals(180, epsilon: 0.0001));
      expect(destination.y, lessThan(origin.y));
      expect(angle, greaterThanOrEqualTo(-3 * pi / 4));
      expect(angle, lessThanOrEqualTo(-pi / 4));
    },
  );

  test('chain strike movement animates before settling at the destination', () {
    final target = SlashTarget()..position = Vector2(100, 300);
    final destination = Vector2(260, 180);

    target.startChainStrikeMove(destination, duration: 0.2);

    expect(target.isChainStrikeMoving, isTrue);

    target.advanceChainStrikeMove(0.1);
    expect(target.position.x, greaterThan(100));
    expect(target.position.x, lessThan(destination.x));
    expect(target.position.y, lessThan(300));

    target.advanceChainStrikeMove(0.1);
    expect(target.isChainStrikeMoving, isFalse);
    expect(target.position, destination);
  });

  test('chain strike cannot bounce laser attack targets', () {
    expect(PlayerComponent.canChainStrikeTarget(SlashTarget()), isTrue);
    expect(
      PlayerComponent.canChainStrikeTarget(LaserTarget(maxStageDurability: 7)),
      isFalse,
    );
  });
}
