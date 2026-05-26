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
  List<SlashTarget> _dashTargets = [];
  int _currentTargetIndex = 0;
  double _dashSpeed = 2500.0;
  Vector2 _dashStartPos = Vector2.zero();

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
    _dashTargets = [];
    _currentTargetIndex = 0;
  }

  // Trigger the chain slash dash
  void startChainDash(List<SlashTarget> targets) {
    if (targets.isEmpty) return;
    isDashing = true;
    _dashTargets = List.from(targets);
    _currentTargetIndex = 0;
    _dashStartPos = position.clone();
    
    // Speed up background scrolling during dash
    final background = game.background;
    if (background != null) {
      background.currentSpeed = background.dashSpeed;
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
      _checkObstacleCollisions(dt);
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
    if (_currentTargetIndex >= _dashTargets.length) {
      // Dash completed! Return to base position
      _finishDash(dt);
      return;
    }

    final target = _dashTargets[_currentTargetIndex];
    // If the target has already been removed or missed, move to next
    if (target.parent == null) {
      _currentTargetIndex++;
      return;
    }

    final Vector2 direction = target.position - position;
    final double distance = direction.length;
    final double moveStep = _dashSpeed * dt;

    if (distance <= moveStep) {
      // Arrived at target! Perform slice
      position = target.position.clone();
      
      // Calculate slice angle (angle of dash vector)
      final Vector2 slashVec = position - _dashStartPos;
      final double sliceAngle = slashVec.length > 0 ? atan2(slashVec.y, slashVec.x) : 0.0;

      // Slice the target
      target.slice(sliceAngle);
      game.triggerTargetSliced();

      // Proceed to next target
      _dashStartPos = position.clone();
      _currentTargetIndex++;
    } else {
      // Move towards target
      direction.normalize();
      position.add(direction * moveStep);
    }
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
    if (isHurt) return; // Invulnerable while flashing red

    final double collisionRadius = size.x / 2 + 12.0; // custom tight radius
    final obstacles = game.children.whereType<ObstacleTarget>();

    for (final obstacle in obstacles) {
      final double distance = (obstacle.position - position).length;
      if (distance < collisionRadius) {
        // Collided! Take damage
        game.triggerObstacleHit(obstacle.position);
        obstacle.removeFromParent();
        _hurtTimer = 1.0; // 1 second of invulnerability/flash
        break;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final double radius = size.x / 2;

    // Draw sword slash trail behind player
    if (trailPoints.length > 1) {
      for (int i = 0; i < trailPoints.length - 1; i++) {
        final p1 = trailPoints[i];
        final p2 = trailPoints[i + 1];
        
        // Convert to local coordinates relative to component position
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

    // Determine color (flash red if hurt)
    final Color playerColor = isHurt 
        ? Colors.red 
        : (isDashing ? const Color(0xFF00FFCC) : const Color(0xFF00FF88));

    final Paint playerPaint = Paint()..color = playerColor;
    
    // Draw neon glowing player shape (a diamond pointing upwards)
    final Path playerPath = Path()
      ..moveTo(radius, 0) // top
      ..lineTo(radius * 2, radius) // right
      ..lineTo(radius, radius * 2) // bottom
      ..lineTo(0, radius) // left
      ..close();

    // Draw shadow/glow
    final Paint glowPaint = Paint()
      ..color = playerColor.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(playerPath, glowPaint);
    
    // Draw main body
    canvas.drawPath(playerPath, playerPaint);

    // Core white highlight
    final Paint corePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(radius, radius), 4, corePaint);
  }
}
