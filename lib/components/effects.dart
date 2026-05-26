import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../main.dart';

class SlashPathLine extends Component with HasGameReference<QuickDrawGame> {
  final List<Vector2> waypoints;
  
  final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..color = const Color(0xFFFF2D55);

  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10.0
    ..color = const Color(0xFFFF2D55).withOpacity(0.3)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

  double _pulseTimer = 0.0;

  SlashPathLine({required this.waypoints});

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt * 5.0;
  }

  @override
  void render(Canvas canvas) {
    if (waypoints.isEmpty) return;

    final Path path = Path();
    path.moveTo(waypoints[0].x, waypoints[0].y);
    
    for (int i = 1; i < waypoints.length; i++) {
      path.lineTo(waypoints[i].x, waypoints[i].y);
    }

    // Set paint width based on pulse
    final double pulseWidth = 3.0 + sin(_pulseTimer).abs() * 2.0;
    _linePaint.strokeWidth = pulseWidth;
    _glowPaint.strokeWidth = pulseWidth + 7.0;

    // Draw glowing neon path
    canvas.drawPath(path, _glowPaint);
    canvas.drawPath(path, _linePaint);

    // Draw lead line from player to first waypoint if not yet dashing
    if (!game.player.isDashing) {
      final playerPos = game.player.position;
      final leadPaint = Paint()
        ..color = const Color(0xFFFF2D55).withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(playerPos.x, playerPos.y),
        Offset(waypoints[0].x, waypoints[0].y),
        leadPaint,
      );
    }
  }
}

class SliceParticleEmitter extends Component {
  final Vector2 position;
  final Color color;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  SliceParticleEmitter({required this.position, required this.color});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Spawn glowing spark particles
    final int count = 20 + _random.nextInt(15);
    for (int i = 0; i < count; i++) {
      final double angle = _random.nextDouble() * 2 * pi;
      final double speed = 100.0 + _random.nextDouble() * 300.0;
      _particles.add(
        _Particle(
          position: position.clone(),
          velocity: Vector2(cos(angle), sin(angle)) * speed,
          color: color,
          radius: 1.5 + _random.nextDouble() * 2.5,
          lifeSpan: 0.3 + _random.nextDouble() * 0.5,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    for (final p in _particles) {
      p.update(dt);
    }
    
    _particles.removeWhere((p) => p.isDead);

    if (_particles.isEmpty) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (final p in _particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity.clamp(0.0, 1.0));
      
      if (_random.nextDouble() > 0.5) {
        final glowPaint = Paint()
          ..color = p.color.withOpacity(p.opacity * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(p.position.x, p.position.y), p.radius + 3, glowPaint);
      }

      canvas.drawCircle(Offset(p.position.x, p.position.y), p.radius, paint);
    }
  }
}

class _Particle {
  Vector2 position;
  Vector2 velocity;
  final Color color;
  final double radius;
  final double lifeSpan;
  
  double age = 0.0;
  bool isDead = false;
  double opacity = 1.0;

  _Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.radius,
    required this.lifeSpan,
  });

  void update(double dt) {
    age += dt;
    if (age >= lifeSpan) {
      isDead = true;
      opacity = 0.0;
    } else {
      position.add(velocity * dt);
      velocity.multiply(Vector2.all(0.92));
      opacity = 1.0 - (age / lifeSpan);
    }
  }
}
