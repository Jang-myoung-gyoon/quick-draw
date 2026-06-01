part of 'quick_draw_game.dart';

extension QuickDrawGameSpawning on QuickDrawGame {
  void spawnInitialObjects() {
    for (int i = 0; i < targetFloatingObjectCount; i++) {
      final double xPos = 40.0 + random.nextDouble() * (size.x - 80.0);
      final double yPos = randomInRange(QuickDrawGame._spawnInset, maxSpawnY);
      spawnSingleObject(xPos, yPos);
    }
  }

  void maintainFloatingObjectCount() {
    if (!isPlaying) return;
    if (!lastCameraShiftAllowsReplacementSpawn()) return;

    final visibleObjects = children
        .whereType<FloatingObject>()
        .where(isFloatingObjectVisible)
        .toList();
    final missing = missingVisibleFloatingObjectCount(visibleObjects);
    if (missing <= 0) {
      _replacementSpawnScrollPixels = min(
        _replacementSpawnScrollPixels,
        replacementSpawnPixelsPerObject,
      );
      return;
    }

    if (_replacementSpawnScrollPixels < replacementSpawnPixelsPerObject) return;

    final spawned = spawnReplacementObject(visibleObjects);
    visibleObjects.add(spawned);
    _replacementSpawnScrollPixels -= replacementSpawnPixelsPerObject;
  }

  void addReplacementScrollPixels(double scrolledPixels) {
    if (scrolledPixels <= 0) {
      return;
    }
    if (!lastCameraShiftAllowsReplacementSpawn()) {
      return;
    }
    _replacementSpawnScrollPixels = min(
      replacementSpawnPixelsPerObject * 2,
      _replacementSpawnScrollPixels + scrolledPixels,
    );
  }

  bool lastCameraShiftAllowsReplacementSpawn() {
    final verticalScroll = _lastCameraShift.y.abs() >= _lastCameraShift.x.abs();
    return !verticalScroll || _lastCameraShift.y >= 0;
  }

  bool isFloatingObjectVisible(FloatingObject object) {
    final halfWidth = object.size.x / 2;
    final halfHeight = object.size.y / 2;
    return object.position.x + halfWidth >= 0 &&
        object.position.x - halfWidth <= size.x &&
        object.position.y + halfHeight >= 0 &&
        object.position.y - halfHeight <= size.y;
  }

  int visibleFloatingObjectCount(Iterable<FloatingObject> objects) =>
      objects.where(isFloatingObjectVisible).length;

  int missingVisibleFloatingObjectCount(Iterable<FloatingObject> objects) =>
      max(0, targetFloatingObjectCount - visibleFloatingObjectCount(objects));

  FloatingObject spawnReplacementObject(List<FloatingObject> existingObjects) {
    final position = replacementBoundarySpawnPosition(
      existingObjects: existingObjects,
      cameraShift: _lastCameraShift,
    );

    return spawnSingleObject(position.x, position.y);
  }

  Vector2 replacementBoundarySpawnPosition({
    required Iterable<FloatingObject> existingObjects,
    required Vector2 cameraShift,
  }) {
    final horizontalScroll = cameraShift.x.abs() > cameraShift.y.abs();
    final edgeBand = min(
      QuickDrawGame._replacementSpawnEdgeBand,
      min(size.x, size.y) * 0.24,
    );

    Vector2 sampleCandidate() {
      if (horizontalScroll) {
        final enteringFromLeft = cameraShift.x > 0;
        final x = enteringFromLeft
            ? randomInRange(
                QuickDrawGame._spawnInset,
                QuickDrawGame._spawnInset + edgeBand,
              )
            : randomInRange(
                size.x - QuickDrawGame._spawnInset - edgeBand,
                size.x - QuickDrawGame._spawnInset,
              );
        return Vector2(x, randomInRange(QuickDrawGame._spawnInset, maxSpawnY));
      }

      final enteringFromTop = cameraShift.y >= 0;
      final y = enteringFromTop
          ? randomInRange(
              QuickDrawGame._spawnInset,
              QuickDrawGame._spawnInset + edgeBand,
            )
          : randomInRange(
              max(QuickDrawGame._spawnInset, maxSpawnY - edgeBand),
              maxSpawnY,
            );
      return Vector2(
        randomInRange(
          QuickDrawGame._spawnInset,
          size.x - QuickDrawGame._spawnInset,
        ),
        y,
      );
    }

    var candidate = sampleCandidate();
    final minimumDistance = 90.0 + random.nextDouble() * 150.0;
    for (int attempt = 0; attempt < 12; attempt++) {
      final tooCloseToPlayer = player.isMounted
          ? (candidate - player.position).length < minimumDistance
          : false;
      final tooCloseToObject = existingObjects.any(
        (obj) => (candidate - obj.position).length < minimumDistance,
      );
      if (!tooCloseToPlayer && !tooCloseToObject) {
        return candidate;
      }
      candidate = sampleCandidate();
    }

    return candidate;
  }

  double randomInRange(double minValue, double maxValue) {
    if (maxValue <= minValue) {
      return (minValue + maxValue) / 2;
    }
    return minValue + random.nextDouble() * (maxValue - minValue);
  }

  @visibleForTesting
  FloatingObject spawnFloatingObjectForTest(double x, double y) =>
      spawnSingleObject(x, y);

  FloatingObject spawnSingleObject(double x, double y) {
    if (stageLevel == 1) {
      final target = SlashTarget(durability: 1)..position = Vector2(x, y);
      add(target);
      recordNonBonusSpawn();
      updateChainHighlighting();
      return target;
    }

    final roll = random.nextDouble();
    if (shouldSpawnBonusObject()) {
      final bonus = BonusTarget()..position = Vector2(x, y);
      add(bonus);
      _spawnsSinceLastBonus = 0;
      updateChainHighlighting();
      return bonus;
    }

    final laserChance = laserTargetSpawnChance;
    if (stageLevel >= 2 && roll < laserChance) {
      final target = LaserTarget(
        maxStageDurability: laserTargetStageDurabilityBase(stageLevel),
      )..position = Vector2(x, y);
      add(target);
      recordNonBonusSpawn();
      updateChainHighlighting();
      return target;
    }

    final obstacleChance = obstacleSpawnChanceForStage(stageLevel);
    if (roll < laserChance + obstacleChance) {
      final obstacle =
          (random.nextDouble() < longObstacleChance
                ? LongObstacleTarget()
                : ObstacleTarget())
            ..position = Vector2(x, y);
      add(obstacle);
      recordNonBonusSpawn();
      updateChainHighlighting();
      return obstacle;
    } else {
      final target = SlashTarget(
        durability: 1 + random.nextInt(maxTargetDurabilityForStage(stageLevel)),
      )..position = Vector2(x, y);
      add(target);
      recordNonBonusSpawn();
      updateChainHighlighting();
      return target;
    }
  }

  bool shouldSpawnBonusObject() {
    return stageLevel >= 2 && _spawnsSinceLastBonus >= bonusSpawnInterval - 1;
  }

  void recordNonBonusSpawn() {
    _spawnsSinceLastBonus++;
  }

  Offset? laserTargetIndicatorOffsetForTest(LaserTarget target) {
    return laserTargetIndicatorOffset(target);
  }

  Offset? laserTargetIndicatorOffset(LaserTarget target) {
    if (size.x <= 0 || size.y <= 0 || isFloatingObjectVisible(target)) {
      return null;
    }
    const inset = 38.0;
    return Offset(
      target.position.x.clamp(inset, size.x - inset).toDouble(),
      target.position.y.clamp(inset, size.y - inset).toDouble(),
    );
  }

  void renderLaserTargetIndicators(Canvas canvas) {
    for (final target in children.whereType<LaserTarget>()) {
      final indicator = laserTargetIndicatorOffset(target);
      if (indicator == null) {
        continue;
      }
      final targetOffset = Offset(target.position.x, target.position.y);
      final angle = atan2(
        targetOffset.dy - indicator.dy,
        targetOffset.dx - indicator.dx,
      );
      drawLaserTargetIndicator(canvas, indicator, angle);
    }
  }

  void drawLaserTargetIndicator(Canvas canvas, Offset center, double angle) {
    final pulse = (sin(_laserIndicatorTimer * 8.0) + 1.0) / 2.0;
    final paint = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.82 + pulse * 0.18)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.22 + pulse * 0.18)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final arrow = Path()
      ..moveTo(22, 0)
      ..lineTo(-14, -16)
      ..lineTo(-8, 0)
      ..lineTo(-14, 16)
      ..close();
    canvas.drawPath(arrow, glowPaint);
    canvas.drawPath(arrow, paint);
    canvas.drawPath(arrow, borderPaint);
    canvas.restore();
  }

  @visibleForTesting
  double replacementSpawnScrollPixelsForTest() => _replacementSpawnScrollPixels;

  @visibleForTesting
  void addReplacementScrollPixelsForTest(double scrolledPixels) {
    addReplacementScrollPixels(scrolledPixels);
  }

  @visibleForTesting
  void setReplacementCameraShiftForTest(Vector2 cameraShift) {
    _lastCameraShift = cameraShift.clone();
  }

  @visibleForTesting
  void maintainFloatingObjectCountForTest() {
    maintainFloatingObjectCount();
  }

  @visibleForTesting
  void processReplacementSpawnAfterScrollForTest(double scrolledPixels) {
    addReplacementScrollPixels(scrolledPixels);
    maintainFloatingObjectCount();
  }

  void resolveFloatingObjectRepulsion() {
    final objects = children.whereType<FloatingObject>().toList();
    if (objects.length < 2) return;

    for (int i = 0; i < objects.length; i++) {
      for (int j = i + 1; j < objects.length; j++) {
        final objA = objects[i];
        final objB = objects[j];

        final posA = objA.position;
        final posB = objB.position;

        final diff = posA - posB;
        final dist = diff.length;

        // Radii based on half of the width/height
        final rA = objA.size.x / 2;
        final rB = objB.size.x / 2;

        final minDistance =
            (rA + rB) * 0.70; // 30% overlap allowed (distance >= 70%)

        if (dist < minDistance) {
          final dir = dist > 0 ? diff / dist : Vector2(0, -1);
          final overlap = minDistance - dist;

          // Push them apart (half of the overlap each)
          final push = dir * (overlap * 0.5);
          posA.add(push);
          posB.sub(push);

          // Keep them within horizontal screen boundaries
          const inset = QuickDrawGame._spawnInset;
          posA.x = posA.x.clamp(inset, size.x - inset);
          posB.x = posB.x.clamp(inset, size.x - inset);
        }
      }
    }
  }
}
