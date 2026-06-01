import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../main.dart';

enum TargetHitOutcome { ignored, blocked, damaged, sliced }

// Base class for objects that scroll downward from the top of the screen
abstract class FloatingObject extends PositionComponent
    with HasGameReference<QuickDrawGame> {
  double driftTimer = 0.0;
  double driftSpeed = 1.0;
  double driftAmount = 0.5;
  Vector2 driftDirection = Vector2.zero();
  double freefallSwayTimer = 0.0;
  double freefallSwaySpeed = 1.0;
  double freefallSwayAmount = 36.0;
  double freefallNoiseSpeed = 1.0;
  double freefallNoiseAmount = 14.0;

  // Fade-in on spawn
  double age = 0.0;
  double opacity = 0.0;

  // Scroll speed (objects drift downward slowly when player is idle)
  double scrollSpeed = 30.0; // px/s downward drift

  FloatingObject() {
    anchor = Anchor.center;
    size = Vector2(48, 48);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    driftSpeed = 0.4 + Random().nextDouble() * 0.8;
    driftAmount = 5.0 + Random().nextDouble() * 10.0;
    freefallSwaySpeed = 1.4 + Random().nextDouble() * 1.6;
    freefallSwayAmount = 28.0 + Random().nextDouble() * 34.0;
    freefallNoiseSpeed = 3.0 + Random().nextDouble() * 3.0;
    freefallNoiseAmount = 8.0 + Random().nextDouble() * 14.0;

    final double angle = Random().nextDouble() * 2 * pi;
    driftDirection = Vector2(cos(angle), sin(angle));
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Fade in quickly
    age += dt;
    if (age < 0.4) {
      opacity = age / 0.4;
    } else {
      opacity = 1.0;
    }

    // Slow downward scroll (idle drift)
    position.y += scrollSpeed * dt;

    // Gentle floating drift in place
    driftTimer += dt * driftSpeed;
    final driftOffset = driftDirection * sin(driftTimer) * driftAmount * dt;
    position.add(driftOffset);

    if (_shouldUseFreefallSway) {
      freefallSwayTimer += dt;
      final sway =
          sin(freefallSwayTimer * freefallSwaySpeed) * freefallSwayAmount;
      final noise =
          sin(freefallSwayTimer * freefallNoiseSpeed + driftDirection.y * pi) *
          freefallNoiseAmount;
      position.x += (sway + noise) * dt;
      position.x = position.x.clamp(-size.x, game.size.x + size.x);
    }

    // Remove if scrolled below the screen
    if (position.y > game.size.y + 80) {
      removeFromParent();
      onMissed();
    }
  }

  void onMissed() {}

  bool get _shouldUseFreefallSway =>
      game.isPlaying &&
      !game.player.isDashing &&
      game.currentChainPoints.isEmpty;

  /// Move this object when the camera follows the player.
  void applyCameraShift(Vector2 delta) {
    position.add(delta);
  }
}

class SlashTarget extends FloatingObject {
  static const int defaultPlayerAttackPower = 1;
  static const double damageRearmDistance = 64.0;
  static const double cuttableHitRadius = 60.0;
  static const double blockedHitRadius = 40.0;

  bool isTargeted = false;
  int chainIndex = -1;
  final int armor;
  final int requiredHits;
  late int remainingHits;
  Vector2? _lastDamagePosition;
  Vector2? _chainStrikeStart;
  Vector2? _chainStrikeDestination;
  double _chainStrikeMoveTimer = 0.0;
  double _chainStrikeMoveDuration = 0.0;

  SlashTarget({this.armor = 1, this.requiredHits = 1}) {
    remainingHits = requiredHits;
    size = Vector2(72, 72);
  }

  int get _effectivePlayerAttackPower =>
      isMounted ? game.playerAttackPower : defaultPlayerAttackPower;

  bool get isBlockedByArmor => _effectivePlayerAttackPower < armor;

  double get pathHitRadius =>
      isBlockedByArmor ? blockedHitRadius : cuttableHitRadius;

  Color get coreColor {
    if (remainingHits >= 3) return const Color(0xFFA855F7);
    if (remainingHits == 2) return const Color(0xFFFF335F);
    return const Color(0xFF00E5FF);
  }

  bool get isDamageRearmed {
    return _lastDamagePosition == null;
  }

  bool get isChainStrikeMoving => _chainStrikeDestination != null;

  final Paint _targetPaint = Paint()
    ..color = const Color(0xFFFF2D55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  @override
  void update(double dt) {
    super.update(dt);
    advanceChainStrikeMove(dt);

    final lastDamagePosition = _lastDamagePosition;
    if (lastDamagePosition != null && isMounted && game.player.isMounted) {
      rearmDamageIfFarFrom(game.player.position);
    }
  }

  void startChainStrikeMove(Vector2 destination, {double duration = 0.18}) {
    _chainStrikeStart = position.clone();
    _chainStrikeDestination = destination.clone();
    _chainStrikeMoveTimer = 0.0;
    _chainStrikeMoveDuration = duration;
  }

  void advanceChainStrikeMove(double dt) {
    final start = _chainStrikeStart;
    final destination = _chainStrikeDestination;
    if (start == null || destination == null) {
      return;
    }

    _chainStrikeMoveTimer += dt;
    final rawProgress = (_chainStrikeMoveTimer / _chainStrikeMoveDuration)
        .clamp(0.0, 1.0);
    final easedProgress = 1.0 - pow(1.0 - rawProgress, 3).toDouble();
    final arcHeight = 34.0 * sin(rawProgress * pi);
    position = start + (destination - start) * easedProgress;
    position.y -= arcHeight;

    if (rawProgress >= 1.0) {
      position = destination;
      _chainStrikeStart = null;
      _chainStrikeDestination = null;
    }
  }

  void rearmDamageIfFarFrom(Vector2 attackerPosition) {
    final lastDamagePosition = _lastDamagePosition;
    if (lastDamagePosition == null) {
      return;
    }
    if ((attackerPosition - lastDamagePosition).length >= damageRearmDistance) {
      _lastDamagePosition = null;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final double radius = size.x / 2;
    final color = coreColor;

    if (isTargeted) {
      // Targeted glow ring
      _targetPaint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(radius, radius), radius + 8, _targetPaint);

      // Core targeted orb
      final targetedCorePaint = Paint()
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(radius, radius), radius - 6, targetedCorePaint);
    } else {
      // Neon armor orb
      final glowPaint = Paint()
        ..color = color.withValues(alpha: opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(radius, radius), radius, glowPaint);

      // Core orb
      final corePaint = Paint()..color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(radius, radius), radius - 4, corePaint);

      // Inner white highlights
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity * 0.8);
      canvas.drawCircle(Offset(radius - 4, radius - 4), 3, highlightPaint);
    }

    _drawArmorText(canvas, radius);
  }

  void _drawArmorText(Canvas canvas, double radius) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$armor',
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontSize: 22,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: opacity * 0.75),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(radius - textPainter.width / 2, radius - textPainter.height / 2),
    );
  }

  bool canReceiveDamageFrom(Vector2 _) {
    return _lastDamagePosition == null;
  }

  TargetHitOutcome hit(Vector2 attackerPosition, {int? attackPower}) {
    if (!canReceiveDamageFrom(attackerPosition)) {
      return TargetHitOutcome.ignored;
    }
    _lastDamagePosition = attackerPosition.clone();
    if ((attackPower ?? _effectivePlayerAttackPower) < armor) {
      return TargetHitOutcome.blocked;
    }

    remainingHits = max(0, remainingHits - 1);
    if (remainingHits == 0) {
      return TargetHitOutcome.sliced;
    }
    return TargetHitOutcome.damaged;
  }

  void hitArmor(Vector2 hitPoint) {
    game.spawnSliceParticles(hitPoint, coreColor);
  }

  // Trigger when player slices this target at a specific intersection point
  void slice(Vector2 hitPoint, double sliceAngle) {
    // Create particle sparks at the hit point
    game.spawnSliceParticles(hitPoint, coreColor);

    // Spawn sliced halves starting from the hit point
    final leftHalf = SlicedHalfComponent(
      position: hitPoint.clone(),
      angle: sliceAngle,
      isLeft: true,
      color: coreColor,
    );
    final rightHalf = SlicedHalfComponent(
      position: hitPoint.clone(),
      angle: sliceAngle,
      isLeft: false,
      color: coreColor,
    );

    game.add(leftHalf);
    game.add(rightHalf);

    removeFromParent();
  }

  @override
  void onMissed() {
    // If a targeted item expires without being slashed, reset chain
    if (isTargeted && game.isPlaying) {
      game.resetChain();
    }
  }
}

class ObstacleTarget extends FloatingObject {
  final Paint _paint = Paint()..color = const Color(0xFFFF7B00);
  final Paint _glowPaint = Paint()
    ..color = const Color(0xFFFF7B00).withValues(alpha: 0.3)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  double rotationSpeed = 2.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    rotationSpeed = (Random().nextDouble() - 0.5) * 4.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    angle += rotationSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final double radius = size.x / 2;

    // Draw neon orange hazard spikes with matching opacity
    _glowPaint.color = const Color(0xFFFF7B00).withValues(alpha: opacity * 0.3);
    canvas.drawCircle(Offset(radius, radius), radius - 4, _glowPaint);

    _paint.color = const Color(0xFFFF7B00).withValues(alpha: opacity);
    final Path spikePath = Path();
    final int spikeCount = 8;
    final double step = (2 * pi) / spikeCount;

    for (int i = 0; i < spikeCount; i++) {
      final double currentAngle = i * step;
      final double outerX = radius + radius * cos(currentAngle);
      final double outerY = radius + radius * sin(currentAngle);

      final double innerAngle = currentAngle + step / 2;
      final double innerX = radius + (radius - 8) * cos(innerAngle);
      final double innerY = radius + (radius - 8) * sin(innerAngle);

      if (i == 0) {
        spikePath.moveTo(outerX, outerY);
      } else {
        spikePath.lineTo(outerX, outerY);
      }
      spikePath.lineTo(innerX, innerY);
    }
    spikePath.close();

    canvas.drawPath(spikePath, _paint);

    // Inner danger core
    final corePaint = Paint()
      ..color = const Color(0xFF1E0E05).withValues(alpha: opacity);
    canvas.drawCircle(Offset(radius, radius), radius - 10, corePaint);
    final coreGlow = Paint()
      ..color = const Color(0xFFFF0055).withValues(alpha: opacity);
    canvas.drawCircle(Offset(radius, radius), 3, coreGlow);
  }
}

class BonusTarget extends FloatingObject {
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  final Paint _corePaint = Paint()..style = PaintingStyle.fill;
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;
  double pulseTimer = 0.0;

  BonusTarget() {
    size = Vector2(64, 64);
  }

  @override
  void update(double dt) {
    super.update(dt);
    pulseTimer += dt * 5.0;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final radius = size.x / 2;
    final pulse = (sin(pulseTimer) + 1.0) / 2.0;
    final color = Color.lerp(
      const Color(0xFF22C55E),
      const Color(0xFFFFFFFF),
      pulse * 0.35,
    )!;

    _glowPaint.color = color.withValues(alpha: opacity * 0.34);
    canvas.drawCircle(Offset(radius, radius), radius + 8, _glowPaint);

    _corePaint.color = color.withValues(alpha: opacity);
    canvas.drawCircle(Offset(radius, radius), radius - 7, _corePaint);

    _ringPaint.color = Colors.white.withValues(alpha: opacity * 0.86);
    canvas.drawCircle(Offset(radius, radius), radius - 2, _ringPaint);

    final slashPaint = Paint()
      ..color = const Color(0xFF052E20).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(radius, radius + 14),
      Offset(radius, radius - 14),
      slashPaint,
    );
  }
}

class SlicedHalfComponent extends PositionComponent {
  final bool isLeft;
  final Color color;

  late Vector2 velocity;
  double opacity = 1.0;
  double rotationSpeed = 5.0;

  SlicedHalfComponent({
    required Vector2 position,
    required double angle,
    required this.isLeft,
    required this.color,
  }) {
    this.position = position;
    this.angle = angle;
    size = Vector2(48, 48);
    anchor = Anchor.center;

    // Fly outwards perpendicular to the slice angle
    final double pushAngle = angle + (isLeft ? -pi / 2 : pi / 2);
    final double speed = 150.0 + Random().nextDouble() * 150.0;
    velocity = Vector2(cos(pushAngle), sin(pushAngle)) * speed;

    // Add downward gravity effect
    velocity.y += 100.0;

    rotationSpeed = (isLeft ? -1 : 1) * (4.0 + Random().nextDouble() * 6.0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.add(velocity * dt);

    // Gravity influence
    velocity.y += 400.0 * dt;
    angle += rotationSpeed * dt;

    // Fade out
    opacity -= dt * 2.0;
    if (opacity <= 0.0) {
      removeFromParent();
    }
  }

  void applyCameraShift(Vector2 delta) {
    position.add(delta);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final double radius = size.x / 2;
    final halfPaint = Paint()
      ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0));

    // Save state to clip half of the circle
    canvas.save();

    // Translate to center for rotation and clipping
    canvas.translate(radius, radius);
    canvas.rotate(angle);

    // Draw only one half (semi-circle)
    if (isLeft) {
      canvas.clipRect(Rect.fromLTRB(-radius - 5, -radius - 5, 0, radius + 5));
    } else {
      canvas.clipRect(Rect.fromLTRB(0, -radius - 5, radius + 5, radius + 5));
    }

    canvas.drawCircle(Offset.zero, radius - 4, halfPaint);

    // Faint neon border
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset.zero, radius - 4, strokePaint);

    canvas.restore();
  }
}
