part of 'quick_draw_game.dart';

extension QuickDrawGameInput on QuickDrawGame {
  void handleTapDown(TapDownEvent event) {
    if (!isPlaying) return;
    if (isGameOverPending) return;

    if (!player.isDashing) {
      addToChain(event.localPosition);
    }
  }

  // Chain Management
  void addToChain(Vector2 tapPos) {
    if (isGameOverPending) return;
    if (currentChainPoints.length >= maxChainLength || player.isDashing) return;

    currentChainPoints.add(tapPos);
    if (currentChainPoints.length == 1) {
      player.lockChainDirection(tapPos);
      chainTimer = 0.0;
    }

    // Redraw preview line
    removePathLine();
    activePathLine = SlashPathLine(waypoints: currentChainPoints);
    add(activePathLine!);

    // Dynamically highlight targets crossed by this path
    updateChainHighlighting();

    // Start dash immediately if chain limit reached
    if (currentChainPoints.length == maxChainLength) {
      executeChainSlash();
    }
  }

  void updateChainHighlighting() {
    // Collect all active targets
    final targets = children.whereType<SlashTarget>();

    // Reset all targeted states first
    for (final target in targets) {
      target.isTargeted = false;
    }

    if (currentChainPoints.isEmpty) return;

    // Build the segments list (starting from the player position)
    final List<Vector2> pathPoints = [
      player.position.clone(),
      ...currentChainPoints,
    ];

    for (int i = 0; i < pathPoints.length - 1; i++) {
      final Vector2 segmentStart = pathPoints[i];
      final Vector2 segmentEnd = pathPoints[i + 1];
      final Vector2 segmentVec = segmentEnd - segmentStart;
      final double segmentLenSq = segmentVec.length2;

      if (segmentLenSq == 0) continue;

      for (final target in targets) {
        final Vector2 targetVec = target.position - segmentStart;
        final double dot = targetVec.dot(segmentVec);
        double t = dot / segmentLenSq;
        t = t.clamp(0.0, 1.0);

        final Vector2 closestPoint = segmentStart + (segmentVec * t);
        final double distance = (target.position - closestPoint).length;

        if (distance <= effectiveTargetHitRadius(target)) {
          target.isTargeted = true;
        }
      }
    }
  }

  void executeChainSlash() {
    if (currentChainPoints.isEmpty) return;

    playSound(GameSound.slashSwing);
    player.startChainDash(currentChainPoints);
    currentChainPoints.clear();
    removePathLine();
  }

  double effectiveTargetHitRadius(SlashTarget target) =>
      target.pathHitRadius + shadowCloneLevel * 32.0;

  void resetChain() {
    currentChainPoints.clear();
    removePathLine();
    updateChainHighlighting();
    combo = 0;
  }

  void removePathLine() {
    if (activePathLine != null) {
      activePathLine!.removeFromParent();
      activePathLine = null;
    }
  }

  // Game Lifecycle Actions
  void startGame() {
    score = 0;
    combo = 0;
    health = maxHealth;
    experience = 0.0;
    characterLevel = 1;
    stageLevel = 1;
    levelUpAnnouncementLevel = 1;
    levelUpAnnouncementTitle = 'CHARACTER LEVEL UP';
    levelUpAnnouncementTimer = 0.0;
    inputTurnsThisStage = 0;
    playerAttackPower = 1;
    criticalStrikeLevel = 0;
    passiveDrainRate = 0.06435;
    scrollEnergyGainMultiplier = 1.0;
    luckLevel = 0;
    rareUpgradeCount = 0;
    shadowCloneLevel = 0;
    shieldUnlocked = false;
    shieldCharges = 0;
    lightfootGaugeUnlocked = false;
    lightfootGauge = 0.0;
    chainStrikeUnlocked = false;
    maxChainTime = 1.5;
    maxChainLength = 1;
    inputDrainMultiplier = 1.0;
    currentUpgradeChoices = const [];
    upgradeInputLockTimer = 0.0;
    acquiredRareUpgrades.clear();
    _pendingExperienceHits = 0;
    _pendingLaserAttackOrigins.clear();
    _spawnsSinceLastBonus = 0;
    _gameOverDelayTimer = 0.0;
    totalAltitude = 0.0;

    clearGameplayComponents();
    removeOverlayIfRegistered('StartScreen');
    removeOverlayIfRegistered('GameOverScreen');
    removeOverlayIfRegistered('UpgradeScreen');
    removeOverlayIfRegistered('SettingsScreen');
    addOverlayIfRegistered('HUD');

    isPlaying = true;
    isGameOver = false;
    isChoosingUpgrade = false;

    stopBackgroundMusic();
    startBackgroundMusic();

    player.resetToBasePosition();
    background?.resetForNewRun();
    spawnInitialObjects();
  }

  void beginDelayedGameOver() {
    if (isGameOver || isGameOverPending) return;
    resetChain();
    player.startGameOverDelayAnimation();
    _gameOverDelayTimer = QuickDrawGame.gameOverDelayDuration;
  }

  void gameOver() {
    if (isGameOver) return;
    _gameOverDelayTimer = 0.0;
    isPlaying = false;
    isGameOver = true;

    removeOverlayIfRegistered('HUD');
    removeOverlayIfRegistered('UpgradeScreen');
    addOverlayIfRegistered('GameOverScreen');
    playSound(GameSound.gameOver);
    stopBackgroundMusic();
  }

  bool handleSystemBack() {
    if (overlays.activeOverlays.contains('SettingsScreen')) {
      closeSettings();
      return true;
    }
    if (overlays.activeOverlays.contains('AchievementsScreen')) {
      hideAchievements();
      return true;
    }
    return false;
  }

  void openSettings() {
    playSound(GameSound.uiSelect);
    if (isPlaying && !isGameOver && !paused) {
      pauseEngine();
      _pausedForSettings = true;
    }
    addOverlayIfRegistered('SettingsScreen', priority: 200);
  }

  void closeSettings() {
    playSound(GameSound.uiSelect);
    removeOverlayIfRegistered('SettingsScreen');
    if (_pausedForSettings) {
      _pausedForSettings = false;
      resumeEngine();
    }
  }

  void returnHomeFromSettings() {
    playSound(GameSound.uiConfirm);
    recordAchievementProgress(showToasts: true);
    _pausedForSettings = false;
    if (paused) {
      resumeEngine();
    }
    isPlaying = false;
    isGameOver = false;
    isChoosingUpgrade = false;
    currentChainPoints.clear();
    removePathLine();
    stopBackgroundMusic();
    clearGameplayComponents();

    removeOverlayIfRegistered('SettingsScreen');
    removeOverlayIfRegistered('UpgradeScreen');
    removeOverlayIfRegistered('GameOverScreen');
    removeOverlayIfRegistered('HUD');
    addOverlayIfRegistered('StartScreen');
    startHomeBgm();
  }

  void showAchievements() {
    async_timer.unawaited(showAchievementsImpl());
  }

  Future<void> showAchievementsImpl() async {
    await loadAchievementProgress();
    recordAchievementProgress();
    addOverlayIfRegistered('AchievementsScreen', priority: 120);
  }

  void hideAchievements() {
    overlays.remove('AchievementsScreen');
  }

  void addOverlayIfRegistered(String name, {int priority = 0}) {
    if (overlays.registeredOverlays.contains(name)) {
      overlays.add(name, priority: priority);
    }
  }

  void removeOverlayIfRegistered(String name) {
    if (overlays.registeredOverlays.contains(name)) {
      overlays.remove(name);
    }
  }

  void clearGameplayComponents() {
    final removable = <Component>[
      ...children.whereType<FloatingObject>(),
      ...children.whereType<SlicedHalfComponent>(),
      ...children.whereType<SliceParticleEmitter>(),
      ...children.whereType<ExperienceShardEmitter>(),
      ...children.whereType<EnergyShard>(),
      ...children.whereType<LaserBeamEffect>(),
      ...children.whereType<CriticalTextEffect>(),
    ];
    for (final component in removable) {
      component.removeFromParent();
    }
  }
}
