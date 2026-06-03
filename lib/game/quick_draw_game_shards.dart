part of 'quick_draw_game.dart';

extension QuickDrawGameShards on QuickDrawGame {
  void triggerTargetSliced(Vector2 hitPoint, {SlashTarget? target}) {
    playSound(
      target is LaserTarget ? GameSound.laserAttack : GameSound.targetSlice,
    );
    score += 100 + (combo * 10);
    bestScore = max(bestScore, score);
    recordAchievementProgress(showToasts: true);
    combo++;
    shakeIntensity = min(shakeIntensity + 10.0, 25.0);
    if (target != null) {
      final experienceReward = experienceRewardForTarget(target);
      _pendingExperienceHits += experienceReward;
      onTutorialTargetSliced();
      spawnExperienceShards(hitPoint, experienceReward);
      if (target is LaserTarget) {
        spawnEnergyShards(hitPoint, target.durability);
      }
    }
  }

  SlashDamageRoll rollSlashDamage({double? roll}) {
    final isCritical =
        criticalStrikeChance > 0 &&
        (roll ?? random.nextDouble()) < criticalStrikeChance;
    return SlashDamageRoll(
      damage: playerAttackPower * (isCritical ? 2 : 1),
      isCritical: isCritical,
    );
  }

  void triggerCriticalHit(Vector2 hitPoint) {
    add(CriticalTextEffect(position: hitPoint.clone()));
  }

  void spawnExperienceShards(Vector2 origin, int durability) {
    add(
      ExperienceShardEmitter(
        origins: experienceShardOrigins(origin, durability),
        burstDirection: -player.experienceShardBurstDirection,
      ),
    );
  }

  List<Vector2> experienceShardOrigins(Vector2 origin, int durability) {
    final origins = <Vector2>[];
    final shardCount = min(8, max(2, durability + 1));
    for (var i = 0; i < shardCount; i++) {
      final angle = (i / shardCount) * pi * 2;
      origins.add(origin + Vector2(cos(angle), sin(angle)) * 14.0);
    }
    return origins;
  }

  void spawnEnergyShards(Vector2 origin, int durability) {
    final shardCount = min(5, max(2, (durability / 2).ceil()));
    for (var i = 0; i < shardCount; i++) {
      final angle = -pi / 2 + (i - (shardCount - 1) / 2) * 0.72;
      final speed = 86.0 + random.nextDouble() * 62.0;
      add(
        EnergyShard(
          position: origin + Vector2(cos(angle), sin(angle)) * 18.0,
          velocity: Vector2(cos(angle), sin(angle)) * speed,
        ),
      );
    }
  }

  void triggerEnergyShardCollected(Vector2 hitPoint) {
    playSound(GameSound.energyShardAbsorb);
    health = min(maxHealth, health + EnergyShard.restoreAmount);
    spawnSliceParticles(hitPoint, const Color(0xFFFFD166));
  }

  void spawnSliceParticles(Vector2 position, Color color) {
    add(SliceParticleEmitter(position: position, color: color));
  }

  bool triggerObstacleHit(Vector2 hitPos) {
    resetChain();
    playSound(GameSound.obstacleHit);

    if (shieldCharges > 0) {
      shieldCharges--;
      shakeIntensity = 14.0;
      spawnSliceParticles(hitPos, const Color(0xFFEAB308));
      return true;
    }

    // Flat 30% health deduction on hit
    health -= 0.30;
    shakeIntensity = 25.0; // Strong screen shake

    spawnSliceParticles(hitPos, const Color(0xFFFF5500)); // Orange sparks

    if (health <= 0) {
      health = 0.0;
      beginDelayedGameOver();
    }
    return false;
  }

  bool triggerLaserTargetMissed(Vector2 laserOrigin) {
    if (player.isResolvingAction) {
      _pendingLaserAttackOrigins.add(laserOrigin.clone());
      return false;
    }
    return applyLaserAttack(laserOrigin);
  }

  void resolvePendingLaserAttacks() {
    if (_pendingLaserAttackOrigins.isEmpty) {
      return;
    }
    final origins = List<Vector2>.from(_pendingLaserAttackOrigins);
    _pendingLaserAttackOrigins.clear();
    for (final origin in origins) {
      applyLaserAttack(origin);
    }
  }

  bool applyLaserAttack(Vector2 laserOrigin) {
    playSound(GameSound.laserAttack);
    final targetPosition = player.isMounted
        ? player.position.clone()
        : laserOrigin;
    add(LaserBeamEffect(start: laserOrigin.clone(), end: targetPosition));
    return triggerObstacleHit(targetPosition);
  }

  void rechargeShieldForSlash() {
    if (shieldUnlocked) {
      shieldCharges = 1;
    }
  }

  void activateUltimate() {
    if (player.isPerformingUltimate) {
      return;
    }
    health = maxHealth;
    shakeIntensity = 25.0;
    currentChainPoints.clear();
    removePathLine();
    player.startUltimateSequence();
  }

  void executeUltimateCut() {
    final objects = children.whereType<FloatingObject>().toList();
    for (final object in objects) {
      final hitPoint = object.position.clone();
      if (object is SlashTarget) {
        object.slice(hitPoint, -pi / 2);
        triggerTargetSliced(hitPoint, target: object);
      } else {
        spawnSliceParticles(hitPoint, const Color(0xFF22C55E));
        object.removeFromParent();
      }
    }
    spawnVerticalUltimateSlash();
  }

  void spawnVerticalUltimateSlash() {
    add(
      UltimateSlashEffect(
        bottomCenter: Vector2(player.position.x, player.position.y + 80.0),
      ),
    );
  }

  void addLightfootDistance(double distance) {
    if (!lightfootGaugeUnlocked || distance <= 0) {
      return;
    }
    lightfootGauge += distance / QuickDrawGame.lightfootGaugeDistance;
    if (lightfootGauge >= 1.0) {
      lightfootGauge = 0.0;
      activateUltimate();
    }
  }

  void triggerBonusCollected(Vector2 hitPoint) {
    playSound(GameSound.bonusCollect);
    onTutorialBonusCollected();
    activateUltimate();
  }

  @visibleForTesting
  int get pendingLaserAttackCountForTest => _pendingLaserAttackOrigins.length;
}
