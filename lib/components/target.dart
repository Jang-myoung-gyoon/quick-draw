import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../main.dart';

// base class for items floating down
abstract class FloatingObject extends PositionComponent with HasGameReference<QuickDrawGame> {
  double speed = 80.0;
  double driftTimer = 0.0;
  double driftSpeed = 1.0;
  double driftAmount = 0.5;
  double baseSpeed = 80.0;

  FloatingObject() {
    anchor = Anchor.center;
    size = Vector2(48, 48);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    driftSpeed = 0.5 + Random().nextDouble() * 1.5;
    driftAmount = 0.2 + Random().nextDouble() * 0.8;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Adjust speed based on whether game background is speeding up (player is dashing)
    final background = game.background;
    if (background != null) {
      if (background.currentSpeed > background.normalSpeed) {
        // Fast scroll down (relative movement during dash)
        position.y += (background.currentSpeed - background.normalSpeed) * dt;
      } else {
        // Normal falling
        position.y += speed * dt;
      }
    } else {
      position.y += speed * dt;
    }

    // Drift side to side slightly
    driftTimer += dt * driftSpeed;
    position.x += sin(driftTimer) * driftAmount;

    // Remove if off-screen (bottom)
    if (position.y > game.size.y + size.y) {
      removeFromParent();
      onMissed();
    }
  }

  void onMissed() {}
}

class SlashTarget extends FloatingObject with TapCallbacks {
  bool isTargeted = false;
  int chainIndex = -1; // -1 if not targeted, otherwise 0, 1, 2...
  
  final Paint _paint = Paint()..color = const Color(0xFF00E5FF);
  final Paint _targetPaint = Paint()
    ..color = const Color(0xFFFF2D55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final double radius = size.x / 2;

    if (isTargeted) {
      // Glow/Target ring
      canvas.drawCircle(Offset(radius, radius), radius + 8, _targetPaint);
      
      // Target number
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${chainIndex + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(radius - textPainter.width / 2, radius - textPainter.height / 2),
      );

      // Core targeted orb
      final targetedCorePaint = Paint()..color = const Color(0xFFFF2D55);
      canvas.drawCircle(Offset(radius, radius), radius - 6, targetedCorePaint);
    } else {
      // Neon blue glowing orb
      final glowPaint = Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(radius, radius), radius, glowPaint);
      
      // Core cyan orb
      canvas.drawCircle(Offset(radius, radius), radius - 4, _paint);

      // Inner white highlights
      final highlightPaint = Paint()..color = Colors.white.withOpacity(0.8);
      canvas.drawCircle(Offset(radius - 4, radius - 4), 3, highlightPaint);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (!game.isPlaying) return;
    
    // Add to chain if possible
    if (!isTargeted && !game.player.isDashing) {
      game.addToChain(this);
    }
  }

  // Trigger when player slices this target
  void slice(double sliceAngle) {
    // Create particle sparks
    game.spawnSliceParticles(position, const Color(0xFF00E5FF));

    // Spawn sliced halves
    final leftHalf = SlicedHalfComponent(
      position: position.clone(),
      angle: sliceAngle,
      isLeft: true,
      color: isTargeted ? const Color(0xFFFF2D55) : const Color(0xFF00E5FF),
    );
    final rightHalf = SlicedHalfComponent(
      position: position.clone(),
      angle: sliceAngle,
      isLeft: false,
      color: isTargeted ? const Color(0xFFFF2D55) : const Color(0xFF00E5FF),
    );

    game.add(leftHalf);
    game.add(rightHalf);

    removeFromParent();
  }

  @override
  void onMissed() {
    // If a targeted item escapes, it resets the combo
    if (isTargeted) {
      game.resetChain();
    }
  }
}

class ObstacleTarget extends FloatingObject with TapCallbacks {
  final Paint _paint = Paint()..color = const Color(0xFFFF7B00);
  final Paint _glowPaint = Paint()
    ..color = const Color(0xFFFF7B00).withOpacity(0.3)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  
  double rotationSpeed = 2.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    speed = 100.0; // slightly faster than targets
    rotationSpeed = (Random().nextDouble() - 0.5) * 6.0;
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
    
    // Draw neon orange hazard spikes
    canvas.drawCircle(Offset(radius, radius), radius - 4, _glowPaint);

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
    final corePaint = Paint()..color = const Color(0xFF1E0E05);
    canvas.drawCircle(Offset(radius, radius), radius - 10, corePaint);
    final coreGlow = Paint()..color = const Color(0xFFFF0055);
    canvas.drawCircle(Offset(radius, radius), 3, coreGlow);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (!game.isPlaying) return;

    // Tapping an obstacle causes instant damage and breaks the chain
    game.triggerObstacleHit(position);
    removeFromParent();
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
    this.angle += rotationSpeed * dt;

    // Fade out
    opacity -= dt * 2.0;
    if (opacity <= 0.0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final double radius = size.x / 2;
    final halfPaint = Paint()
      ..color = color.withOpacity(opacity.clamp(0.0, 1.0));

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
      ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset.zero, radius - 4, strokePaint);

    canvas.restore();
  }
}
