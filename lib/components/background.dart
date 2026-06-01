import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class FallingBackground extends PositionComponent with HasGameReference {
  final List<_BackgroundParticle> _particles = [];
  double _scrollOffset = 0.0;
  final Random _random = Random();

  // Base scroll speed representing falling
  double currentSpeed = 100.0;
  final double normalSpeed = 100.0;
  final double dashSpeed = 1200.0;

  FallingBackground() {
    // We want the background to fill the screen
    priority = -10; // Render behind everything else
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = game.size;

    // Initialize background particles
    for (int i = 0; i < 40; i++) {
      _particles.add(
        _BackgroundParticle(
          position: Vector2(
            _random.nextDouble() * size.x,
            _random.nextDouble() * size.y,
          ),
          speedMultiplier: 0.5 + _random.nextDouble() * 1.5,
          radius: 1.0 + _random.nextDouble() * 2.5,
          opacity: 0.1 + _random.nextDouble() * 0.4,
        ),
      );
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Scroll vertical grid lines upwards
    _scrollOffset -= currentSpeed * dt;
    if (_scrollOffset.abs() >= 100.0) {
      _scrollOffset = _scrollOffset % 100.0;
    }

    // Update background particles moving upwards (opposite to player falling)
    for (final particle in _particles) {
      particle.position.y -= currentSpeed * particle.speedMultiplier * dt;
      if (particle.position.y < 0) {
        particle.position.y = size.y;
        particle.position.x = _random.nextDouble() * size.x;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw dark space background
    final bgPaint = Paint()..color = const Color(0xFF0D0E15);
    canvas.drawRect(size.toRect(), bgPaint);

    // Draw faint grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1E2135).withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    // Vertical grid lines
    const int verticalGridCount = 8;
    final double spacingX = size.x / verticalGridCount;
    for (int i = 0; i <= verticalGridCount; i++) {
      final double x = i * spacingX;
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), gridPaint);
    }

    // Horizontal scrolling grid lines
    final double spacingY = 100.0;
    double y = _scrollOffset;
    while (y < size.y) {
      if (y >= 0) {
        canvas.drawLine(Offset(0, y), Offset(size.x, y), gridPaint);
      }
      y += spacingY;
    }

    // Render particles (stars/sparks floating up)
    for (final particle in _particles) {
      final particlePaint = Paint()
        ..color = const Color(0xFF86A5FF).withValues(alpha: particle.opacity);
      canvas.drawCircle(
        Offset(particle.position.x, particle.position.y),
        particle.radius,
        particlePaint,
      );
    }
  }

  /// Apply an instant scroll boost when the camera follows the player.
  void applyScrollBoost(Vector2 delta) {
    // Push particles with parallax.
    for (final particle in _particles) {
      particle.position.x += delta.x * particle.speedMultiplier * 0.25;
      particle.position.y += delta.y * particle.speedMultiplier * 0.5;
      if (particle.position.x < 0) {
        particle.position.x += size.x;
      } else if (particle.position.x > size.x) {
        particle.position.x -= size.x;
      }
      if (particle.position.y > size.y) {
        particle.position.y -= size.y;
        particle.position.x = _random.nextDouble() * size.x;
      }
    }
    // Shift grid
    _scrollOffset += delta.y * 0.3;
  }
}

class _BackgroundParticle {
  Vector2 position;
  final double speedMultiplier;
  final double radius;
  final double opacity;

  _BackgroundParticle({
    required this.position,
    required this.speedMultiplier,
    required this.radius,
    required this.opacity,
  });
}
