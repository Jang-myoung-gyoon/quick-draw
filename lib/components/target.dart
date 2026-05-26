import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../main.dart';

// Base class for objects drifting in place (free-falling together with player)
abstract class FloatingObject extends PositionComponent with HasGameReference<QuickDrawGame> {
  double driftTimer = 0.0;
  double driftSpeed = 1.0;
  double driftAmount = 0.5;
  Vector2 driftDirection = Vector2.zero();

  // Fade-in/out lifetime variables
  double age = 0.0;
  final double lifetime = 6.0;
  double opacity = 0.0;

  FloatingObject() {
    anchor = Anchor.center;
    size = Vector2(48, 48);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    driftSpeed = 0.4 + Random().nextDouble() * 0.8;
    driftAmount = 5.0 + Random().nextDouble() * 10.0; // drift offset amplitude
    
    final double angle = Random().nextDouble() * 2 * pi;
    driftDirection = Vector2(cos(angle), sin(angle));
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update age and calculate fade opacity
    age += dt;
    if (age < 0.5) {
      // Fade in (0 to 0.5 seconds)
      opacity = age / 0.5;
    } else if (age < 4.5) {
      // Full opacity
      opacity = 1.0;
    } else if (age < lifetime) {
      // Fade out (4.5 to 6 seconds)
      opacity = 1.0 - (age - 4.5) / 1.5;
    } else {
      removeFromParent();
      onMissed();
      return;
    }

    // Floating/Drifting slowly in place (relative speed is 0)
    driftTimer += dt * driftSpeed;
    final driftOffset = driftDirection * sin(driftTimer) * driftAmount * dt;
    position.add(driftOffset);
  }

  void onMissed() {}
}

class SlashTarget extends FloatingObject {
  bool isTargeted = false;
  int chainIndex = -1; // Not used for ordering anymore, but kept for highlight index
  
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
      // Targeted glow ring
      _targetPaint.color = const Color(0xFFFF2D55).withOpacity(opacity);
      canvas.drawCircle(Offset(radius, radius), radius + 8, _targetPaint);

      // Core targeted orb
      final targetedCorePaint = Paint()..color = const Color(0xFFFF2D55).withOpacity(opacity);
      canvas.drawCircle(Offset(radius, radius), radius - 6, targetedCorePaint);
    } else {
      // Neon blue glowing orb
      final glowPaint = Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(radius, radius), radius, glowPaint);
      
      // Core cyan orb
      _paint.color = const Color(0xFF00E5FF).withOpacity(opacity);
      canvas.drawCircle(Offset(radius, radius), radius - 4, _paint);

      // Inner white highlights
      final highlightPaint = Paint()..color = Colors.white.withOpacity(opacity * 0.8);
      canvas.drawCircle(Offset(radius - 4, radius - 4), 3, highlightPaint);
    }
  }

  // Trigger when player slices this target at a specific intersection point
  void slice(Vector2 hitPoint, double sliceAngle) {
    // Create particle sparks at the hit point
    game.spawnSliceParticles(hitPoint, const Color(0xFF00E5FF));

    // Spawn sliced halves starting from the hit point
    final leftHalf = SlicedHalfComponent(
      position: hitPoint.clone(),
      angle: sliceAngle,
      isLeft: true,
      color: isTargeted ? const Color(0xFFFF2D55) : const Color(0xFF00E5FF),
    );
    final rightHalf = SlicedHalfComponent(
      position: hitPoint.clone(),
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
    // If a targeted item expires without being slashed, reset chain
    if (isTargeted && game.isPlaying) {
      game.resetChain();
    }
  }
}

class ObstacleTarget extends FloatingObject {
  final Paint _paint = Paint()..color = const Color(0xFFFF7B00);
  final Paint _glowPaint = Paint()
    ..color = const Color(0xFFFF7B00).withOpacity(0.3)
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
    _glowPaint.color = const Color(0xFFFF7B00).withOpacity(opacity * 0.3);
    canvas.drawCircle(Offset(radius, radius), radius - 4, _glowPaint);

    _paint.color = const Color(0xFFFF7B00).withOpacity(opacity);
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
    final corePaint = Paint()..color = const Color(0xFF1E0E05).withOpacity(opacity);
    canvas.drawCircle(Offset(radius, radius), radius - 10, corePaint);
    final coreGlow = Paint()..color = const Color(0xFFFF0055).withOpacity(opacity);
    canvas.drawCircle(Offset(radius, radius), 3, coreGlow);
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
