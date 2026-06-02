import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import '../game/quick_draw_game.dart';

enum TargetHitOutcome { ignored, damaged, sliced }

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

    if (shouldRemoveAsMissed()) {
      removeFromParent();
      onMissed();
    }
  }

  void onMissed() {}

  bool shouldRemoveAsMissed() => position.y > game.size.y + 80;

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
  static const String stageOneSpritePath = 'targets/target_stage_1.png';
  static const String stageTwoSpritePath = 'targets/target_stage_2.png';
  static const String stageThreeSpritePath = 'targets/target_stage_3.png';
  static const int defaultPlayerAttackPower = 1;
  static const double damageRearmDistance = 64.0;
  static const double hitRadius = 60.0;
  static const double targetDrawSize = 95.04;

  bool isTargeted = false;
  int chainIndex = -1;
  final int durability;
  late int remainingDurability;
  Vector2? _lastDamagePosition;
  Vector2? _chainStrikeStart;
  Vector2? _chainStrikeDestination;
  double _chainStrikeMoveTimer = 0.0;
  double _chainStrikeMoveDuration = 0.0;
  double _spriteAngle = 0.0;
  double _spriteRotationSpeed = 0.0;

  SlashTarget({this.durability = 1}) {
    remainingDurability = durability;
    size = Vector2.all(targetDrawSize);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _spriteAngle = Random().nextDouble() * 2 * pi;
    _spriteRotationSpeed = randomSignedRotationSpeed();
  }

  @visibleForTesting
  static double randomSignedRotationSpeed({Random? random}) {
    final rng = random ?? Random();
    final direction = rng.nextBool() ? 1.0 : -1.0;
    return direction * (0.35 + rng.nextDouble() * 0.85);
  }

  int get _effectivePlayerAttackPower =>
      isMounted ? game.playerAttackPower : defaultPlayerAttackPower;

  double get pathHitRadius => hitRadius;

  int hitsToDestroyForAttackPower(int attackPower) {
    attackPower = max(1, attackPower);
    return (remainingDurability / attackPower).ceil();
  }

  int get hitsToDestroy =>
      hitsToDestroyForAttackPower(_effectivePlayerAttackPower);

  int get experienceValue => durability;

  Color coreColorForAttackPower(int attackPower) {
    final hits = hitsToDestroyForAttackPower(attackPower);
    if (hits >= 3) return const Color(0xFFA855F7);
    if (hits == 2) return const Color(0xFFFF335F);
    return const Color(0xFF00E5FF);
  }

  Color get coreColor => coreColorForAttackPower(_effectivePlayerAttackPower);

  int stageForAttackPower(int attackPower) {
    return min(3, hitsToDestroyForAttackPower(attackPower));
  }

  String targetSpritePathForAttackPower(int attackPower) {
    return switch (stageForAttackPower(attackPower)) {
      1 => stageOneSpritePath,
      2 => stageTwoSpritePath,
      _ => stageThreeSpritePath,
    };
  }

  String get targetSpritePath =>
      targetSpritePathForAttackPower(_effectivePlayerAttackPower);

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
    _spriteAngle += _spriteRotationSpeed * dt;
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
    final usedSprite = renderTargetSprite(canvas);

    if (isTargeted) {
      // Targeted glow ring
      _targetPaint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(radius, radius), radius + 8, _targetPaint);

      if (!usedSprite) {
        // Core targeted orb
        final targetedCorePaint = Paint()
          ..color = color.withValues(alpha: opacity);
        canvas.drawCircle(
          Offset(radius, radius),
          radius - 6,
          targetedCorePaint,
        );
      }
    } else if (!usedSprite) {
      // Neon durability orb
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

    _drawDurabilityText(canvas, radius);
  }

  bool renderTargetSprite(Canvas canvas) {
    if (runtimeType != SlashTarget ||
        !game.images.containsKey(targetSpritePath)) {
      return false;
    }

    final image = game.images.fromCache(targetSpritePath);
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final destination = Rect.fromLTWH(0, 0, size.x, size.y);
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..color = Colors.white.withValues(alpha: opacity);

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(_spriteAngle);
    canvas.translate(-size.x / 2, -size.y / 2);
    canvas.drawImageRect(image, source, destination, paint);
    canvas.restore();
    return true;
  }

  void _drawDurabilityText(Canvas canvas, double radius) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$remainingDurability',
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

    remainingDurability = max(
      0,
      remainingDurability - (attackPower ?? _effectivePlayerAttackPower),
    );
    if (remainingDurability == 0) {
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
    final slicedSpritePath = runtimeType == SlashTarget
        ? targetSpritePath
        : null;

    // Spawn sliced halves starting from the hit point
    final leftHalf = SlicedHalfComponent(
      position: hitPoint.clone(),
      angle: sliceAngle,
      isLeft: true,
      color: coreColor,
      spritePath: slicedSpritePath,
      spriteAngle: _spriteAngle,
    );
    final rightHalf = SlicedHalfComponent(
      position: hitPoint.clone(),
      angle: sliceAngle,
      isLeft: false,
      color: coreColor,
      spritePath: slicedSpritePath,
      spriteAngle: _spriteAngle,
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

class LaserTarget extends SlashTarget {
  static const double laserDrawSize = 98.9;
  static const double laserHitRadius = 69.0;
  static const List<String> spriteAnimationFramePaths = [
    'sprites/generated/squirrel_spaceship_laser_idle_transparent_001.png',
    'sprites/generated/squirrel_spaceship_laser_idle_transparent_002.png',
    'sprites/generated/squirrel_spaceship_laser_idle_transparent_003.png',
    'sprites/generated/squirrel_spaceship_laser_idle_transparent_004.png',
    'sprites/generated/squirrel_spaceship_laser_idle_transparent_005.png',
    'sprites/generated/squirrel_spaceship_laser_idle_transparent_006.png',
    'sprites/generated/squirrel_spaceship_laser_idle_transparent_007.png',
    'sprites/generated/squirrel_spaceship_laser_idle_transparent_008.png',
  ];
  static const double spriteAnimationDuration = 2.0;
  static const double spriteFrameStepTime = 0.25;

  static int durabilityForStageMax(int maxStageDurability) =>
      min(20, max(1, (maxStageDurability * 1.3).ceil()));

  static int minimumDurabilityForStageMax(int maxStageDurability) =>
      max(1, (durabilityForStageMax(maxStageDurability) * 0.7).ceil());

  SpriteAnimationTicker? _spriteAnimationTicker;
  final Paint _spritePaint = Paint()..filterQuality = FilterQuality.high;

  LaserTarget({required int maxStageDurability, int? durability})
    : super(
        durability: durability ?? durabilityForStageMax(maxStageDurability),
      ) {
    size = Vector2.all(laserDrawSize);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await game.images.loadAll(spriteAnimationFramePaths);
    final sprites = [
      for (final framePath in spriteAnimationFramePaths)
        Sprite(game.images.fromCache(framePath)),
    ];
    _spriteAnimationTicker = SpriteAnimation.spriteList(
      sprites,
      stepTime: spriteFrameStepTime,
    ).createTicker();
  }

  @override
  int get experienceValue => durability * 3;

  @override
  Color coreColorForAttackPower(int attackPower) => const Color(0xFFFF1744);

  @override
  double get pathHitRadius => laserHitRadius;

  @override
  bool shouldRemoveAsMissed() => position.y > game.size.y + size.y;

  @override
  void onMissed() {
    if (!game.isPlaying) {
      return;
    }
    game.triggerLaserTargetMissed(position.clone());
  }

  @override
  void render(Canvas canvas) {
    final usedSprite = _renderLaserSprite(canvas);
    if (!usedSprite) {
      super.render(canvas);
    }
    _drawSegmentedHealthBar(canvas);
  }

  @override
  void slice(Vector2 hitPoint, double sliceAngle) {
    game.spawnSliceParticles(hitPoint, coreColor);
    final slicedSpritePath = currentSliceSpritePath;

    final leftHalf = SlicedHalfComponent(
      position: hitPoint.clone(),
      angle: sliceAngle,
      isLeft: true,
      color: coreColor,
      spritePath: slicedSpritePath,
      drawSize: size.x,
    );
    final rightHalf = SlicedHalfComponent(
      position: hitPoint.clone(),
      angle: sliceAngle,
      isLeft: false,
      color: coreColor,
      spritePath: slicedSpritePath,
      drawSize: size.x,
    );

    game.add(leftHalf);
    game.add(rightHalf);
    removeFromParent();
  }

  @visibleForTesting
  String get currentSliceSpritePath {
    final ticker = _spriteAnimationTicker;
    if (ticker == null) {
      return spriteAnimationFramePaths.first;
    }
    return spriteAnimationFramePaths[ticker.currentIndex];
  }

  @visibleForTesting
  int healthBarSegmentCountForAttackPower(int attackPower) {
    return max(1, (durability / max(1, attackPower)).ceil());
  }

  @visibleForTesting
  int filledHealthBarSegmentsForAttackPower(int attackPower) {
    return max(0, (remainingDurability / max(1, attackPower)).ceil());
  }

  void _drawSegmentedHealthBar(Canvas canvas) {
    final attackPower = isMounted
        ? game.playerAttackPower
        : SlashTarget.defaultPlayerAttackPower;
    final segmentCount = healthBarSegmentCountForAttackPower(attackPower);
    final filledSegments = filledHealthBarSegmentsForAttackPower(attackPower);
    final barWidth = min(size.x + 22.0, 124.0);
    const barHeight = 8.0;
    const gap = 1.5;
    final left = (size.x - barWidth) / 2;
    const top = -14.0;
    final background = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, barWidth, barHeight),
      const Radius.circular(3),
    );
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity * 0.62);
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fillPaint = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: opacity);
    final emptyPaint = Paint()
      ..color = const Color(0xFF4B1020).withValues(alpha: opacity * 0.72);

    canvas.drawRRect(background, backgroundPaint);
    final segmentWidth = (barWidth - gap * (segmentCount - 1)) / segmentCount;
    for (var i = 0; i < segmentCount; i++) {
      final segmentRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left + i * (segmentWidth + gap),
          top,
          segmentWidth,
          barHeight,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        segmentRect,
        i < filledSegments ? fillPaint : emptyPaint,
      );
    }
    canvas.drawRRect(background, borderPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _spriteAnimationTicker?.update(dt);
  }

  bool _renderLaserSprite(Canvas canvas) {
    final ticker = _spriteAnimationTicker;
    if (ticker == null) {
      return false;
    }
    _spritePaint.color = Colors.white.withValues(alpha: opacity);
    ticker.getSprite().render(
      canvas,
      position: Vector2.zero(),
      size: size,
      overridePaint: _spritePaint,
    );
    return true;
  }
}

class EnergyShard extends PositionComponent
    with HasGameReference<QuickDrawGame> {
  static const double collectRadius = 22.0;
  static const double restoreAmount = 0.08;

  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final Paint _corePaint = Paint()..style = PaintingStyle.fill;
  final Vector2 _velocity;
  double _age = 0.0;
  double _opacity = 0.0;

  static const double _burstDuration = 0.28;
  static const double _minChaseSpeed = 180.0;
  static const double _maxChaseSpeed = 920.0;

  EnergyShard({required Vector2 position, Vector2? velocity})
    : _velocity = velocity ?? Vector2.zero() {
    this.position = position;
    size = Vector2.all(26);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameplayPausedForUi) {
      return;
    }
    _age += dt;
    _opacity = (_age / 0.18).clamp(0.0, 1.0);
    if (_age < _burstDuration) {
      position.add(_velocity * dt);
      position.y += 46.0 * dt;
    } else if (game.isGameOverPending) {
      return;
    } else {
      final target = game.player.position;
      final toTarget = target - position;
      final distance = toTarget.length;
      if (distance <= collectRadius + game.player.size.x / 2) {
        removeFromParent();
        game.triggerEnergyShardCollected(position);
        return;
      }
      if (distance > 0) {
        final chaseProgress = ((_age - _burstDuration) / 0.9).clamp(0.0, 1.0);
        final speed =
            _minChaseSpeed + (_maxChaseSpeed - _minChaseSpeed) * chaseProgress;
        position.add(toTarget.normalized() * min(speed * dt, distance));
      }
    }
    if (position.y > game.size.y + size.y) {
      removeFromParent();
    }
  }

  void applyCameraShift(Vector2 delta) {
    if (game.isGameplayPausedForUi) {
      return;
    }
    position.add(delta);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final radius = size.x / 2;
    final center = Offset(radius, radius);
    final pulse = (sin(_age * 8.0) + 1.0) / 2.0;
    final color = Color.lerp(
      const Color(0xFFFFD166),
      const Color(0xFFFFFFFF),
      pulse * 0.28,
    )!;

    _glowPaint.color = color.withValues(alpha: _opacity * 0.34);
    canvas.drawCircle(center, radius + 6, _glowPaint);

    _corePaint.color = color.withValues(alpha: _opacity);
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(path, _corePaint);

    final sparkPaint = Paint()
      ..color = Colors.white.withValues(alpha: _opacity * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - 5, center.dy),
      Offset(center.dx + 5, center.dy),
      sparkPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 5),
      Offset(center.dx, center.dy + 5),
      sparkPaint,
    );
  }
}

class ObstacleTarget extends FloatingObject {
  static const double collisionRadius = 60.0;

  final Paint _paint = Paint()..color = const Color(0xFFFF7B00);
  final Paint _glowPaint = Paint()
    ..color = const Color(0xFFFF7B00).withValues(alpha: 0.3)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  double rotationSpeed = 2.0;

  ObstacleTarget() {
    size = Vector2(72, 72);
  }

  double get pathCollisionRadius => collisionRadius;

  double get touchCollisionRadius => size.x / 2;

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

class LongObstacleTarget extends ObstacleTarget {
  static const double longHeight = 187.2;

  final double _drawAngle = (Random().nextDouble() - 0.5) * pi;

  LongObstacleTarget() {
    size = Vector2(54, longHeight);
    rotationSpeed = 0.0;
  }

  @override
  double get pathCollisionRadius => longHeight / 2;

  @override
  double get touchCollisionRadius => size.y / 2;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    rotationSpeed = 0.0;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(_drawAngle);
    canvas.translate(-size.x / 2, -size.y / 2);

    _glowPaint.color = const Color(0xFFFF7B00).withValues(alpha: opacity * 0.3);
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(24),
    );
    canvas.drawRRect(bodyRect, _glowPaint);

    _paint.color = const Color(0xFFFF7B00).withValues(alpha: opacity);
    canvas.drawRRect(bodyRect, _paint);

    final corePaint = Paint()
      ..color = const Color(0xFF1E0E05).withValues(alpha: opacity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 12, size.x - 20, size.y - 24),
        const Radius.circular(16),
      ),
      corePaint,
    );

    final spikePaint = Paint()
      ..color = const Color(0xFFFF0055).withValues(alpha: opacity);
    for (var y = 24.0; y < size.y - 12; y += 28.0) {
      canvas.drawCircle(Offset(size.x / 2, y), 4, spikePaint);
    }

    canvas.restore();
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

class SlicedHalfComponent extends PositionComponent
    with HasGameReference<QuickDrawGame> {
  final bool isLeft;
  final Color color;
  final String? spritePath;
  final double spriteAngle;

  late Vector2 velocity;
  double opacity = 1.0;
  double rotationSpeed = 5.0;

  SlicedHalfComponent({
    required Vector2 position,
    required double angle,
    required this.isLeft,
    required this.color,
    this.spritePath,
    this.spriteAngle = 0.0,
    double drawSize = SlashTarget.targetDrawSize,
  }) {
    this.position = position;
    this.angle = angle;
    size = Vector2.all(drawSize);
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
    final alpha = opacity.clamp(0.0, 1.0);
    final usedSprite = renderSlicedSprite(canvas, radius, alpha);
    if (usedSprite) {
      return;
    }

    final halfPaint = Paint()..color = color.withValues(alpha: alpha);

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
      ..color = Colors.white.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset.zero, radius - 4, strokePaint);

    canvas.restore();
  }

  bool renderSlicedSprite(Canvas canvas, double radius, double alpha) {
    final path = spritePath;
    if (path == null || !game.images.containsKey(path)) {
      return false;
    }

    final image = game.images.fromCache(path);
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final destination = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..color = Colors.white.withValues(alpha: alpha);

    canvas.save();
    canvas.translate(radius, radius);
    canvas.rotate(angle);
    if (isLeft) {
      canvas.clipRect(Rect.fromLTRB(-radius - 5, -radius - 5, 0, radius + 5));
    } else {
      canvas.clipRect(Rect.fromLTRB(0, -radius - 5, radius + 5, radius + 5));
    }
    canvas.rotate(spriteAngle);
    canvas.drawImageRect(image, source, destination, paint);
    canvas.restore();
    return true;
  }
}
