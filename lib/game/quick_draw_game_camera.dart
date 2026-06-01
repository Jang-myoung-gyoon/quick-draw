part of 'quick_draw_game.dart';

extension QuickDrawGameCamera on QuickDrawGame {
  void shiftWorldForCamera(Vector2 delta) {
    if (delta.length2 > 0) {
      _lastCameraShift = delta.clone();
      addReplacementScrollPixels(delta.length);
    }
    addLightfootDistance(delta.length);
    if (delta.y >= 0) {
      rechargeEnergyFromScroll(delta.y);
    } else {
      drainEnergyFromScroll(-delta.y);
    }

    // Shift all floating objects (targets + obstacles)
    for (final obj in children.whereType<FloatingObject>()) {
      obj.applyCameraShift(delta);
    }
    // Shift sliced halves too
    for (final obj in children.whereType<SlicedHalfComponent>()) {
      obj.applyCameraShift(delta);
    }
    for (final obj in children.whereType<SliceParticleEmitter>()) {
      obj.applyCameraShift(delta);
    }
    for (final obj in children.whereType<ExperienceShardEmitter>()) {
      obj.applyCameraShift(delta);
    }
    for (final obj in children.whereType<EnergyShard>()) {
      obj.applyCameraShift(delta);
    }
    for (final obj in children.whereType<CriticalTextEffect>()) {
      obj.applyCameraShift(delta);
    }
    for (final obj in children.whereType<LaserBeamEffect>()) {
      obj.applyCameraShift(delta);
    }

    // Background scroll boost
    final bg = background;
    if (bg != null) {
      bg.applyScrollBoost(delta);
    }

    maintainFloatingObjectCount();
  }

  void rechargeEnergyFromScroll(
    double scrolledPixels, {
    double? referenceHeight,
  }) {
    if (scrolledPixels <= 0) {
      return;
    }
    health = min(
      maxHealth,
      health +
          energyRechargeForScroll(
            scrolledPixels,
            referenceHeight ?? player.baseY,
          ),
    );
  }

  void drainEnergyFromScroll(double scrolledPixels, {double? referenceHeight}) {
    if (scrolledPixels <= 0) {
      return;
    }
    health = max(
      QuickDrawGame.hiddenEnergyReserve,
      health -
          energyRechargeForScroll(
            scrolledPixels,
            referenceHeight ?? player.baseY,
          ),
    );
  }

  double energyRechargeForScroll(
    double scrolledPixels,
    double referenceHeight,
  ) {
    if (scrolledPixels <= 0 || referenceHeight <= 0) {
      return 0.0;
    }
    const baseGain = 0.0175;
    const maxScrollGain = 0.0875;
    final normalizedScroll = (scrolledPixels / referenceHeight).clamp(0.0, 1.0);
    return (baseGain + maxScrollGain * normalizedScroll) *
        scrollEnergyGainMultiplier;
  }

  void syncBackgroundMotionSpeed() {
    final bg = background;
    if (bg == null) {
      return;
    }
    bg.currentSpeed = player.isDashing ? bg.dashSpeed : bg.normalSpeed;
  }

  void onPlayerClimbed(double climbAmount) {
    totalAltitude += climbAmount;
  }
}
