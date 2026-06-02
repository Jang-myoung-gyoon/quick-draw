part of 'quick_draw_game.dart';

extension QuickDrawGameAchievements on QuickDrawGame {
  bool recordSelectedUpgradeAchievement(UpgradeType type) {
    if (isUpgradeSelected(type)) {
      return selectedUpgradeAchievements.add(type);
    }
    return false;
  }

  bool recordMaxedUpgradeAchievement(UpgradeType type) {
    if (isUpgradeAtMax(type)) {
      return maxedUpgradeAchievements.add(type);
    }
    return false;
  }

  bool isUpgradeSelected(UpgradeType type) {
    return switch (type) {
      UpgradeType.bladePower => playerAttackPower > 1,
      UpgradeType.criticalStrike => criticalStrikeLevel > 0,
      UpgradeType.chainLength => maxChainLength > 1,
      UpgradeType.scrollRecovery => scrollEnergyGainMultiplier > 1.0,
      UpgradeType.energyEfficiency => passiveDrainRate < 0.06435,
      UpgradeType.focusTime => maxChainTime > 1.5,
      UpgradeType.luck => luckLevel > 0,
      UpgradeType.shadowClone => shadowCloneLevel > 0,
      UpgradeType.shield => shieldUnlocked,
      UpgradeType.lightfootGauge => lightfootGaugeUnlocked,
      UpgradeType.chainStrike => chainStrikeUnlocked,
    };
  }

  bool isUpgradeAtMax(UpgradeType type) {
    return switch (type) {
      UpgradeType.bladePower => playerAttackPower >= 15,
      UpgradeType.criticalStrike => criticalStrikeLevel >= 10,
      UpgradeType.chainLength => maxChainLength >= 6,
      UpgradeType.scrollRecovery => scrollEnergyGainMultiplier >= 1.75,
      UpgradeType.energyEfficiency => passiveDrainRate <= 0.026,
      UpgradeType.focusTime => maxChainTime >= 2.3,
      UpgradeType.luck => bonusSpawnInterval <= 200,
      UpgradeType.shadowClone => shadowCloneLevel >= 4,
      UpgradeType.shield => shieldUnlocked,
      UpgradeType.lightfootGauge => lightfootGaugeUnlocked,
      UpgradeType.chainStrike => chainStrikeUnlocked,
    };
  }

  List<Achievement> achievementsForDisplay() {
    recordAchievementProgress();
    return [
      ...upgradeAchievements(),
      ...stageAchievements(),
      ...characterAchievements(),
      ...scoreAchievements(),
    ];
  }

  List<Achievement> visibleAchievementsForDisplay() {
    return QuickDrawGame.visibleAchievementsFrom(
      achievementsForDisplay(),
      acknowledgedAchievementIds: acknowledgedAchievementIds,
    );
  }

  void acknowledgeAchievement(String id) {
    Achievement? achievement;
    for (final item in achievementsForDisplay()) {
      if (item.id == id) {
        achievement = item;
        break;
      }
    }
    if (achievement == null || !achievement.unlocked) {
      return;
    }
    if (acknowledgedAchievementIds.add(id)) {
      achievementRevision.value++;
      persistAchievementProgressIfLoaded();
    }
  }

  void enqueueNewlyUnlockedAchievementToasts() {
    for (final achievement in achievementsForDisplay()) {
      if (!achievement.unlocked) {
        continue;
      }
      if (_announcedAchievementIds.add(achievement.id)) {
        _achievementToastQueue.add(text.achievementUnlocked(achievement.title));
      }
    }
  }

  void updateAchievementToast(double dt) {
    if (achievementToastTimer > 0) {
      achievementToastTimer = max(0.0, achievementToastTimer - dt);
      if (achievementToastTimer > 0) {
        return;
      }
      achievementToastMessage = null;
    }
    if (_achievementToastQueue.isEmpty) {
      return;
    }
    achievementToastMessage = _achievementToastQueue.removeAt(0);
    achievementToastTimer = 3.0;
  }

  List<Achievement> upgradeAchievements() {
    final t = text;
    return UpgradeType.values
        .expand(
          (type) => [
            Achievement(
              id: 'upgrade-${type.name}-selected',
              title: t.selectedAchievementTitle(type),
              description: t.selectedAchievementDescription,
              group: AchievementGroup.upgrade,
              unlocked: selectedUpgradeAchievements.contains(type),
              acknowledged: acknowledgedAchievementIds.contains(
                'upgrade-${type.name}-selected',
              ),
              progress: selectedUpgradeAchievements.contains(type) ? 1.0 : 0.0,
            ),
            Achievement(
              id: 'upgrade-${type.name}-maxed',
              title: t.masteredAchievementTitle(type),
              description: t.masteredAchievementDescription,
              group: AchievementGroup.upgrade,
              unlocked: maxedUpgradeAchievements.contains(type),
              acknowledged: acknowledgedAchievementIds.contains(
                'upgrade-${type.name}-maxed',
              ),
              progress: maxedUpgradeAchievements.contains(type) ? 1.0 : 0.0,
            ),
          ],
        )
        .toList(growable: false);
  }

  List<Achievement> stageAchievements() {
    final t = text;
    const levelTargets = [3, 5, 10, 15, 20];
    return levelTargets
        .map(
          (level) => Achievement(
            id: 'stage-$level',
            title: t.stageAchievementTitle(level),
            description: t.stageAchievementDescription(level),
            group: AchievementGroup.stage,
            unlocked: bestStageLevel >= level,
            acknowledged: acknowledgedAchievementIds.contains('stage-$level'),
            progress: (bestStageLevel / level).clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
  }

  List<Achievement> characterAchievements() {
    final t = text;
    const levelTargets = [3, 5, 10, 15, 20];
    return levelTargets
        .map(
          (level) => Achievement(
            id: 'character-$level',
            title: t.characterAchievementTitle(level),
            description: t.characterAchievementDescription(level),
            group: AchievementGroup.character,
            unlocked: bestCharacterLevel >= level,
            acknowledged: acknowledgedAchievementIds.contains(
              'character-$level',
            ),
            progress: (bestCharacterLevel / level).clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
  }

  List<Achievement> scoreAchievements() {
    final t = text;
    const thresholds = [1000, 3000, 5000, 10000, 20000, 50000];
    return thresholds
        .map(
          (scoreTarget) => Achievement(
            id: 'score-$scoreTarget',
            title: t.scoreAchievementTitle(scoreTarget),
            description: t.scoreAchievementDescription(scoreTarget),
            group: AchievementGroup.score,
            unlocked: bestScore >= scoreTarget,
            acknowledged: acknowledgedAchievementIds.contains(
              'score-$scoreTarget',
            ),
            progress: (bestScore / scoreTarget).clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
  }

  void recordRareUpgrade(UpgradeType type) {
    if (!acquiredRareUpgrades.contains(type)) {
      acquiredRareUpgrades.add(type);
    }
  }

  void recordAchievementProgress({bool showToasts = false}) {
    var changed = false;
    final nextBestScore = max(bestScore, score);
    if (nextBestScore != bestScore) {
      bestScore = nextBestScore;
      changed = true;
    }
    final nextBestStageLevel = max(bestStageLevel, stageLevel);
    if (nextBestStageLevel != bestStageLevel) {
      bestStageLevel = nextBestStageLevel;
      changed = true;
    }
    final nextBestCharacterLevel = max(bestCharacterLevel, characterLevel);
    if (nextBestCharacterLevel != bestCharacterLevel) {
      bestCharacterLevel = nextBestCharacterLevel;
      changed = true;
    }
    for (final type in UpgradeType.values) {
      changed = recordSelectedUpgradeAchievement(type) || changed;
      changed = recordMaxedUpgradeAchievement(type) || changed;
    }
    if (changed) {
      achievementRevision.value++;
      persistAchievementProgressIfLoaded();
    }
    if (showToasts) {
      enqueueNewlyUnlockedAchievementToasts();
    }
  }

  Future<void> loadAchievementProgress() {
    return _achievementProgressLoad ??= loadAchievementProgressImpl();
  }

  Future<void> loadAchievementProgressImpl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bestStageLevel = max(
        bestStageLevel,
        prefs.getInt(QuickDrawGame._achievementBestStageKey) ?? bestStageLevel,
      );
      bestCharacterLevel = max(
        bestCharacterLevel,
        prefs.getInt(QuickDrawGame._achievementBestCharacterKey) ??
            bestCharacterLevel,
      );
      bestScore = max(
        bestScore,
        prefs.getInt(QuickDrawGame._achievementBestScoreKey) ?? bestScore,
      );
      final storedMaxedUpgrades =
          prefs.getStringList(QuickDrawGame._achievementMaxedUpgradesKey) ??
          const <String>[];
      final storedSelectedUpgrades =
          prefs.getStringList(QuickDrawGame._achievementSelectedUpgradesKey) ??
          const <String>[];
      final storedAcknowledgedAchievements =
          prefs.getStringList(QuickDrawGame._achievementAcknowledgedKey) ??
          const <String>[];
      acknowledgedAchievementIds.addAll(storedAcknowledgedAchievements);
      selectedUpgradeAchievements.addAll(
        storedSelectedUpgrades
            .map(upgradeTypeFromName)
            .whereType<UpgradeType>(),
      );
      maxedUpgradeAchievements.addAll(
        storedMaxedUpgrades.map(upgradeTypeFromName).whereType<UpgradeType>(),
      );
      selectedUpgradeAchievements.addAll(maxedUpgradeAchievements);
    } catch (_) {
      // Local persistence should not block the game or tests.
    } finally {
      _achievementProgressLoaded = true;
      achievementRevision.value++;
      recordAchievementProgress();
    }
  }

  UpgradeType? upgradeTypeFromName(String name) {
    for (final type in UpgradeType.values) {
      if (type.name == name) {
        return type;
      }
    }
    return null;
  }

  void persistAchievementProgressIfLoaded() {
    if (!_achievementProgressLoaded) {
      return;
    }
    async_timer.unawaited(saveAchievementProgress());
  }

  @visibleForTesting
  Future<void> saveAchievementProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        QuickDrawGame._achievementBestStageKey,
        bestStageLevel,
      );
      await prefs.setInt(
        QuickDrawGame._achievementBestCharacterKey,
        bestCharacterLevel,
      );
      await prefs.setInt(QuickDrawGame._achievementBestScoreKey, bestScore);
      await prefs.setStringList(
        QuickDrawGame._achievementSelectedUpgradesKey,
        selectedUpgradeAchievements
            .map((type) => type.name)
            .toList(growable: false),
      );
      await prefs.setStringList(
        QuickDrawGame._achievementMaxedUpgradesKey,
        maxedUpgradeAchievements
            .map((type) => type.name)
            .toList(growable: false),
      );
      await prefs.setStringList(
        QuickDrawGame._achievementAcknowledgedKey,
        acknowledgedAchievementIds.toList(growable: false),
      );
    } catch (_) {
      // Local persistence should not block gameplay.
    }
  }
}
