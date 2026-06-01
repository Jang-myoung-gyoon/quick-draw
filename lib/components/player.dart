import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'target.dart';

const List<String> _freefallFramePaths = [
  'sprites/generated/nori_freefall_veo_frames_transparent/nori_freefall_veo_01.png',
  'sprites/generated/nori_freefall_veo_frames_transparent/nori_freefall_veo_02.png',
  'sprites/generated/nori_freefall_veo_frames_transparent/nori_freefall_veo_03.png',
  'sprites/generated/nori_freefall_veo_frames_transparent/nori_freefall_veo_04.png',
  'sprites/generated/nori_freefall_veo_frames_transparent/nori_freefall_veo_05.png',
  'sprites/generated/nori_freefall_veo_frames_transparent/nori_freefall_veo_06.png',
];

const String _battoujutsuStartPath =
    'sprites/video_references/nori_air_battoujutsu_dash_start_from_freefall_transparent.png';
const String _battoujutsuEndPath =
    'sprites/video_references/nori_air_battoujutsu_slash_end_transparent.png';

enum _DashPhase { windup, moving, recovery }

enum _UltimatePhase { preScroll, slash }

class PlayerComponent extends PositionComponent
    with HasGameReference<QuickDrawGame> {
  // Idle floating properties
  double _hoverTimer = 0.0;
  final double _hoverSpeed = 3.0;
  final double _hoverAmplitude = 15.0;
  late double _baseY;
  double get baseY => _baseY;

  // Dashing state properties
  bool isDashing = false;
  List<Vector2> _dashWaypoints = [];
  int _currentTargetIndex = 0;
  static const double dashSpeed = 5590.0;
  Vector2 _dashStartPos = Vector2.zero();
  double _dashProgress = 0.0;
  double _dashSegmentElapsed = 0.0;
  double _dashSegmentDuration = 0.0;
  bool _dashFacingLeft = false;
  bool _chainFacingLeft = false;
  Vector2 _activeSlashDirection = Vector2(0, -1);
  _DashPhase _dashPhase = _DashPhase.moving;
  double _dashPauseTimer = 0.0;
  static const double _dashStartPause = 0.18;
  static const double _dashEndPause = 0.16;

  // Scheduled slashes along the dash path
  final List<_ScheduledSlash> _scheduledSlashes = [];

  // Invulnerability and hit visual state
  double _hurtTimer = 0.0;
  bool get isHurt => _hurtTimer > 0.0;

  // Scroll return state: after dash, smoothly scroll world to bring player back
  bool _isScrollingBack = false;
  bool _isPerformingUltimate = false;
  bool get isPerformingUltimate => _isPerformingUltimate;
  bool get isResolvingAction =>
      isDashing || _isPerformingUltimate || _isScrollingBack;
  Vector2 _lastMovementDirection = Vector2(0, -1);
  Vector2 get experienceShardBurstDirection => _lastMovementDirection.clone();
  _UltimatePhase _ultimatePhase = _UltimatePhase.preScroll;
  double _ultimateTimer = 0.0;
  bool _ultimateCutTriggered = false;
  Vector2 _ultimateSlashStart = Vector2.zero();
  Vector2 _ultimateSlashEnd = Vector2.zero();
  static const double _ultimatePreScrollDuration = 0.18;
  static const double _ultimateSlashDuration = 0.34;
  static const double _ultimatePreScrollDistance = 150.0;

  // Sword trail points
  final List<Vector2> trailPoints = [];
  final int maxTrailPoints = 12;

  final List<ui.Image> _freefallFrames = [];
  ui.Image? _battoujutsuStartImage;
  ui.Image? _battoujutsuEndImage;
  double _animationTimer = 0.0;
  static const double _frameDuration = 0.09;
  static const Size _spriteDrawSize = Size(105.6, 187);
  static const Size _battoujutsuDrawSize = Size(144, 216);
  static const double _baseViewportHeightFactor = 2 / 3;

  final Paint _trailPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;
  final Paint _chainTimerPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round;
  final Paint _chainCountBackgroundPaint = Paint()
    ..color = const Color(0xFF05060A).withValues(alpha: 0.78);
  final Paint _shieldRingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;
  final Paint _shieldGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 9.0
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  PlayerComponent() {
    anchor = Anchor.center;
    size = Vector2(40, 40);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _freefallFrames.addAll(
      await Future.wait(_freefallFramePaths.map(game.images.load)),
    );
    _battoujutsuStartImage = await game.images.load(_battoujutsuStartPath);
    _battoujutsuEndImage = await game.images.load(_battoujutsuEndPath);
    resetToBasePosition();
  }

  static double baseYForViewportHeight(double height) {
    return height * _baseViewportHeightFactor;
  }

  @visibleForTesting
  static Size get freefallSpriteDrawSize => _spriteDrawSize;

  void resetToBasePosition() {
    position = Vector2(game.size.x / 2, baseYForViewportHeight(game.size.y));
    _baseY = position.y;
    isDashing = false;
    _isScrollingBack = false;
    _isPerformingUltimate = false;
    _dashWaypoints = [];
    _currentTargetIndex = 0;
    _dashProgress = 0.0;
    _dashSegmentElapsed = 0.0;
    _dashSegmentDuration = 0.0;
    _dashFacingLeft = false;
    _chainFacingLeft = false;
    _dashPhase = _DashPhase.moving;
    _dashPauseTimer = 0.0;
    _scheduledSlashes.clear();
    _lastMovementDirection = Vector2(0, -1);
    _activeSlashDirection = Vector2(0, -1);
  }

  void startUltimateSequence() {
    isDashing = false;
    _isScrollingBack = false;
    _isPerformingUltimate = true;
    _ultimatePhase = _UltimatePhase.preScroll;
    _ultimateTimer = 0.0;
    _ultimateCutTriggered = false;
    _ultimateSlashStart = position.clone();
    _ultimateSlashEnd = Vector2(position.x, -80);
    _activeSlashDirection = Vector2(0, -1);
    _dashWaypoints = [];
    _currentTargetIndex = 0;
    _dashProgress = 0.0;
    _dashPhase = _DashPhase.moving;
    for (final slash in _scheduledSlashes) {
      slash.isTriggered = true;
    }
    _scheduledSlashes.clear();
    trailPoints.clear();
  }

  // Trigger the chain slash dash along waypoints
  void startChainDash(List<Vector2> waypoints) {
    if (waypoints.isEmpty) return;
    game.rechargeShieldForSlash();
    isDashing = true;
    _isScrollingBack = false;
    _dashWaypoints = List.from(waypoints);
    _currentTargetIndex = 0;
    _dashStartPos = position.clone();
    _dashProgress = 0.0;
    _beginDashSegment();
    _updateDashDirectionAngle();
    _dashPhase = _DashPhase.windup;
    _dashPauseTimer = _dashStartPause;
    _scheduledSlashes.clear();

    // Pre-calculate all hits along the waypoints
    _calculatePathIntersections();
  }

  void lockChainDirection(Vector2 firstWaypoint) {
    _chainFacingLeft = shouldFlipBattoujutsuSpriteForDirection(
      firstWaypoint - position,
    );
  }

  static bool shouldFlipBattoujutsuSpriteForDirection(Vector2 direction) {
    // The generated battoujutsu sprites face left by default.
    return direction.x > 0;
  }

  @visibleForTesting
  static double dashSegmentDurationForDistance(double distance) {
    return max(0.0, distance) / dashSpeed;
  }

  @visibleForTesting
  static double dashMotionEase(double progress) {
    final t = progress.clamp(0.0, 1.0);
    if (t < 0.5) {
      return 4.0 * t * t * t;
    }
    return 1.0 - pow(-2.0 * t + 2.0, 3).toDouble() / 2.0;
  }

  void _calculatePathIntersections() {
    // Collect all targets and obstacles currently alive
    final targets = game.children.whereType<SlashTarget>().toList();
    final obstacles = game.children.whereType<ObstacleTarget>().toList();

    Vector2 segmentStart = position.clone();
    for (int i = 0; i < _dashWaypoints.length; i++) {
      final Vector2 segmentEnd = _dashWaypoints[i];
      final Vector2 segmentVec = segmentEnd - segmentStart;
      final double segmentLenSq = segmentVec.length2;

      if (segmentLenSq == 0) {
        segmentStart = segmentEnd;
        continue;
      }

      // Check targets
      for (final target in targets) {
        final Vector2 targetVec = target.position - segmentStart;
        final double dot = targetVec.dot(segmentVec);
        double t = dot / segmentLenSq;
        t = t.clamp(0.0, 1.0);

        final Vector2 projectionPoint = segmentStart + (segmentVec * t);
        final double distance = (target.position - projectionPoint).length;

        if (distance <= game.effectiveTargetHitRadius(target)) {
          _scheduledSlashes.add(
            _ScheduledSlash(
              object: target,
              segmentIndex: i,
              hitPoint: projectionPoint,
              t: t,
            ),
          );
        }
      }

      // Check obstacles
      for (final obstacle in obstacles) {
        final Vector2 obstacleVec = obstacle.position - segmentStart;
        final double dot = obstacleVec.dot(segmentVec);
        double t = dot / segmentLenSq;
        t = t.clamp(0.0, 1.0);

        final Vector2 projectionPoint = segmentStart + (segmentVec * t);
        final double distance = (obstacle.position - projectionPoint).length;

        if (distance <= obstacle.pathCollisionRadius) {
          _scheduledSlashes.add(
            _ScheduledSlash(
              object: obstacle,
              segmentIndex: i,
              hitPoint: projectionPoint,
              t: t,
            ),
          );
        }
      }

      segmentStart = segmentEnd;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animationTimer += dt;

    // Save trail point
    trailPoints.add(position.clone());
    if (trailPoints.length > maxTrailPoints) {
      trailPoints.removeAt(0);
    }

    // Hurt timer decay
    if (_hurtTimer > 0) {
      _hurtTimer -= dt;
    }

    if (_isPerformingUltimate) {
      _updateUltimateSequence(dt);
    } else if (isDashing) {
      _updateDash(dt);
    } else if (_isScrollingBack) {
      _updateScrollBack(dt);
    } else {
      _updateIdle(dt);
      _checkFloatingObjectCollisions(dt);
    }
  }

  void _updateUltimateSequence(double dt) {
    switch (_ultimatePhase) {
      case _UltimatePhase.preScroll:
        _ultimateTimer += dt;
        final step =
            _ultimatePreScrollDistance *
            min(dt / _ultimatePreScrollDuration, 1.0);
        game.shiftWorldForCamera(Vector2(0, step));
        if (_ultimateTimer >= _ultimatePreScrollDuration) {
          _ultimatePhase = _UltimatePhase.slash;
          _ultimateTimer = 0.0;
          _ultimateSlashStart = position.clone();
          _ultimateSlashEnd = Vector2(position.x, -80);
        }
      case _UltimatePhase.slash:
        if (!_ultimateCutTriggered) {
          _ultimateCutTriggered = true;
          game.executeUltimateCut();
        }
        _ultimateTimer += dt;
        final progress = (_ultimateTimer / _ultimateSlashDuration).clamp(
          0.0,
          1.0,
        );
        final eased = 1.0 - pow(1.0 - progress, 3).toDouble();
        final previousPosition = position.clone();
        position =
            _ultimateSlashStart +
            (_ultimateSlashEnd - _ultimateSlashStart) * eased;
        _rememberMovementDirection(position - previousPosition);
        _dashFacingLeft = false;
        if (progress >= 1.0) {
          _isPerformingUltimate = false;
          _startScrollBack();
        }
    }
  }

  void _updateIdle(double dt) {
    // Float/Hover at the bottom
    _hoverTimer += dt * _hoverSpeed;
    position.y = _baseY + sin(_hoverTimer) * _hoverAmplitude;
  }

  void _updateDash(double dt) {
    if (_currentTargetIndex >= _dashWaypoints.length) {
      // Dash completed! Transition to scroll-back phase
      _startScrollBack();
      return;
    }

    if (_dashPhase == _DashPhase.windup) {
      _dashPauseTimer -= dt;
      if (_dashPauseTimer <= 0.0) {
        _dashPhase = _DashPhase.moving;
      }
      return;
    }

    if (_dashPhase == _DashPhase.recovery) {
      _dashPauseTimer -= dt;
      if (_dashPauseTimer <= 0.0) {
        _advanceDashSegment();
      }
      return;
    }

    final Vector2 targetPos = _dashWaypoints[_currentTargetIndex];
    final Vector2 segmentVec = targetPos - _dashStartPos;
    final double segmentLength = segmentVec.length;
    final previousPosition = position.clone();
    if (segmentVec.length2 > 0) {
      _dashFacingLeft = shouldFlipBattoujutsuSpriteForDirection(segmentVec);
      _activeSlashDirection = segmentVec.normalized();
    }

    if (segmentLength <= 0.0 || _dashSegmentDuration <= 0.0) {
      position = targetPos.clone();
      _dashProgress = 1.0;
      _triggerSlashesOnSegment(_currentTargetIndex, 1.0);
      _dashPhase = _DashPhase.recovery;
      _dashPauseTimer = _dashEndPause;
      return;
    }

    _dashSegmentElapsed = min(_dashSegmentDuration, _dashSegmentElapsed + dt);
    final rawProgress = (_dashSegmentElapsed / _dashSegmentDuration).clamp(
      0.0,
      1.0,
    );
    final easedProgress = dashMotionEase(rawProgress);
    position = _dashStartPos + segmentVec * easedProgress;
    final movementDelta = position - previousPosition;
    if (movementDelta.length2 > 0) {
      _rememberMovementDirection(movementDelta);
      game.addLightfootDistance(movementDelta.length);
      _collectBonusAlongMovement(previousPosition, position);
    }

    _dashProgress = easedProgress;
    _triggerSlashesOnSegment(_currentTargetIndex, easedProgress);

    if (rawProgress >= 1.0) {
      // Arrived at waypoint! Move to next
      position = targetPos.clone();

      // Trigger any remaining slashes on this segment that weren't triggered yet
      _triggerSlashesOnSegment(_currentTargetIndex, 1.0);

      _dashProgress = 1.0;
      _dashPhase = _DashPhase.recovery;
      _dashPauseTimer = _dashEndPause;
    }
  }

  void _advanceDashSegment() {
    _currentTargetIndex++;
    _dashStartPos = position.clone();
    _dashProgress = 0.0;
    _dashSegmentElapsed = 0.0;

    if (_currentTargetIndex >= _dashWaypoints.length) {
      _startScrollBack();
      return;
    }

    _updateDashDirectionAngle();
    _beginDashSegment();
    _dashPhase = _DashPhase.windup;
    _dashPauseTimer = _dashStartPause;
  }

  void _beginDashSegment() {
    if (_currentTargetIndex >= _dashWaypoints.length) {
      _dashSegmentDuration = 0.0;
      return;
    }
    final distance =
        (_dashWaypoints[_currentTargetIndex] - _dashStartPos).length;
    _dashSegmentElapsed = 0.0;
    _dashSegmentDuration = dashSegmentDurationForDistance(distance);
  }

  void _updateDashDirectionAngle() {
    if (_currentTargetIndex >= _dashWaypoints.length) return;

    final direction = _dashWaypoints[_currentTargetIndex] - position;
    if (direction.length2 > 0) {
      _dashFacingLeft = shouldFlipBattoujutsuSpriteForDirection(direction);
      _activeSlashDirection = direction.normalized();
    }
  }

  void _startScrollBack() {
    isDashing = false;
    _isScrollingBack = true;
    game.collectPendingTargetExperience();
    game.onInputTurnCompleted();

    // Calculate how much the player climbed above baseY
    final double climbAmount = max(0.0, _baseY - position.y);
    if (climbAmount > 0) {
      // Notify the game to spawn new objects based on climb
      game.onPlayerClimbed(climbAmount);
    }
  }

  void _updateScrollBack(double dt) {
    // Move the camera with the player until the player returns to screen center/base height.
    final double cameraFollowSpeed = 2520.0;
    final double step = cameraFollowSpeed * dt;
    final targetPosition = Vector2(game.size.x / 2, _baseY);
    final toTarget = targetPosition - position;

    if (toTarget.length <= 1.0) {
      position = targetPosition;
      _isScrollingBack = false;
      game.resolvePendingLaserAttacks();
      return;
    }

    final cameraShift = toTarget.normalized() * min(step, toTarget.length);
    position.add(cameraShift);
    _rememberMovementDirection(cameraShift);
    game.shiftWorldForCamera(cameraShift);
  }

  void _rememberMovementDirection(Vector2 delta) {
    if (delta.length2 == 0) {
      return;
    }
    _lastMovementDirection = delta.normalized();
  }

  void _triggerSlashesOnSegment(int segmentIndex, double currentT) {
    final slashes = _scheduledSlashes
        .where(
          (s) =>
              s.segmentIndex == segmentIndex &&
              !s.isTriggered &&
              s.t <= currentT,
        )
        .toList(growable: false);

    for (final slash in slashes) {
      slash.isTriggered = true;
      final obj = slash.object;

      if (obj.parent != null) {
        // Calculate slice angle from the segment vector
        final Vector2 segmentVec = _dashWaypoints[segmentIndex] - _dashStartPos;
        final double sliceAngle = segmentVec.length > 0
            ? atan2(segmentVec.y, segmentVec.x)
            : 0.0;

        if (obj is SlashTarget) {
          final damageRoll = game.rollSlashDamage();
          if (damageRoll.isCritical) {
            game.triggerCriticalHit(slash.hitPoint);
          }
          switch (obj.hit(position, attackPower: damageRoll.damage)) {
            case TargetHitOutcome.sliced:
              obj.slice(slash.hitPoint, sliceAngle);
              game.triggerTargetSliced(slash.hitPoint, target: obj);
              break;
            case TargetHitOutcome.damaged:
              game.playSound(
                obj is LaserTarget
                    ? GameSound.laserAttack
                    : GameSound.targetHit,
              );
              obj.hitArmor(slash.hitPoint);
              if (game.chainStrikeUnlocked && canChainStrikeTarget(obj)) {
                _triggerChainStrike(obj, slash.hitPoint);
              }
              break;
            case TargetHitOutcome.ignored:
              break;
          }
        } else if (obj is ObstacleTarget) {
          final blockedByShield = game.triggerObstacleHit(slash.hitPoint);
          obj.removeFromParent();
          if (!blockedByShield) {
            _abortDash(slash.hitPoint);
            break; // Stop processing further slashes
          }
        }
      }
    }
  }

  @visibleForTesting
  static bool canChainStrikeTarget(SlashTarget target) =>
      target is! LaserTarget;

  void _triggerChainStrike(SlashTarget target, Vector2 hitPoint) {
    final nextSegmentIndex = _currentTargetIndex + 1;
    final nextPathStart = nextSegmentIndex < _dashWaypoints.length
        ? _dashWaypoints[_currentTargetIndex]
        : null;
    final nextPathEnd = nextSegmentIndex < _dashWaypoints.length
        ? _dashWaypoints[nextSegmentIndex]
        : null;
    final launch = chainStrikeLaunch(
      currentPosition: target.position,
      nextPathStart: nextPathStart,
      nextPathEnd: nextPathEnd,
      random: game.random,
    );

    if (nextPathEnd != null) {
      _scheduledSlashes.add(
        _ScheduledSlash(
          object: target,
          segmentIndex: nextSegmentIndex,
          hitPoint: launch.destination.clone(),
          t: launch.pathT,
        ),
      );
    }

    target.startChainStrikeMove(launch.destination);
    target.rearmDamageIfFarFrom(hitPoint);
    target.rearmDamageIfFarFrom(launch.destination);
  }

  static ChainStrikeLaunch chainStrikeLaunch({
    required Vector2 currentPosition,
    required Vector2? nextPathStart,
    required Vector2? nextPathEnd,
    required Random random,
  }) {
    if (nextPathStart != null && nextPathEnd != null) {
      final pathT = 0.25 + random.nextDouble() * 0.6;
      return ChainStrikeLaunch(
        destination: nextPathStart + (nextPathEnd - nextPathStart) * pathT,
        pathT: pathT,
      );
    }
    return ChainStrikeLaunch(
      destination: chainStrikeFallbackDestination(
        origin: currentPosition,
        random: random,
      ),
      pathT: 1.0,
    );
  }

  static Vector2 chainStrikeFallbackDestination({
    required Vector2 origin,
    required Random random,
    double distance = 180.0,
  }) {
    final angle = -pi / 2 + (random.nextDouble() - 0.5) * (pi / 2);
    return origin + Vector2(cos(angle), sin(angle)) * distance;
  }

  void _abortDash(Vector2 hitPoint) {
    position = hitPoint.clone();
    _dashStartPos = position.clone();
    for (final s in _scheduledSlashes) {
      s.isTriggered = true;
    }
    _currentTargetIndex = _dashWaypoints.length;
    _dashPhase = _DashPhase.recovery;
    _dashPauseTimer = _dashEndPause;
    _hurtTimer = 1.0; // Invulnerable flash
    // Go directly to scroll-back
    _startScrollBack();
  }

  void _checkFloatingObjectCollisions(double dt) {
    if (isHurt) return;

    final double collisionRadius = size.x / 2 + 12.0;
    final bonuses = game.children.whereType<BonusTarget>().toList();

    for (final bonus in bonuses) {
      final double distance = (bonus.position - position).length;
      if (distance < collisionRadius + bonus.size.x / 2) {
        bonus.removeFromParent();
        game.triggerBonusCollected(bonus.position);
        return;
      }
    }

    final energyShards = game.children.whereType<EnergyShard>().toList();
    for (final shard in energyShards) {
      final double distance = (shard.position - position).length;
      if (distance < collisionRadius + EnergyShard.collectRadius) {
        shard.removeFromParent();
        game.triggerEnergyShardCollected(shard.position);
        return;
      }
    }

    final obstacles = game.children.whereType<ObstacleTarget>().toList();
    for (final obstacle in obstacles) {
      final double distance = (obstacle.position - position).length;
      if (distance < collisionRadius + obstacle.touchCollisionRadius) {
        final blockedByShield = game.triggerObstacleHit(obstacle.position);
        obstacle.removeFromParent();
        if (!blockedByShield) {
          _hurtTimer = 1.0; // Invulnerable flashing
        }
        break;
      }
    }
  }

  void _collectBonusAlongMovement(Vector2 start, Vector2 end) {
    final collisionRadius = size.x / 2 + 12.0;
    final bonuses = game.children.whereType<BonusTarget>().toList();

    for (final bonus in bonuses) {
      final touchRadius = collisionRadius + bonus.size.x / 2;
      if (movementTouchesBonus(
        start: start,
        end: end,
        bonusPosition: bonus.position,
        radius: touchRadius,
      )) {
        bonus.removeFromParent();
        game.triggerBonusCollected(bonus.position);
        return;
      }
    }

    final energyShards = game.children.whereType<EnergyShard>().toList();
    for (final shard in energyShards) {
      final touchRadius = collisionRadius + EnergyShard.collectRadius;
      if (movementTouchesBonus(
        start: start,
        end: end,
        bonusPosition: shard.position,
        radius: touchRadius,
      )) {
        shard.removeFromParent();
        game.triggerEnergyShardCollected(shard.position);
      }
    }
  }

  static bool movementTouchesBonus({
    required Vector2 start,
    required Vector2 end,
    required Vector2 bonusPosition,
    required double radius,
  }) {
    final segment = end - start;
    if (segment.length2 == 0) {
      return (bonusPosition - start).length <= radius;
    }

    final t = ((bonusPosition - start).dot(segment) / segment.length2).clamp(
      0.0,
      1.0,
    );
    final closestPoint = start + segment * t;
    return (bonusPosition - closestPoint).length <= radius;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final double radius = size.x / 2;

    // Draw sword slash trail
    if (trailPoints.length > 1) {
      for (int i = 0; i < trailPoints.length - 1; i++) {
        final p1 = trailPoints[i];
        final p2 = trailPoints[i + 1];

        final offset1 = Offset(
          p1.x - position.x + radius,
          p1.y - position.y + radius,
        );
        final offset2 = Offset(
          p2.x - position.x + radius,
          p2.y - position.y + radius,
        );

        final double ratio = i / (trailPoints.length - 1);
        _trailPaint.color = (isDashing || _isPerformingUltimate)
            ? const Color(0xFF00FFCC).withValues(alpha: ratio * 0.8)
            : const Color(0xFF00FF88).withValues(alpha: ratio * 0.3);
        _trailPaint.strokeWidth = (isDashing || _isPerformingUltimate)
            ? (ratio * 8.0)
            : (ratio * 3.0);

        canvas.drawLine(offset1, offset2, _trailPaint);
      }
    }

    if (_freefallFrames.isEmpty) return;

    if (game.shieldCharges > 0) {
      _drawShieldAura(canvas, Offset(radius, radius));
    }

    final isChaining = game.currentChainPoints.isNotEmpty && !isDashing;
    if (isChaining && _battoujutsuStartImage != null) {
      _drawSpriteImage(
        canvas: canvas,
        image: _battoujutsuStartImage!,
        center: Offset(radius, radius),
        drawSize: _battoujutsuDrawSize,
        rotation: 0.0,
        flipX: _chainFacingLeft,
        isDashingTinted: false,
      );
      _drawChainCountdown(canvas, Offset(radius, radius));
      _drawRemainingSlashCount(canvas, Offset(radius, radius));
      return;
    }

    if ((isDashing || _isPerformingUltimate) &&
        _battoujutsuStartImage != null &&
        _battoujutsuEndImage != null) {
      final image =
          (_isPerformingUltimate ||
              _dashPhase == _DashPhase.windup ||
              _dashProgress < 0.42)
          ? _battoujutsuStartImage!
          : _battoujutsuEndImage!;
      for (final offset in shadowCloneOffsetsForDirection(
        game.shadowCloneLevel,
        _activeSlashDirection,
      )) {
        _drawSpriteImage(
          canvas: canvas,
          image: image,
          center: Offset(radius + offset.x, radius + offset.y),
          drawSize: _battoujutsuDrawSize,
          rotation: 0.0,
          flipX: _dashFacingLeft,
          isDashingTinted: true,
          opacity: 0.36,
        );
      }
      _drawSpriteImage(
        canvas: canvas,
        image: image,
        center: Offset(radius, radius),
        drawSize: _battoujutsuDrawSize,
        rotation: 0.0,
        flipX: _dashFacingLeft,
        isDashingTinted: false,
      );
      return;
    }

    final int frameIndex =
        (_animationTimer / _frameDuration).floor() % _freefallFrames.length;
    _drawSpriteImage(
      canvas: canvas,
      image: _freefallFrames[frameIndex],
      center: Offset(radius, radius),
      drawSize: _spriteDrawSize,
      rotation: 0.0,
      flipX: false,
      isDashingTinted: false,
    );
  }

  @visibleForTesting
  static List<double> shadowCloneOffsetsForLevel(int level) {
    return shadowCloneOffsetsForDirection(
      level,
      Vector2(0, -1),
    ).map((offset) => offset.x).toList(growable: false);
  }

  @visibleForTesting
  static List<Vector2> shadowCloneOffsetsForDirection(
    int level,
    Vector2 direction,
  ) {
    const spacing = 60.0;
    final clampedLevel = level.clamp(0, 4);
    var slashDirection = direction.clone();
    if (slashDirection.length2 == 0) {
      slashDirection = Vector2(0, -1);
    } else {
      slashDirection.normalize();
    }
    final rightNormal = Vector2(-slashDirection.y, slashDirection.x);
    final offsets = <Vector2>[];
    for (var i = 0; i < clampedLevel; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final rank = i ~/ 2 + 1;
      offsets.add(rightNormal * (side * spacing * rank));
    }
    return offsets;
  }

  void _drawShieldAura(Canvas canvas, Offset center) {
    const shieldColor = Color(0xFF38BDF8);
    final pulse = (sin(_animationTimer * 5.2) + 1.0) / 2.0;
    final ringRadius = 78.0 + pulse * 5.0;
    final glowAlpha = 0.18 + pulse * 0.12;
    final ringAlpha = 0.72 + pulse * 0.2;

    _shieldGlowPaint
      ..color = shieldColor.withValues(alpha: glowAlpha)
      ..strokeWidth = 10.0 + pulse * 4.0;
    _shieldRingPaint
      ..color = shieldColor.withValues(alpha: ringAlpha)
      ..strokeWidth = 2.5 + pulse * 0.8;

    canvas.drawCircle(center, ringRadius, _shieldGlowPaint);
    canvas.drawCircle(center, ringRadius, _shieldRingPaint);
    canvas.drawCircle(
      center,
      ringRadius + 9.0,
      _shieldRingPaint..color = shieldColor.withValues(alpha: 0.18),
    );
  }

  void _drawChainCountdown(Canvas canvas, Offset center) {
    final progress = (1.0 - game.chainTimer / game.maxChainTime).clamp(
      0.0,
      1.0,
    );
    final radius = 64.0 * progress + 20.0 * (1.0 - progress);
    _chainTimerPaint.color = Colors.white.withValues(alpha: 0.75);
    canvas.drawCircle(center, radius, _chainTimerPaint);
  }

  void _drawRemainingSlashCount(Canvas canvas, Offset center) {
    final remaining = max(
      0,
      game.maxChainLength - game.currentChainPoints.length,
    );
    final label = '$remaining';
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 24,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: const Color(0xFF00FFCC).withValues(alpha: 0.85),
              blurRadius: 10,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeCenter = center.translate(-70, -18);
    final badgeRect = Rect.fromCenter(
      center: badgeCenter,
      width: 48,
      height: 38,
    );
    final borderPaint = Paint()
      ..color = const Color(0xFF00FFCC).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(8)),
      _chainCountBackgroundPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(8)),
      borderPaint,
    );
    textPainter.paint(
      canvas,
      Offset(
        badgeCenter.dx - textPainter.width / 2,
        badgeCenter.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawSpriteImage({
    required Canvas canvas,
    required ui.Image image,
    required Offset center,
    required Size drawSize,
    required double rotation,
    required bool flipX,
    required bool isDashingTinted,
    double opacity = 1.0,
  }) {
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final destination = Rect.fromCenter(
      center: Offset.zero,
      width: drawSize.width,
      height: drawSize.height,
    );
    final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
    if (isHurt) {
      paint.colorFilter = const ColorFilter.mode(
        Colors.red,
        BlendMode.modulate,
      );
    } else if (isDashingTinted) {
      paint.colorFilter = const ColorFilter.mode(
        Color(0xFFAAFFF0),
        BlendMode.modulate,
      );
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    if (flipX) {
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(image, source, destination, paint);
    canvas.restore();
  }
}

class ChainStrikeLaunch {
  final Vector2 destination;
  final double pathT;

  const ChainStrikeLaunch({required this.destination, required this.pathT});
}

// Helper class to schedule slices mid-dash segment
class _ScheduledSlash {
  final FloatingObject object;
  final int segmentIndex;
  final Vector2 hitPoint;
  final double t; // parameter progress (0.0 to 1.0) along segment
  bool isTriggered = false;

  _ScheduledSlash({
    required this.object,
    required this.segmentIndex,
    required this.hitPoint,
    required this.t,
  });
}
