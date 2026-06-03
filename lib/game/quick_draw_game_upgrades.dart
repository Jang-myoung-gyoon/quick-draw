part of 'quick_draw_game.dart';

extension QuickDrawGameUpgrades on QuickDrawGame {
  void chooseUpgrade(UpgradeOption option) {
    if (upgradeInputLockTimer > 0) {
      return;
    }
    if (!canChooseUpgradeOption(option)) {
      return;
    }
    playSound(GameSound.uiConfirm);
    switch (option.type) {
      case UpgradeType.bladePower:
        playerAttackPower++;
      case UpgradeType.criticalStrike:
        criticalStrikeLevel++;
      case UpgradeType.chainLength:
        maxChainLength++;
      case UpgradeType.scrollRecovery:
        scrollEnergyGainMultiplier += 0.25;
      case UpgradeType.energyEfficiency:
        passiveDrainRate = max(0.02, passiveDrainRate * 0.85);
      case UpgradeType.focusTime:
        maxChainTime += 0.25;
      case UpgradeType.luck:
        luckLevel++;
      case UpgradeType.shadowClone:
        shadowCloneLevel = min(4, shadowCloneLevel + 1);
      case UpgradeType.shield:
        shieldUnlocked = true;
        shieldCharges = 1;
        rareUpgradeCount++;
        recordRareUpgrade(option.type);
      case UpgradeType.lightfootGauge:
        lightfootGaugeUnlocked = true;
        lightfootGauge = 0.0;
        rareUpgradeCount++;
        recordRareUpgrade(option.type);
      case UpgradeType.chainStrike:
        chainStrikeUnlocked = true;
        rareUpgradeCount++;
        recordRareUpgrade(option.type);
    }
    currentUpgradeChoices = const [];
    upgradeInputLockTimer = 0.0;
    isChoosingUpgrade = false;
    removeOverlayIfRegistered('UpgradeScreen');
    recordAchievementProgress(showToasts: true);
    onTutorialUpgradeChosen();
    updateChainHighlighting();
  }

  List<UpgradeOption> recommendedUpgradeChoices() {
    final t = text;
    final options = <UpgradeOption>[
      UpgradeOption(
        type: UpgradeType.bladePower,
        title: t.upgradeTitle(UpgradeType.bladePower),
        description: t.upgradeDescription(UpgradeType.bladePower),
        color: const Color(0xFFFF335F),
        currentValue: '${t.current} $playerAttackPower',
      ),
      UpgradeOption(
        type: UpgradeType.criticalStrike,
        title: t.upgradeTitle(UpgradeType.criticalStrike),
        description: t.upgradeDescription(UpgradeType.criticalStrike),
        color: const Color(0xFFFF1744),
        currentValue:
            '${t.current} ${(criticalStrikeChance * 100).toStringAsFixed(0)}%',
      ),
      if (maxChainLength < 6)
        UpgradeOption(
          type: UpgradeType.chainLength,
          title: t.upgradeTitle(UpgradeType.chainLength),
          description: t.upgradeDescription(UpgradeType.chainLength),
          color: const Color(0xFF00E5FF),
          currentValue: '${t.current} $maxChainLength',
        ),
      if (scrollEnergyGainMultiplier < 1.75)
        UpgradeOption(
          type: UpgradeType.scrollRecovery,
          title: t.upgradeTitle(UpgradeType.scrollRecovery),
          description: t.upgradeDescription(UpgradeType.scrollRecovery),
          color: const Color(0xFF00FFCC),
          currentValue:
              '${t.current} ${(scrollEnergyGainMultiplier * 100).round()}%',
        ),
      if (passiveDrainRate > 0.026)
        UpgradeOption(
          type: UpgradeType.energyEfficiency,
          title: t.upgradeTitle(UpgradeType.energyEfficiency),
          description: t.upgradeDescription(UpgradeType.energyEfficiency),
          color: const Color(0xFFFFB020),
          currentValue:
              '${t.current} ${(passiveDrainRate * 100).toStringAsFixed(1)}',
        ),
      if (maxChainTime < 2.3)
        UpgradeOption(
          type: UpgradeType.focusTime,
          title: t.upgradeTitle(UpgradeType.focusTime),
          description: t.upgradeDescription(UpgradeType.focusTime),
          color: const Color(0xFFA855F7),
          currentValue: '${t.current} ${maxChainTime.toStringAsFixed(2)}s',
        ),
      UpgradeOption(
        type: UpgradeType.luck,
        title: t.upgradeTitle(UpgradeType.luck),
        description: t.upgradeDescription(UpgradeType.luck),
        color: const Color(0xFFFFD166),
        currentValue: '${t.current} 1 / $bonusSpawnInterval',
      ),
      if (shadowCloneLevel < 4)
        UpgradeOption(
          type: UpgradeType.shadowClone,
          title: t.upgradeTitle(UpgradeType.shadowClone),
          description: t.upgradeDescription(UpgradeType.shadowClone),
          color: const Color(0xFF38BDF8),
          currentValue: '${t.current} $shadowCloneLevel / 4',
        ),
    ];

    options.sort((a, b) => _upgradePriority(b).compareTo(_upgradePriority(a)));
    final choices = options.take(3).toList(growable: true);
    final rare = rollRareUpgradeForTest();
    if (rare != null && choices.isNotEmpty) {
      choices[choices.length - 1] = rare;
    }
    return choices.toList(growable: false);
  }

  int _upgradePriority(UpgradeOption option) {
    switch (option.type) {
      case UpgradeType.bladePower:
        return children.whereType<SlashTarget>().any(
              (target) => target.durability > playerAttackPower,
            )
            ? 100
            : 52;
      case UpgradeType.criticalStrike:
        return 68;
      case UpgradeType.scrollRecovery:
        return health < 0.45 ? 95 : 55;
      case UpgradeType.energyEfficiency:
        return health < 0.3 ? 90 : 45;
      case UpgradeType.chainLength:
        return characterLevel >= 3 ? 75 : 60;
      case UpgradeType.focusTime:
        return combo == 0 ? 65 : 40;
      case UpgradeType.luck:
        return 58;
      case UpgradeType.shadowClone:
        return 62 + shadowCloneLevel * 3;
      case UpgradeType.shield:
      case UpgradeType.lightfootGauge:
      case UpgradeType.chainStrike:
        return 80;
    }
  }

  void offerUpgradeChoices() {
    if (isChoosingUpgrade) return;
    isChoosingUpgrade = true;
    currentChainPoints.clear();
    removePathLine();
    updateChainHighlighting();
    resetChain();

    currentUpgradeChoices = _tutorialPhase == TutorialPhase.upgradeChoice
        ? tutorialUpgradeChoices()
        : recommendedUpgradeChoices();
    upgradeInputLockTimer = QuickDrawGame.upgradeInputLockDuration;
    addOverlayIfRegistered('UpgradeScreen', priority: 100);
  }

  void advanceCharacterLevel() {
    characterLevel++;
    bestCharacterLevel = max(bestCharacterLevel, characterLevel);
    recordAchievementProgress(showToasts: true);
    levelUpAnnouncementLevel = characterLevel;
    levelUpAnnouncementTitle = 'CHARACTER LEVEL UP';
    levelUpAnnouncementTimer = 2.4;
    experience = 0.0;
    offerUpgradeChoices();
  }

  void advanceStageLevel() {
    stageLevel++;
    bestStageLevel = max(bestStageLevel, stageLevel);
    recordAchievementProgress(showToasts: true);
    inputTurnsThisStage = 0;
    levelUpAnnouncementLevel = stageLevel;
    levelUpAnnouncementTitle = 'STAGE LEVEL UP';
    levelUpAnnouncementTimer = 2.4;
    applyStageDifficulty();
  }

  void applyStageDifficulty() {
    inputDrainMultiplier = QuickDrawGame.inputDrainMultiplierForStage(
      stageLevel,
    );
  }

  void gainExperienceForRemovedHits(int durability) {
    if (!isPlaying || isChoosingUpgrade) {
      return;
    }
    experience += durability / experienceRequiredForCharacterLevel;
    if (experience >= maxExperience) {
      advanceCharacterLevel();
    }
  }

  void collectPendingTargetExperience({bool animate = true}) {
    if (_pendingExperienceHits <= 0) {
      return;
    }

    beforeCollectTutorialExperience();
    final totalRequiredHits = _pendingExperienceHits;
    _pendingExperienceHits = 0;
    gainExperienceForRemovedHits(totalRequiredHits);
  }

  void onInputTurnCompleted() {
    if (!isPlaying || isChoosingUpgrade) return;

    inputTurnsThisStage++;
    if (inputTurnsThisStage >= turnsRequiredForNextStage) {
      advanceStageLevel();
    }
    onTutorialInputTurnCompleted();
  }

  @visibleForTesting
  List<UpgradeOption> availableRareUpgradeOptionsForTest() {
    final t = text;
    return <UpgradeOption>[
      if (!shieldUnlocked)
        UpgradeOption(
          type: UpgradeType.shield,
          title: t.upgradeTitle(UpgradeType.shield),
          description: t.upgradeDescription(UpgradeType.shield),
          color: const Color(0xFFFFD166),
          isRare: true,
        ),
      if (!lightfootGaugeUnlocked)
        UpgradeOption(
          type: UpgradeType.lightfootGauge,
          title: t.upgradeTitle(
            QuickDrawGame.lightfootGaugeDistance == 0.0
                ? UpgradeType.bladePower
                : UpgradeType.lightfootGauge,
          ),
          description: t.upgradeDescription(UpgradeType.lightfootGauge),
          color: const Color(0xFF00FFCC),
          isRare: true,
        ),
      if (!chainStrikeUnlocked)
        UpgradeOption(
          type: UpgradeType.chainStrike,
          title: t.upgradeTitle(UpgradeType.chainStrike),
          description: t.upgradeDescription(UpgradeType.chainStrike),
          color: const Color(0xFFA29BFE),
          isRare: true,
        ),
    ];
  }

  @visibleForTesting
  UpgradeOption? rollRareUpgradeForTest() {
    if (rareUpgradeCount >= QuickDrawGame.maxRareUpgradeCount) {
      return null;
    }
    if (random.nextDouble() >= QuickDrawGame.rareUpgradeChance) {
      return null;
    }
    final rareOptions = availableRareUpgradeOptionsForTest();
    if (rareOptions.isEmpty) {
      return null;
    }
    return rareOptions[random.nextInt(rareOptions.length)];
  }
}
