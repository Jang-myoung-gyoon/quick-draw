import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/quick_draw_game.dart';

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

  @visibleForTesting
  List<Vector2> get shardPositionsForTest =>
      _positions.map((position) => position.clone()).toList(growable: false);

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
    if (game.isGameplayPausedForUi) {
      return;
    }

    _timer += dt;
    final progress = (_timer / duration).clamp(0.0, 1.0);
    final target = game.player.position.clone();

    for (var i = 0; i < _positions.length; i++) {
      _previousPositions[i] = _positions[i].clone();
      final origin = origins[i];
      final burstEnd = origin + _burstVectors[i];
      final burstProgress = (progress / _burstPhase).clamp(0.0, 1.0);
      final burstEase = 1.0 - pow(1.0 - burstProgress, 3).toDouble();
      final followProgress = ((progress - _burstPhase) / (1.0 - _burstPhase))
          .clamp(0.0, 1.0);
      final swirl = Vector2(
        cos(progress * pi * 4 + _offsetSeeds[i]) * 26.0 * (1.0 - progress),
        sin(progress * pi * 3 + _offsetSeeds[i]) * 18.0 * (1.0 - progress),
      );
      final outwardPosition = origin + _burstVectors[i] * burstEase;
      final arc = Vector2(0, -36.0 * sin(followProgress * pi));
      if (progress <= _burstPhase) {
        _positions[i] = outwardPosition;
      } else {
        final chaseEase = pow(followProgress, 1.35).toDouble();
        _positions[i] =
            burstEnd + (target - burstEnd) * chaseEase + arc + swirl;
      }
    }

    if (progress >= 1.0) {
      _completed = true;
      game.playSound(GameSound.experienceShardAbsorb);
      removeFromParent();
    }
  }

  void applyCameraShift(Vector2 delta) {
    if (game.isGameplayPausedForUi) {
      return;
    }
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

class CriticalTextEffect extends Component {
  Vector2 position;
  double _timer = 0.0;

  static const double duration = 0.8;

  CriticalTextEffect({required this.position});

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    position.y -= 42.0 * dt;
    if (_timer >= duration) {
      removeFromParent();
    }
  }

  void applyCameraShift(Vector2 delta) {
    position.add(delta);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final progress = (_timer / duration).clamp(0.0, 1.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final scale = 1.0 + sin(progress * pi) * 0.18;
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'CRITICAL!',
        style: TextStyle(
          color: const Color(0xFFFF1744).withValues(alpha: opacity),
          fontSize: 28 * scale,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: opacity * 0.8),
              blurRadius: 6,
            ),
            Shadow(
              color: const Color(0xFFFF1744).withValues(alpha: opacity * 0.6),
              blurRadius: 14,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(position.x - textPainter.width / 2, position.y - 44),
    );
  }
}

class LaserBeamEffect extends Component {
  Vector2 start;
  Vector2 end;
  double _timer = 0.0;

  static const double duration = 0.45;

  LaserBeamEffect({required this.start, required this.end});

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    if (_timer >= duration) {
      removeFromParent();
    }
  }

  void applyCameraShift(Vector2 delta) {
    start.add(delta);
    end.add(delta);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final progress = (_timer / duration).clamp(0.0, 1.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final pulse = sin(progress * pi);
    final outerPaint = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: opacity * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18.0 + pulse * 8.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 + pulse * 3.0
      ..strokeCap = StrokeCap.round;
    final redPaint = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0 + pulse * 4.0
      ..strokeCap = StrokeCap.round;

    final startOffset = Offset(start.x, start.y);
    final endOffset = Offset(end.x, end.y);
    canvas.drawLine(startOffset, endOffset, outerPaint);
    canvas.drawLine(startOffset, endOffset, redPaint);
    canvas.drawLine(startOffset, endOffset, corePaint);

    final impactPaint = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 + pulse * 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(endOffset, 18.0 + pulse * 28.0, impactPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'LASER HIT!',
        style: TextStyle(
          color: const Color(0xFFFF1744).withValues(alpha: opacity),
          fontSize: 22,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: opacity * 0.9),
              blurRadius: 5,
            ),
            Shadow(
              color: const Color(0xFFFF1744).withValues(alpha: opacity * 0.7),
              blurRadius: 12,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(end.x - textPainter.width / 2, end.y - 62),
    );
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
