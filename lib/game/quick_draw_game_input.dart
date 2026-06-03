part of 'quick_draw_game.dart';

extension QuickDrawGameInput on QuickDrawGame {
  void handleTapDown(TapDownEvent event) {
    if (!isPlaying) return;
    if (isGameOverPending) return;

    if (!player.isDashing) {
      final tapPosition = guidedTutorialTapPosition(event.localPosition);
      if (tapPosition == null) {
        return;
      }
      addToChain(tapPosition);
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
    onTutorialChainPointAdded();

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
  void startGame({bool forceTutorial = false}) {
    final startTutorial = forceTutorial || shouldAutoStartTutorial;
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
    passiveDrainRate = QuickDrawGame.initialPassiveDrainRate;
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
    inputDrainMultiplier = QuickDrawGame.inputDrainMultiplierForStage(
      stageLevel,
    );
    currentUpgradeChoices = const [];
    upgradeInputLockTimer = 0.0;
    acquiredRareUpgrades.clear();
    _pendingExperienceHits = 0;
    _pendingLaserAttackOrigins.clear();
    _spawnsSinceLastBonus = 0;
    _gameOverDelayTimer = 0.0;
    totalAltitude = 0.0;
    resetTutorialStateForNewRun(tutorial: startTutorial);

    clearGameplayComponents();
    removeOverlayIfRegistered('StartScreen');
    removeOverlayIfRegistered('GameOverScreen');
    removeOverlayIfRegistered('UpgradeScreen');
    removeOverlayIfRegistered('SettingsScreen');
    removeOverlayIfRegistered('CommunityScreen');
    removeOverlayIfRegistered('FriendsScreen');
    addOverlayIfRegistered('HUD');

    isPlaying = true;
    isGameOver = false;
    isChoosingUpgrade = false;

    stopBackgroundMusic();
    startBackgroundMusic();

    player.resetToBasePosition();
    background?.resetForNewRun();
    if (startTutorial) {
      beginTutorialRun();
    } else {
      spawnInitialObjects();
    }
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
    _scoreRecordSave = recordFinalScore();

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
    if (overlays.activeOverlays.contains('RankingScreen')) {
      hideRanking();
      return true;
    }
    if (overlays.activeOverlays.contains('FriendsScreen')) {
      hideFriends();
      return true;
    }
    if (overlays.activeOverlays.contains('CommunityScreen')) {
      hideCommunity();
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
    resetTutorialStateForNewRun(tutorial: false);
    currentChainPoints.clear();
    removePathLine();
    stopBackgroundMusic();
    clearGameplayComponents();

    removeOverlayIfRegistered('SettingsScreen');
    removeOverlayIfRegistered('UpgradeScreen');
    removeOverlayIfRegistered('GameOverScreen');
    removeOverlayIfRegistered('RankingScreen');
    removeOverlayIfRegistered('CommunityScreen');
    removeOverlayIfRegistered('FriendsScreen');
    removeOverlayIfRegistered('HUD');
    addOverlayIfRegistered('StartScreen');
    startHomeBgm();
  }

  void showCommunity() {
    overlays.remove('FriendsScreen');
    addOverlayIfRegistered('CommunityScreen', priority: 140);
  }

  void hideCommunity() {
    overlays.remove('CommunityScreen');
  }

  void showFriends() {
    overlays.remove('CommunityScreen');
    addOverlayIfRegistered('FriendsScreen', priority: 150);
  }

  void hideFriends() {
    overlays.remove('FriendsScreen');
  }

  Future<FriendCommunitySnapshot> loadCommunitySnapshot() {
    return _firebaseSync.loadCommunitySnapshot();
  }

  Future<void> sendFriendRequest(String friendUid) {
    return _firebaseSync.sendFriendRequest(friendUid);
  }

  Future<void> acceptFriendRequest(String requesterUid) {
    return _firebaseSync.acceptFriendRequest(requesterUid);
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

  void showRanking() {
    async_timer.unawaited(showRankingImpl());
  }

  Future<void> showRankingImpl() async {
    await _scoreRecordSave;
    addOverlayIfRegistered('RankingScreen', priority: 130);
  }

  void hideRanking() {
    overlays.remove('RankingScreen');
  }

  Future<FriendRankingSnapshot> loadFriendRankingSnapshot() {
    return _firebaseSync.loadFriendRankingSnapshot();
  }

  String? get currentUserIdForRanking => _firebaseSync.currentUser?.uid;

  Future<String?> buildFriendInviteLink() async {
    await _firebaseSync.initialize();
    final uid = _firebaseSync.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return null;
    }
    return link_share.friendInviteLink(uid);
  }

  String buildPlainAppLink() => link_share.plainAppLink();

  Future<void> recordFinalScore() {
    final progress = currentProgressSnapshot();
    final record = ScoreRecord(
      score: finalScoreForRecord,
      stageLevel: stageLevel,
      characterLevel: characterLevel,
      playedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    return _firebaseSync.recordScore(
      record,
      achievementScore: achievementScoreForRanking(progress),
    );
  }

  int achievementScoreForRanking(GameProgressSnapshot progress) {
    return progress.acknowledgedAchievements.length * 100 +
        progress.selectedUpgrades.length * 100 +
        progress.maxedUpgrades.length * 100 +
        (progress.bestStageLevel - 1).clamp(0, 9999) * 20 +
        (progress.bestCharacterLevel - 1).clamp(0, 9999) * 20;
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
