import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'target.dart';

class PlayerComponent extends PositionComponent with HasGameReference<QuickDrawGame> {
  // Idle floating properties
  double _hoverTimer = 0.0;
  final double _hoverSpeed = 3.0;
  final double _hoverAmplitude = 15.0;
  late double _baseY;

  // Dashing state properties
  bool isDashing = false;
  List<Vector2> _dashWaypoints = [];
  int _currentTargetIndex = 0;
  final double _dashSpeed = 2500.0;
  Vector2 _dashStartPos = Vector2.zero();

  // Scheduled slashes along the dash path
  final List<_ScheduledSlash> _scheduledSlashes = [];

  // Invulnerability and hit visual state
  double _hurtTimer = 0.0;
  bool get isHurt => _hurtTimer > 0.0;

  // Sword trail points
  final List<Vector2> trailPoints = [];
  final int maxTrailPoints = 12;

  final Paint _trailPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;

  PlayerComponent() {
    anchor = Anchor.center;
    size = Vector2(40, 40);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    resetToBasePosition();
  }

  void resetToBasePosition() {
    position = Vector2(game.size.x / 2, game.size.y - 120);
    _baseY = position.y;
    isDashing = false;
    _dashWaypoints = [];
    _currentTargetIndex = 0;
    _scheduledSlashes.clear();
  }

  // Trigger the chain slash dash along waypoints
  void startChainDash(List<Vector2> waypoints) {
    if (waypoints.isEmpty) return;
    isDashing = true;
    _dashWaypoints = List.from(waypoints);
    _currentTargetIndex = 0;
    _dashStartPos = position.clone();
    _scheduledSlashes.clear();

    // Pre-calculate all hits along the waypoints
    _calculatePathIntersections();

    // Speed up background scrolling during dash
    final background = game.background;
    if (background != null) {
      background.currentSpeed = background.dashSpeed;
    }
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

        // If target is within 40px of this segment, schedule a slice
        if (distance <= 40.0) {
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

        if (distance <= 40.0) {
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

    // Save trail point
    trailPoints.add(position.clone());
    if (trailPoints.length > maxTrailPoints) {
      trailPoints.removeAt(0);
    }

    // Hurt timer decay
    if (_hurtTimer > 0) {
      _hurtTimer -= dt;
    }

    if (isDashing) {
      _updateDash(dt);
    } else {
      _updateIdle(dt);
      _checkObstacleCollisions(dt); // Collision checks outside of dashing
    }
  }

  void _updateIdle(double dt) {
    // Float/Hover at the bottom
    _hoverTimer += dt * _hoverSpeed;
    position.y = _baseY + sin(_hoverTimer) * _hoverAmplitude;
    
    // Slowly drift player back to center horizontally if they were moved
    final double targetX = game.size.x / 2;
    position.x += (targetX - position.x) * 4.0 * dt;
  }

  void _updateDash(double dt) {
    if (_currentTargetIndex >= _dashWaypoints.length) {
      // Dash completed! Return to base position
      _finishDash(dt);
      return;
    }

    final Vector2 targetPos = _dashWaypoints[_currentTargetIndex];
    final Vector2 direction = targetPos - position;
    final double distance = direction.length;
    final double moveStep = _dashSpeed * dt;

    if (distance <= moveStep) {
      // Trigger any remaining slashes on this segment that weren't triggered yet
      _triggerSlashesOnSegment(_currentTargetIndex, 1.0);

      // Arrived at waypoint! Move to next
      position = targetPos.clone();
      _dashStartPos = position.clone();
      _currentTargetIndex++;
    } else {
      // Move towards waypoint
      direction.normalize();
      position.add(direction * moveStep);

      // Check current progress t along this segment to trigger slices mid-flight
      final Vector2 currentSegmentVec = targetPos - _dashStartPos;
      final double totalLen = currentSegmentVec.length;
      if (totalLen > 0) {
        final double currentLen = (position - _dashStartPos).length;
        final double t = currentLen / totalLen;
        _triggerSlashesOnSegment(_currentTargetIndex, t);
      }
    }
  }

  void _triggerSlashesOnSegment(int segmentIndex, double currentT) {
    final slashes = _scheduledSlashes.where(
      (s) => s.segmentIndex == segmentIndex && !s.isTriggered && s.t <= currentT,
    );

    for (final slash in slashes) {
      slash.isTriggered = true;
      final obj = slash.object;
      
      if (obj.parent != null) {
        // Calculate slice angle from the segment vector
        final Vector2 segmentVec = _dashWaypoints[segmentIndex] - _dashStartPos;
        final double sliceAngle = segmentVec.length > 0 ? atan2(segmentVec.y, segmentVec.x) : 0.0;

        if (obj is SlashTarget) {
          obj.slice(slash.hitPoint, sliceAngle);
          game.triggerTargetSliced();
        } else if (obj is ObstacleTarget) {
          game.triggerObstacleHit(slash.hitPoint);
          obj.removeFromParent();
          _abortDash(slash.hitPoint);
          break; // Stop processing further slashes
        }
      }
    }
  }

  void _abortDash(Vector2 hitPoint) {
    position = hitPoint.clone();
    _dashStartPos = position.clone();
    for (final s in _scheduledSlashes) {
      s.isTriggered = true;
    }
    _currentTargetIndex = _dashWaypoints.length;
    _hurtTimer = 1.0; // Invulnerable flash
  }

  void _finishDash(double dt) {
    // Slowly move back to base vertical and horizontal center
    final Vector2 targetBase = Vector2(game.size.x / 2, _baseY);
    final Vector2 returnVec = targetBase - position;
    final double returnDist = returnVec.length;
    
    // Slow down background speed back to normal
    final background = game.background;
    if (background != null) {
      background.currentSpeed += (background.normalSpeed - background.currentSpeed) * 8.0 * dt;
    }

    if (returnDist < 10.0) {
      position = targetBase;
      isDashing = false;
      if (background != null) {
        background.currentSpeed = background.normalSpeed;
      }
    } else {
      returnVec.normalize();
      position.add(returnVec * 1200.0 * dt);
    }
  }

  void _checkObstacleCollisions(double dt) {
    if (isHurt) return;

    final double collisionRadius = size.x / 2 + 12.0;
    final obstacles = game.children.whereType<ObstacleTarget>();

    for (final obstacle in obstacles) {
      final double distance = (obstacle.position - position).length;
      if (distance < collisionRadius) {
        game.triggerObstacleHit(obstacle.position);
        obstacle.removeFromParent();
        _hurtTimer = 1.0; // Invulnerable flashing
        break;
      }
    }
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
        
        final offset1 = Offset(p1.x - position.x + radius, p1.y - position.y + radius);
        final offset2 = Offset(p2.x - position.x + radius, p2.y - position.y + radius);

        final double ratio = i / (trailPoints.length - 1);
        _trailPaint.color = isDashing 
            ? const Color(0xFF00FFCC).withOpacity(ratio * 0.8) 
            : const Color(0xFF00FF88).withOpacity(ratio * 0.3);
        _trailPaint.strokeWidth = isDashing ? (ratio * 8.0) : (ratio * 3.0);
        
        canvas.drawLine(offset1, offset2, _trailPaint);
      }
    }

    final Color playerColor = isHurt 
        ? Colors.red 
        : (isDashing ? const Color(0xFF00FFCC) : const Color(0xFF00FF88));

    final Paint playerPaint = Paint()..color = playerColor;
    
    final Path playerPath = Path()
      ..moveTo(radius, 0)
      ..lineTo(radius * 2, radius)
      ..lineTo(radius, radius * 2)
      ..lineTo(0, radius)
      ..close();

    final Paint glowPaint = Paint()
      ..color = playerColor.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(playerPath, glowPaint);
    
    canvas.drawPath(playerPath, playerPaint);

    final Paint corePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(radius, radius), 4, corePaint);
  }
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
