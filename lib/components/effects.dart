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
    ..color = const Color(0xFFFF2D55).withValues(alpha: 0.3)
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
        ..color = const Color(0xFFFF2D55).withValues(alpha: 0.5)
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

  void applyCameraShift(Vector2 delta) {
    position.add(delta);
    for (final particle in _particles) {
      particle.position.add(delta);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (final p in _particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity.clamp(0.0, 1.0));

      if (_random.nextDouble() > 0.5) {
        final glowPaint = Paint()
          ..color = p.color.withValues(alpha: p.opacity * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(
          Offset(p.position.x, p.position.y),
          p.radius + 3,
          glowPaint,
        );
      }

      canvas.drawCircle(Offset(p.position.x, p.position.y), p.radius, paint);
    }
  }
}

class ExperienceShardEmitter extends Component
    with HasGameReference<QuickDrawGame> {
  final List<Vector2> origins;
  final Vector2 burstDirection;
  final List<Vector2> _positions = [];
  final List<Vector2> _previousPositions = [];
  final List<double> _offsetSeeds = [];
  final List<Vector2> _burstVectors = [];
  final Paint _paint = Paint()..style = PaintingStyle.fill;
  final Paint _trailPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round;
  double _timer = 0.0;
  bool _completed = false;

  static const double duration = 0.9;
  static const double _burstPhase = 0.28;

  ExperienceShardEmitter({
    required this.origins,
    required this.burstDirection,
  }) {
    final random = Random();
    for (var i = 0; i < origins.length; i++) {
      _positions.add(origins[i].clone());
      _previousPositions.add(origins[i].clone());
      _offsetSeeds.add(i * 1.73);
      final randomAngle = random.nextDouble() * pi;
      final randomDistance = 152.0 + random.nextDouble() * 72.0;
      _burstVectors.add(
        Vector2(cos(randomAngle), sin(randomAngle)) * randomDistance,
      );
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_completed) {
      return;
    }

    _timer += dt;
    final progress = (_timer / duration).clamp(0.0, 1.0);
    final eased = pow(progress, 2.8).toDouble();
    final target = game.player.position.clone();

    for (var i = 0; i < _positions.length; i++) {
      _previousPositions[i] = _positions[i].clone();
      final origin = origins[i];
      final burstEnd = origin + _burstVectors[i];
      final burstProgress = (progress / _burstPhase).clamp(0.0, 1.0);
      final burstEase = 1.0 - pow(1.0 - burstProgress, 3).toDouble();
      final followProgress = ((progress - _burstPhase) / (1.0 - _burstPhase))
          .clamp(0.0, 1.0);
      final followEase = pow(followProgress, 2.4).toDouble();
      final swirl = Vector2(
        cos(progress * pi * 4 + _offsetSeeds[i]) * 26.0 * (1.0 - progress),
        sin(progress * pi * 3 + _offsetSeeds[i]) * 18.0 * (1.0 - progress),
      );
      final outwardPosition = origin + _burstVectors[i] * burstEase;
      final chaseStart = burstProgress < 1.0 ? outwardPosition : burstEnd;
      final arc = Vector2(0, -36.0 * sin(followProgress * pi));
      _positions[i] =
          chaseStart + (target - chaseStart) * eased * followEase + arc + swirl;
    }

    if (progress >= 1.0) {
      _completed = true;
      removeFromParent();
    }
  }

  void applyCameraShift(Vector2 delta) {
    for (final origin in origins) {
      origin.add(delta);
    }
    for (final position in _positions) {
      position.add(delta);
    }
    for (final previousPosition in _previousPositions) {
      previousPosition.add(delta);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final progress = (_timer / duration).clamp(0.0, 1.0);
    final opacity = (1.0 - progress * 0.25).clamp(0.0, 1.0);
    final color = const Color(0xFFA29BFE).withValues(alpha: opacity);
    _paint.color = color;
    _trailPaint.color = const Color(
      0xFFA29BFE,
    ).withValues(alpha: opacity * 0.45);
    for (var i = 0; i < _positions.length; i++) {
      final position = _positions[i];
      final previousPosition = _previousPositions[i];
      final center = Offset(position.x, position.y);
      final trailDelta = previousPosition - position;
      final trailLength = trailDelta.length;
      final trailEnd = trailLength > 0.1
          ? position + trailDelta.normalized() * min(34.0, trailLength * 3.2)
          : previousPosition;
      canvas.drawLine(center, Offset(trailEnd.x, trailEnd.y), _trailPaint);
      final path = Path()
        ..moveTo(center.dx, center.dy - 8)
        ..lineTo(center.dx + 8, center.dy)
        ..lineTo(center.dx, center.dy + 8)
        ..lineTo(center.dx - 8, center.dy)
        ..close();
      canvas.drawPath(path, _paint);
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
