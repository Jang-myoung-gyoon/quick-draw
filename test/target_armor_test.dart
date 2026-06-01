import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_draw/components/player.dart';
import 'package:quick_draw/components/target.dart';

void main() {
  test('hit count requires separate rearmed hits to slice', () {
    final target = SlashTarget(armor: 1, requiredHits: 2);
    final hitPosition = Vector2(100, 100);

    expect(target.armor, 1);
    expect(target.remainingHits, 2);
    expect(target.hit(hitPosition), TargetHitOutcome.damaged);
    expect(target.armor, 1);
    expect(target.remainingHits, 1);

    expect(target.hit(hitPosition), TargetHitOutcome.ignored);
    expect(target.remainingHits, 1);

    target.rearmDamageIfFarFrom(
      hitPosition + Vector2(SlashTarget.damageRearmDistance, 0),
    );

    expect(target.hit(hitPosition), TargetHitOutcome.sliced);
    expect(target.armor, 1);
    expect(target.remainingHits, 0);
  });

  test('armor blocks independently from hit count', () {
    final target = SlashTarget(armor: 2, requiredHits: 1);

    expect(target.hit(Vector2(100, 100)), TargetHitOutcome.blocked);
    expect(target.armor, 2);
    expect(target.remainingHits, 1);
  });

  test('armor and hit count are stored independently', () {
    final target = SlashTarget(armor: 2, requiredHits: 3);

    expect(target.armor, 2);
    expect(target.remainingHits, 3);
  });

  test(
    'cuttable targets are larger while armor-blocked hit radius stays small',
    () {
      final cuttableTarget = SlashTarget(armor: 1, requiredHits: 1);
      final blockedTarget = SlashTarget(armor: 2, requiredHits: 1);

      expect(cuttableTarget.size.x, 72);
      expect(cuttableTarget.size.y, 72);
      expect(cuttableTarget.pathHitRadius, 60);
      expect(blockedTarget.pathHitRadius, 40);
    },
  );

  test('target color follows remaining hit count after damage', () {
    final target = SlashTarget(armor: 1, requiredHits: 3);
    final hitPosition = Vector2(100, 100);

    expect(target.coreColor, const Color(0xFFA855F7));

    expect(target.hit(hitPosition), TargetHitOutcome.damaged);
    expect(target.coreColor, const Color(0xFFFF335F));

    target.rearmDamageIfFarFrom(
      hitPosition + Vector2(SlashTarget.damageRearmDistance, 0),
    );

    expect(target.hit(hitPosition), TargetHitOutcome.damaged);
    expect(target.coreColor, const Color(0xFF00E5FF));
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
}
