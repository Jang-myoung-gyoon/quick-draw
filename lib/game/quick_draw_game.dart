import 'dart:async' as async_timer;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/background.dart';
import '../components/effects.dart';
import '../components/player.dart';
import '../components/target.dart';
import '../audio/html_audio_stub.dart'
    if (dart.library.html) '../audio/html_audio_web.dart'
    as html_audio;

import '../models/upgrade.dart';
import '../models/achievement.dart';
import '../models/game_text.dart';
import '../models/audio.dart';

export '../models/upgrade.dart';
export '../models/achievement.dart';
export '../models/game_text.dart';
export '../models/audio.dart';

class QuickDrawGame extends FlameGame with KeyboardEvents, TapCallbacks {
  static const String _achievementBestStageKey =
      'quick_draw.achievements.best_stage';
  static const String _achievementBestCharacterKey =
      'quick_draw.achievements.best_character';
  static const String _achievementBestScoreKey =
      'quick_draw.achievements.best_score';
  static const String _achievementSelectedUpgradesKey =
      'quick_draw.achievements.selected_upgrades';
  static const String _achievementMaxedUpgradesKey =
      'quick_draw.achievements.maxed_upgrades';

  FallingBackground? background;
  late PlayerComponent player;

  // Game states
  bool isPlaying = false;
  bool isGameOver = false;
  bool isChoosingUpgrade = false;
  int score = 0;
  int combo = 0;

  // Health Gauge (0.0 to 1.0)
  double health = 1.1;
  static const double hiddenEnergyReserve = 0.1;
  final double maxHealth = 1.0 + hiddenEnergyReserve;
  double passiveDrainRate = 0.06435; // Drains fully in ~16 seconds if idle

  // Experience Gauge (0.0 to 1.0)
  double experience = 0.0;
  double get maxExperience => 1.0;
  int characterLevel = 1;
  int stageLevel = 1;
  int levelUpAnnouncementLevel = 1;
  String levelUpAnnouncementTitle = 'CHARACTER LEVEL UP';
  double levelUpAnnouncementTimer = 0.0;
  int inputTurnsThisStage = 0;
  int playerAttackPower = 1;
  int criticalStrikeLevel = 0;
  double scrollEnergyGainMultiplier = 1.0;
  int luckLevel = 0;
  int rareUpgradeCount = 0;
  int shadowCloneLevel = 0;
  bool shieldUnlocked = false;
  int shieldCharges = 0;
  bool lightfootGaugeUnlocked = false;
  double lightfootGauge = 0.0;
  bool chainStrikeUnlocked = false;
  List<UpgradeOption> currentUpgradeChoices = const [];
  double upgradeInputLockTimer = 0.0;
  final List<UpgradeType> acquiredRareUpgrades = [];
  int bestStageLevel = 1;
  int bestCharacterLevel = 1;
  int bestScore = 0;
  final Set<UpgradeType> selectedUpgradeAchievements = {};
  final Set<UpgradeType> maxedUpgradeAchievements = {};
  final Set<String> _announcedAchievementIds = {'stage-1', 'character-1'};
  final List<String> _achievementToastQueue = [];
  final ValueNotifier<int> achievementRevision = ValueNotifier<int>(0);
  String? achievementToastMessage;
  double achievementToastTimer = 0.0;
  bool _achievementProgressLoaded = false;
  Future<void>? _achievementProgressLoad;
  int _pendingExperienceHits = 0;
  final List<Vector2> _pendingLaserAttackOrigins = [];
  int _spawnsSinceLastBonus = 0;
  bool _pausedForSettings = false;
  bool soundEnabled = true;
  GameLanguage language = GameLanguage.ko;
  GameText get text => GameText(language);
  bool get isGameplayPausedForUi => isChoosingUpgrade || paused;

  // Chain variables (now using raw screen coordinates instead of targets)
  final List<Vector2> currentChainPoints = [];
  SlashPathLine? activePathLine;
  double chainTimer = 0.0;
  double maxChainTime = 1.5; // 1.5s to complete chain after first selection
  int maxChainLength = 1;
  double inputDrainMultiplier = 1.0;

  // Spawning variables
  double totalAltitude = 0.0; // Total distance climbed
  double _laserIndicatorTimer = 0.0;
  static const int baseFloatingObjects = 9;
  static const int maxFloatingObjects = 20;
  static const double _spawnInset = 48.0;
  static const double _replacementSpawnEdgeBand = 72.0;
  static const double _maxSpawnYFactor = 0.72;
  static const double baseReplacementSpawnPixelsPerObject = 80.0;
  int get targetFloatingObjectCount =>
      min(maxFloatingObjects, baseFloatingObjects + stageLevel - 1);
  double get replacementSpawnPixelsPerObject {
    final extraVisibleObjects = max(
      0,
      targetFloatingObjectCount - baseFloatingObjects,
    );
    return max(
      40.0,
      baseReplacementSpawnPixelsPerObject - extraVisibleObjects * 4.0,
    );
  }

  double get maxSpawnY => max(_spawnInset, size.y * _maxSpawnYFactor);

  int get experienceRequiredForCharacterLevel {
    final levelRamp = characterLevel - 1;
    return 4 + characterLevel * 2 + levelRamp * levelRamp;
  }

  int get turnsRequiredForNextStage => 5;
  int get bonusSpawnInterval {
    final reducedInterval = 400 * pow(0.9, luckLevel);
    return max(200, reducedInterval.round());
  }

  double get criticalStrikeChance => min(1.0, criticalStrikeLevel * 0.10);
  double get laserTargetSpawnChance {
    if (stageLevel < 2) {
      return 0.0;
    }
    return 0.013 + (stageLevel - 2) * 0.0065;
  }

  double get longObstacleChance => 0.18;

  int maxTargetDurabilityForStage(int level) {
    if (level <= 1) return 1;
    if (level == 2) return 2;
    if (level == 3) return 4;
    return min(15, 1 + level * 2);
  }

  int laserTargetStageDurabilityBase(int level) {
    if (level <= 2) return 1;
    return maxTargetDurabilityForStage(level);
  }

  @visibleForTesting
  double obstacleSpawnChanceForStage(int level) {
    if (level < 2) return 0;
    if (level == 3) return 0.15;
    return min(0.50, (level - 1) * 0.10);
  }

  final Random random = Random();
  Vector2 _lastCameraShift = Vector2(0, 1);
  static const int maxRareUpgradeCount = 3;
  static const double rareUpgradeChance = 0.1;
  static const double lightfootGaugeDistance = 24000.0;
  static const double upgradeInputLockDuration = 0.7;
  double _replacementSpawnScrollPixels = 0.0;
  double masterVolume = 1.0;
  double bgmVolume = 0.45;
  double sfxVolume = 1.0;
  final Map<GameSound, Future<AudioPool>> _soundPools = {};
  Future<void>? _audioInitialization;
  GameMusic? _currentBgmTrack;
  GameMusic? _bgmPlayingTrack;
  GameSound? lastRequestedSoundForTest;
  double get effectiveBgmVolume => (masterVolume * bgmVolume).clamp(0.0, 1.0);
  double get effectiveSfxVolume => (masterVolume * sfxVolume).clamp(0.0, 1.0);
  double effectiveSfxVolumeFor(GameSound sound) =>
      (effectiveSfxVolume * sound.volumeMultiplier).clamp(0.0, 1.0);
  double get displayedEnergy => (health - hiddenEnergyReserve).clamp(0.0, 1.0);
  bool get _canUseAudio =>
      soundEnabled &&
      !WidgetsBinding.instance.runtimeType.toString().contains(
        'TestWidgetsFlutterBinding',
      );

  // Screen shake
  double shakeIntensity = 0.0;
  double get lowHealthWarningIntensity {
    const threshold = 0.3;
    final energy = displayedEnergy;
    if (energy > threshold + 0.000001) {
      return 0.0;
    }
    final dangerRatio = ((threshold - energy) / threshold).clamp(0.0, 1.0);
    return (0.15 + dangerRatio * 0.85).clamp(0.0, 1.0);
  }

  // Slow motion factor when chaining targets (bullet time)
  double get speedMultiplier =>
      (currentChainPoints.isNotEmpty && !player.isDashing) ? 0.25 : 1.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await loadAchievementProgress();
    async_timer.unawaited(_preloadSounds());

    // 1. Background
    background = FallingBackground();
    add(background!);

    // 2. Player
    player = PlayerComponent();
    add(player);
  }

  Future<void> _preloadSounds() async {
    try {
      await FlameAudio.audioCache.loadAll([
        ...GameSound.values.map((sound) => sound.assetPath),
        ...GameMusic.values.map((music) => music.assetPath),
      ]);
    } catch (_) {
      // Audio should never block gameplay or tests.
    }
  }

  void playSound(GameSound sound) {
    lastRequestedSoundForTest = sound;
    if (!_canUseAudio) {
      return;
    }
    async_timer.unawaited(_playSound(sound));
  }

  Future<void> _playSound(GameSound sound) async {
    final volume = effectiveSfxVolumeFor(sound);
    if (html_audio.supportsHtmlAudio) {
      html_audio.playSfx(sound.assetPath, volume);
      return;
    }
    try {
      await _initializeAudio();
      final pool = await _soundPoolFor(sound);
      await pool.start(volume: volume);
    } catch (_) {
      _soundPools.remove(sound);
      // Audio should never block gameplay or tests.
    }
  }

  Future<AudioPool> _soundPoolFor(GameSound sound) {
    return _soundPools.putIfAbsent(sound, () => _createSoundPool(sound));
  }

  Future<AudioPool> _createSoundPool(GameSound sound) {
    return FlameAudio.createPool(sound.assetPath, minPlayers: 1, maxPlayers: 4);
  }

  Future<void> _initializeAudio() {
    return _audioInitialization ??= _doInitializeAudio();
  }

  Future<void> _doInitializeAudio() async {
    await FlameAudio.bgm.initialize();
    await FlameAudio.audioCache.loadAll([
      ...GameSound.values.map((sound) => sound.assetPath),
      ...GameMusic.values.map((music) => music.assetPath),
    ]);
  }

  void setMasterVolume(double value) {
    masterVolume = value.clamp(0.0, 1.0);
    _applyBgmVolume();
  }

  void setBgmVolume(double value) {
    bgmVolume = value.clamp(0.0, 1.0);
    _applyBgmVolume();
  }

  void setSfxVolume(double value) {
    sfxVolume = value.clamp(0.0, 1.0);
  }

  void previewUiVolume() {
    playSound(GameSound.uiVolumePreview);
  }

  void setLanguage(GameLanguage value) {
    if (language == value) {
      return;
    }
    language = value;
    currentUpgradeChoices = isChoosingUpgrade
        ? recommendedUpgradeChoices()
        : const [];
    achievementRevision.value++;
  }

  void _startBackgroundMusic() {
    _playBgmTrack(GameMusic.mainLoop);
  }

  void startHomeBgm() {
    _playBgmTrack(GameMusic.homeLoop);
  }

  void stopHomeBgm() {
    _stopBgmTrack();
  }

  void _playBgmTrack(GameMusic track) {
    if (!_canUseAudio) {
      return;
    }
    if (_bgmPlayingTrack == track && _currentBgmTrack == track) {
      return;
    }
    _currentBgmTrack = track;
    async_timer.unawaited(_doPlayBgmTrack(track));
  }

  Future<void> _doPlayBgmTrack(GameMusic track) async {
    if (html_audio.supportsHtmlAudio) {
      try {
        await html_audio.playBgm(track.assetPath, effectiveBgmVolume);
        _bgmPlayingTrack = track;
      } catch (_) {
        _bgmPlayingTrack = null;
      }
      return;
    }
    try {
      await _initializeAudio();
      if (_currentBgmTrack != track) return;
      await FlameAudio.bgm.play(track.assetPath, volume: effectiveBgmVolume);
      _bgmPlayingTrack = track;
    } catch (_) {
      _audioInitialization = null;
      _bgmPlayingTrack = null;
      // Music should never block gameplay or tests.
    }
  }

  void _applyBgmVolume() {
    if (html_audio.supportsHtmlAudio) {
      html_audio.setBgmVolume(effectiveBgmVolume);
      return;
    }
    if (!_canUseAudio) {
      return;
    }
    async_timer.unawaited(_setBgmPlayerVolume());
  }

  Future<void> _setBgmPlayerVolume() async {
    try {
      await FlameAudio.bgm.audioPlayer.setVolume(effectiveBgmVolume);
    } catch (_) {
      // Audio should never block gameplay or tests.
    }
  }

  void _stopBackgroundMusic() {
    _stopBgmTrack();
  }

  void _stopBgmTrack() {
    _currentBgmTrack = null;
    _bgmPlayingTrack = null;
    if (html_audio.supportsHtmlAudio) {
      html_audio.stopBgm();
      return;
    }
    if (!_canUseAudio) {
      return;
    }
    async_timer.unawaited(FlameAudio.bgm.stop());
  }

  void toggleMute() {
    if (masterVolume > 0.0) {
      _preMuteMasterVolume = masterVolume;
      setMasterVolume(0.0);
    } else {
      setMasterVolume(_preMuteMasterVolume > 0.0 ? _preMuteMasterVolume : 1.0);
    }
  }

  bool get isMuted => masterVolume <= 0.0;
  double _preMuteMasterVolume = 1.0;

  @override
  void onRemove() {
    _stopBackgroundMusic();
    for (final pool in _soundPools.values) {
      async_timer.unawaited(pool.then((value) => value.dispose()));
    }
    _soundPools.clear();
    achievementRevision.dispose();
    super.onRemove();
  }

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
    totalAltitude = 0.0;
    _laserIndicatorTimer = 0.0;
    _replacementSpawnScrollPixels = 0.0;
    _achievementToastQueue.clear();
    achievementToastMessage = null;
    achievementToastTimer = 0.0;
    isGameOver = false;
    isChoosingUpgrade = false;
    isPlaying = true;

    currentChainPoints.clear();
    _removePathLine();
    _clearGameplayComponents();

    player.resetToBasePosition();
    background?.resetForNewRun();

    _removeOverlayIfRegistered('StartScreen');
    _removeOverlayIfRegistered('GameOverScreen');
    _removeOverlayIfRegistered('AchievementsScreen');
    _removeOverlayIfRegistered('UpgradeScreen');
    _addOverlayIfRegistered('HUD');
    stopHomeBgm();
    _startBackgroundMusic();

    // Spawn initial objects scattered across the screen
    _spawnInitialObjects();
  }

  void gameOver() {
    _recordAchievementProgress(showToasts: true);
    _pausedForSettings = false;
    if (paused) {
      resumeEngine();
    }
    isPlaying = false;
    isGameOver = true;
    isChoosingUpgrade = false;
    currentChainPoints.clear();
    _removePathLine();

    _removeOverlayIfRegistered('HUD');
    _removeOverlayIfRegistered('UpgradeScreen');
    _addOverlayIfRegistered('GameOverScreen');
    playSound(GameSound.gameOver);
    _stopBackgroundMusic();
  }

  // Tap anywhere on screen to record waypoints
  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (!isPlaying) return;

    if (!player.isDashing) {
      addToChain(event.localPosition);
    }
  }

  // Chain Management
  void addToChain(Vector2 tapPos) {
    if (currentChainPoints.length >= maxChainLength || player.isDashing) return;

    currentChainPoints.add(tapPos);
    if (currentChainPoints.length == 1) {
      player.lockChainDirection(tapPos);
      chainTimer = 0.0;
    }

    // Redraw preview line
    _removePathLine();
    activePathLine = SlashPathLine(waypoints: currentChainPoints);
    add(activePathLine!);

    // Dynamically highlight targets crossed by this path
    _updateChainHighlighting();

    // Start dash immediately if chain limit reached
    if (currentChainPoints.length == maxChainLength) {
      _executeChainSlash();
    }
  }

  void _updateChainHighlighting() {
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

  void _executeChainSlash() {
    if (currentChainPoints.isEmpty) return;

    playSound(GameSound.slashSwing);
    player.startChainDash(currentChainPoints);
    currentChainPoints.clear();
    _removePathLine();
  }

  double effectiveTargetHitRadius(SlashTarget target) =>
      target.pathHitRadius + shadowCloneLevel * 32.0;

  void resetChain() {
    currentChainPoints.clear();
    _removePathLine();
    _updateChainHighlighting();
    combo = 0;
  }

  void _removePathLine() {
    if (activePathLine != null) {
      activePathLine!.removeFromParent();
      activePathLine = null;
    }
  }

  // Game Logic Triggered by Components
  void triggerTargetSliced(Vector2 hitPoint, {SlashTarget? target}) {
    playSound(
      target is LaserTarget ? GameSound.laserAttack : GameSound.targetSlice,
    );
    score += 100 + (combo * 10);
    bestScore = max(bestScore, score);
    _recordAchievementProgress(showToasts: true);
    combo++;
    shakeIntensity = min(shakeIntensity + 10.0, 25.0);
    if (target != null) {
      _pendingExperienceHits += target.experienceValue;
      _spawnExperienceShards(hitPoint, target.experienceValue);
      if (target is LaserTarget) {
        _spawnEnergyShards(hitPoint, target.durability);
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

  void onInputTurnCompleted() {
    if (!isPlaying || isChoosingUpgrade) return;

    inputTurnsThisStage++;
    if (inputTurnsThisStage >= turnsRequiredForNextStage) {
      _advanceStageLevel();
    }
  }

  void _gainExperienceForRemovedHits(int durability) {
    if (!isPlaying || isChoosingUpgrade) {
      return;
    }
    experience += durability / experienceRequiredForCharacterLevel;
    if (experience >= maxExperience) {
      _advanceCharacterLevel();
    }
  }

  void collectPendingTargetExperience({bool animate = true}) {
    if (_pendingExperienceHits <= 0) {
      return;
    }

    final totalRequiredHits = _pendingExperienceHits;
    _pendingExperienceHits = 0;
    _gainExperienceForRemovedHits(totalRequiredHits);
  }

  void _spawnExperienceShards(Vector2 origin, int durability) {
    add(
      ExperienceShardEmitter(
        origins: _experienceShardOrigins(origin, durability),
        burstDirection: -player.experienceShardBurstDirection,
      ),
    );
  }

  List<Vector2> _experienceShardOrigins(Vector2 origin, int durability) {
    final origins = <Vector2>[];
    final shardCount = min(8, max(2, durability + 1));
    for (var i = 0; i < shardCount; i++) {
      final angle = (i / shardCount) * pi * 2;
      origins.add(origin + Vector2(cos(angle), sin(angle)) * 14.0);
    }
    return origins;
  }

  void _spawnEnergyShards(Vector2 origin, int durability) {
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

  void _advanceCharacterLevel() {
    characterLevel++;
    bestCharacterLevel = max(bestCharacterLevel, characterLevel);
    _recordAchievementProgress(showToasts: true);
    levelUpAnnouncementLevel = characterLevel;
    levelUpAnnouncementTitle = 'CHARACTER LEVEL UP';
    levelUpAnnouncementTimer = 2.4;
    experience = 0.0;
    _offerUpgradeChoices();
  }

  void _advanceStageLevel() {
    stageLevel++;
    bestStageLevel = max(bestStageLevel, stageLevel);
    _recordAchievementProgress(showToasts: true);
    inputTurnsThisStage = 0;
    levelUpAnnouncementLevel = stageLevel;
    levelUpAnnouncementTitle = 'STAGE LEVEL UP';
    levelUpAnnouncementTimer = 2.4;
    _applyStageDifficulty();
  }

  void _applyStageDifficulty() {
    inputDrainMultiplier = 1.0 + (stageLevel - 1) * 0.28;
  }

  void _offerUpgradeChoices() {
    if (isChoosingUpgrade) return;
    isChoosingUpgrade = true;
    currentChainPoints.clear();
    _removePathLine();
    currentUpgradeChoices = recommendedUpgradeChoices();
    upgradeInputLockTimer = upgradeInputLockDuration;
    if (overlays.registeredOverlays.contains('UpgradeScreen')) {
      overlays.add('UpgradeScreen', priority: 100);
    }
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
    final rare = _rollRareUpgrade();
    if (rare != null && choices.isNotEmpty) {
      choices[choices.length - 1] = rare;
    }
    return choices.toList(growable: false);
  }

  UpgradeOption? _rollRareUpgrade() {
    if (rareUpgradeCount >= maxRareUpgradeCount) {
      return null;
    }
    if (random.nextDouble() >= rareUpgradeChance) {
      return null;
    }
    final rareOptions = availableRareUpgradeOptionsForTest();
    if (rareOptions.isEmpty) {
      return null;
    }
    return rareOptions[random.nextInt(rareOptions.length)];
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
          color: const Color(0xFFEAB308),
          isRare: true,
        ),
      if (!lightfootGaugeUnlocked)
        UpgradeOption(
          type: UpgradeType.lightfootGauge,
          title: t.upgradeTitle(UpgradeType.lightfootGauge),
          description: t.upgradeDescription(UpgradeType.lightfootGauge),
          color: const Color(0xFF22C55E),
          isRare: true,
        ),
      if (!chainStrikeUnlocked)
        UpgradeOption(
          type: UpgradeType.chainStrike,
          title: t.upgradeTitle(UpgradeType.chainStrike),
          description: t.upgradeDescription(UpgradeType.chainStrike),
          color: const Color(0xFFF97316),
          isRare: true,
        ),
    ];
  }

  @visibleForTesting
  UpgradeOption? rollRareUpgradeForTest() => _rollRareUpgrade();

  bool get canChooseUpgrade => upgradeInputLockTimer <= 0.0;

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

  void chooseUpgrade(UpgradeOption option) {
    if (!canChooseUpgrade) {
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
        _recordRareUpgrade(option.type);
      case UpgradeType.lightfootGauge:
        lightfootGaugeUnlocked = true;
        lightfootGauge = 0.0;
        rareUpgradeCount++;
        _recordRareUpgrade(option.type);
      case UpgradeType.chainStrike:
        chainStrikeUnlocked = true;
        rareUpgradeCount++;
        _recordRareUpgrade(option.type);
    }
    currentUpgradeChoices = const [];
    upgradeInputLockTimer = 0.0;
    isChoosingUpgrade = false;
    overlays.remove('UpgradeScreen');
    _recordAchievementProgress(showToasts: true);
    _updateChainHighlighting();
  }

  void showAchievements() {
    async_timer.unawaited(_showAchievements());
  }

  Future<void> _showAchievements() async {
    await loadAchievementProgress();
    _recordAchievementProgress();
    _addOverlayIfRegistered('AchievementsScreen', priority: 120);
  }

  void hideAchievements() {
    overlays.remove('AchievementsScreen');
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
    _addOverlayIfRegistered('SettingsScreen', priority: 200);
  }

  void closeSettings() {
    playSound(GameSound.uiSelect);
    _removeOverlayIfRegistered('SettingsScreen');
    if (_pausedForSettings) {
      _pausedForSettings = false;
      resumeEngine();
    }
  }

  void returnHomeFromSettings() {
    playSound(GameSound.uiConfirm);
    _recordAchievementProgress(showToasts: true);
    _pausedForSettings = false;
    if (paused) {
      resumeEngine();
    }
    isPlaying = false;
    isGameOver = false;
    isChoosingUpgrade = false;
    currentChainPoints.clear();
    _removePathLine();
    _stopBackgroundMusic();
    _clearGameplayComponents();

    _removeOverlayIfRegistered('SettingsScreen');
    _removeOverlayIfRegistered('UpgradeScreen');
    _removeOverlayIfRegistered('GameOverScreen');
    _removeOverlayIfRegistered('HUD');
    _addOverlayIfRegistered('StartScreen');
    startHomeBgm();
  }

  void _addOverlayIfRegistered(String name, {int priority = 0}) {
    if (overlays.registeredOverlays.contains(name)) {
      overlays.add(name, priority: priority);
    }
  }

  void _removeOverlayIfRegistered(String name) {
    if (overlays.registeredOverlays.contains(name)) {
      overlays.remove(name);
    }
  }

  void _clearGameplayComponents() {
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

  void _recordAchievementProgress({bool showToasts = false}) {
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
      changed = _recordSelectedUpgradeAchievement(type) || changed;
      changed = _recordMaxedUpgradeAchievement(type) || changed;
    }
    if (changed) {
      achievementRevision.value++;
      _persistAchievementProgressIfLoaded();
    }
    if (showToasts) {
      _enqueueNewlyUnlockedAchievementToasts();
    }
  }

  Future<void> loadAchievementProgress() {
    return _achievementProgressLoad ??= _loadAchievementProgress();
  }

  Future<void> _loadAchievementProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bestStageLevel = max(
        bestStageLevel,
        prefs.getInt(_achievementBestStageKey) ?? bestStageLevel,
      );
      bestCharacterLevel = max(
        bestCharacterLevel,
        prefs.getInt(_achievementBestCharacterKey) ?? bestCharacterLevel,
      );
      bestScore = max(
        bestScore,
        prefs.getInt(_achievementBestScoreKey) ?? bestScore,
      );
      final storedMaxedUpgrades =
          prefs.getStringList(_achievementMaxedUpgradesKey) ?? const <String>[];
      final storedSelectedUpgrades =
          prefs.getStringList(_achievementSelectedUpgradesKey) ??
          const <String>[];
      selectedUpgradeAchievements.addAll(
        storedSelectedUpgrades
            .map(_upgradeTypeFromName)
            .whereType<UpgradeType>(),
      );
      maxedUpgradeAchievements.addAll(
        storedMaxedUpgrades.map(_upgradeTypeFromName).whereType<UpgradeType>(),
      );
      selectedUpgradeAchievements.addAll(maxedUpgradeAchievements);
    } catch (_) {
      // Local persistence should not block the game or tests.
    } finally {
      _achievementProgressLoaded = true;
      achievementRevision.value++;
      _recordAchievementProgress();
    }
  }

  UpgradeType? _upgradeTypeFromName(String name) {
    for (final type in UpgradeType.values) {
      if (type.name == name) {
        return type;
      }
    }
    return null;
  }

  void _persistAchievementProgressIfLoaded() {
    if (!_achievementProgressLoaded) {
      return;
    }
    async_timer.unawaited(saveAchievementProgress());
  }

  @visibleForTesting
  Future<void> saveAchievementProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_achievementBestStageKey, bestStageLevel);
      await prefs.setInt(_achievementBestCharacterKey, bestCharacterLevel);
      await prefs.setInt(_achievementBestScoreKey, bestScore);
      await prefs.setStringList(
        _achievementSelectedUpgradesKey,
        selectedUpgradeAchievements
            .map((type) => type.name)
            .toList(growable: false),
      );
      await prefs.setStringList(
        _achievementMaxedUpgradesKey,
        maxedUpgradeAchievements
            .map((type) => type.name)
            .toList(growable: false),
      );
    } catch (_) {
      // Local persistence should not block gameplay.
    }
  }

  bool _recordSelectedUpgradeAchievement(UpgradeType type) {
    if (isUpgradeSelected(type)) {
      return selectedUpgradeAchievements.add(type);
    }
    return false;
  }

  bool _recordMaxedUpgradeAchievement(UpgradeType type) {
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
    _recordAchievementProgress();
    return [
      ..._upgradeAchievements(),
      ..._stageAchievements(),
      ..._characterAchievements(),
      ..._scoreAchievements(),
    ];
  }

  List<Achievement> visibleAchievementsForDisplay() {
    return visibleAchievementsFrom(achievementsForDisplay());
  }

  static List<Achievement> visibleAchievementsFrom(
    List<Achievement> achievements,
  ) {
    return [
      ..._visibleUpgradeAchievementsFrom(achievements),
      _visibleProgressAchievementFrom(achievements, AchievementGroup.stage),
      _visibleProgressAchievementFrom(achievements, AchievementGroup.character),
      _visibleProgressAchievementFrom(achievements, AchievementGroup.score),
    ].whereType<Achievement>().toList(growable: false);
  }

  static List<Achievement> _visibleUpgradeAchievementsFrom(
    List<Achievement> achievements,
  ) {
    final visible = <Achievement>[];
    for (final type in UpgradeType.values) {
      final steps = achievements
          .where(
            (achievement) => achievement.id.startsWith('upgrade-${type.name}-'),
          )
          .toList(growable: false);
      if (steps.isEmpty) {
        continue;
      }
      visible.add(
        steps.firstWhere((step) => !step.unlocked, orElse: () => steps.last),
      );
    }
    return visible;
  }

  static Achievement? _visibleProgressAchievementFrom(
    List<Achievement> achievements,
    AchievementGroup group,
  ) {
    final steps = achievements
        .where((achievement) => achievement.group == group)
        .toList(growable: false);
    if (steps.isEmpty) {
      return null;
    }
    return steps.firstWhere((step) => !step.unlocked, orElse: () => steps.last);
  }

  void _enqueueNewlyUnlockedAchievementToasts() {
    for (final achievement in achievementsForDisplay()) {
      if (!achievement.unlocked) {
        continue;
      }
      if (_announcedAchievementIds.add(achievement.id)) {
        _achievementToastQueue.add(text.achievementUnlocked(achievement.title));
      }
    }
  }

  void _updateAchievementToast(double dt) {
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

  List<Achievement> _upgradeAchievements() {
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
              progress: selectedUpgradeAchievements.contains(type) ? 1.0 : 0.0,
            ),
            Achievement(
              id: 'upgrade-${type.name}-maxed',
              title: t.masteredAchievementTitle(type),
              description: t.masteredAchievementDescription,
              group: AchievementGroup.upgrade,
              unlocked: maxedUpgradeAchievements.contains(type),
              progress: maxedUpgradeAchievements.contains(type) ? 1.0 : 0.0,
            ),
          ],
        )
        .toList(growable: false);
  }

  List<Achievement> _stageAchievements() {
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
            progress: (bestStageLevel / level).clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
  }

  List<Achievement> _characterAchievements() {
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
            progress: (bestCharacterLevel / level).clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
  }

  List<Achievement> _scoreAchievements() {
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
            progress: (bestScore / scoreTarget).clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
  }

  void _recordRareUpgrade(UpgradeType type) {
    if (!acquiredRareUpgrades.contains(type)) {
      acquiredRareUpgrades.add(type);
    }
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
      gameOver();
    }
    return false;
  }

  bool triggerLaserTargetMissed(Vector2 laserOrigin) {
    if (player.isResolvingAction) {
      _pendingLaserAttackOrigins.add(laserOrigin.clone());
      return false;
    }
    return _applyLaserAttack(laserOrigin);
  }

  void resolvePendingLaserAttacks() {
    if (_pendingLaserAttackOrigins.isEmpty) {
      return;
    }
    final origins = List<Vector2>.from(_pendingLaserAttackOrigins);
    _pendingLaserAttackOrigins.clear();
    for (final origin in origins) {
      _applyLaserAttack(origin);
    }
  }

  @visibleForTesting
  int get pendingLaserAttackCountForTest => _pendingLaserAttackOrigins.length;

  bool _applyLaserAttack(Vector2 laserOrigin) {
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

  void spawnSliceParticles(Vector2 position, Color color) {
    add(SliceParticleEmitter(position: position, color: color));
  }

  void addLightfootDistance(double distance) {
    if (!lightfootGaugeUnlocked || distance <= 0) {
      return;
    }
    lightfootGauge += distance / lightfootGaugeDistance;
    if (lightfootGauge >= 1.0) {
      lightfootGauge = 0.0;
      activateUltimate();
    }
  }

  void triggerBonusCollected(Vector2 hitPoint) {
    playSound(GameSound.bonusCollect);
    spawnSliceParticles(hitPoint, const Color(0xFF22C55E));
    activateUltimate();
  }

  void activateUltimate() {
    if (player.isPerformingUltimate) {
      return;
    }
    health = maxHealth;
    shakeIntensity = 25.0;
    currentChainPoints.clear();
    _removePathLine();
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
    _spawnVerticalUltimateSlash();
  }

  void _spawnVerticalUltimateSlash() {
    final x = player.position.x;
    const slashColor = Color(0xFF22C55E);
    for (var y = player.position.y; y >= -80; y -= 180) {
      spawnSliceParticles(Vector2(x, y), slashColor);
    }
  }

  /// Called by the player after a dash completes to report vertical climb
  void onPlayerClimbed(double climbAmount) {
    totalAltitude += climbAmount;
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
      hiddenEnergyReserve,
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

  /// Called every frame while the camera follows the player after a dash.
  void shiftWorldForCamera(Vector2 delta) {
    if (delta.length2 > 0) {
      _lastCameraShift = delta.clone();
      _addReplacementScrollPixels(delta.length);
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

    _maintainFloatingObjectCount();
  }

  @override
  void update(double dt) {
    _laserIndicatorTimer += dt;
    _recordAchievementProgress(showToasts: isPlaying && !isGameOver);
    _updateAchievementToast(dt);
    // Screen shake decay
    if (shakeIntensity > 0) {
      shakeIntensity = max(0.0, shakeIntensity - dt * 50.0);
    }
    if (levelUpAnnouncementTimer > 0) {
      levelUpAnnouncementTimer = max(0.0, levelUpAnnouncementTimer - dt);
    }
    if (upgradeInputLockTimer > 0) {
      upgradeInputLockTimer = max(0.0, upgradeInputLockTimer - dt);
    }

    // Apply speed multiplier (time dilation)
    final double adjustedDt = dt * speedMultiplier;
    if (isChoosingUpgrade) {
      _syncBackgroundMotionSpeed();
      return;
    }

    _syncBackgroundMotionSpeed();
    super.update(adjustedDt);

    if (!isPlaying) return;

    // Passive energy decay when not dashing
    if (!player.isDashing) {
      health -= passiveDrainRate * inputDrainMultiplier * adjustedDt;
      if (health <= 0) {
        health = 0.0;
        gameOver();
      }
    }

    // Handle chain expiration timer (using real delta time so bullet time doesn't freeze the timer)
    if (currentChainPoints.isNotEmpty && !player.isDashing) {
      chainTimer += dt;
      if (chainTimer >= maxChainTime) {
        _executeChainSlash();
      }
    }
  }

  void _syncBackgroundMotionSpeed() {
    final bg = background;
    if (bg == null) {
      return;
    }
    bg.currentSpeed = player.isDashing ? bg.dashSpeed : bg.normalSpeed;
  }

  /// Spawn initial objects scattered across the upper portion of the screen
  void _spawnInitialObjects() {
    for (int i = 0; i < targetFloatingObjectCount; i++) {
      final double xPos = 40.0 + random.nextDouble() * (size.x - 80.0);
      final double yPos = _randomInRange(_spawnInset, maxSpawnY);
      _spawnSingleObject(xPos, yPos);
    }
  }

  void _maintainFloatingObjectCount() {
    if (!isPlaying) return;
    if (!_lastCameraShiftAllowsReplacementSpawn()) return;

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

    final spawned = _spawnReplacementObject(visibleObjects);
    visibleObjects.add(spawned);
    _replacementSpawnScrollPixels -= replacementSpawnPixelsPerObject;
  }

  void _addReplacementScrollPixels(double scrolledPixels) {
    if (scrolledPixels <= 0) {
      return;
    }
    if (!_lastCameraShiftAllowsReplacementSpawn()) {
      return;
    }
    _replacementSpawnScrollPixels = min(
      replacementSpawnPixelsPerObject * 2,
      _replacementSpawnScrollPixels + scrolledPixels,
    );
  }

  bool _lastCameraShiftAllowsReplacementSpawn() {
    final verticalScroll = _lastCameraShift.y.abs() >= _lastCameraShift.x.abs();
    return !verticalScroll || _lastCameraShift.y >= 0;
  }

  @visibleForTesting
  double replacementSpawnScrollPixelsForTest() => _replacementSpawnScrollPixels;

  @visibleForTesting
  void addReplacementScrollPixelsForTest(double scrolledPixels) {
    _addReplacementScrollPixels(scrolledPixels);
  }

  @visibleForTesting
  void setReplacementCameraShiftForTest(Vector2 cameraShift) {
    _lastCameraShift = cameraShift.clone();
  }

  @visibleForTesting
  void maintainFloatingObjectCountForTest() {
    _maintainFloatingObjectCount();
  }

  @visibleForTesting
  void processReplacementSpawnAfterScrollForTest(double scrolledPixels) {
    _addReplacementScrollPixels(scrolledPixels);
    _maintainFloatingObjectCount();
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

  FloatingObject _spawnReplacementObject(List<FloatingObject> existingObjects) {
    final position = replacementBoundarySpawnPosition(
      existingObjects: existingObjects,
      cameraShift: _lastCameraShift,
    );

    return _spawnSingleObject(position.x, position.y);
  }

  Vector2 replacementBoundarySpawnPosition({
    required Iterable<FloatingObject> existingObjects,
    required Vector2 cameraShift,
  }) {
    final horizontalScroll = cameraShift.x.abs() > cameraShift.y.abs();
    final edgeBand = min(_replacementSpawnEdgeBand, min(size.x, size.y) * 0.24);

    Vector2 sampleCandidate() {
      if (horizontalScroll) {
        final enteringFromLeft = cameraShift.x > 0;
        final x = enteringFromLeft
            ? _randomInRange(_spawnInset, _spawnInset + edgeBand)
            : _randomInRange(
                size.x - _spawnInset - edgeBand,
                size.x - _spawnInset,
              );
        return Vector2(x, _randomInRange(_spawnInset, maxSpawnY));
      }

      final enteringFromTop = cameraShift.y >= 0;
      final y = enteringFromTop
          ? _randomInRange(_spawnInset, _spawnInset + edgeBand)
          : _randomInRange(max(_spawnInset, maxSpawnY - edgeBand), maxSpawnY);
      return Vector2(_randomInRange(_spawnInset, size.x - _spawnInset), y);
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

  double _randomInRange(double minValue, double maxValue) {
    if (maxValue <= minValue) {
      return (minValue + maxValue) / 2;
    }
    return minValue + random.nextDouble() * (maxValue - minValue);
  }

  /// Spawn a single target or obstacle at the given position
  @visibleForTesting
  FloatingObject spawnFloatingObjectForTest(double x, double y) =>
      _spawnSingleObject(x, y);

  FloatingObject _spawnSingleObject(double x, double y) {
    if (stageLevel == 1) {
      final target = SlashTarget(durability: 1)..position = Vector2(x, y);
      add(target);
      _recordNonBonusSpawn();
      _updateChainHighlighting();
      return target;
    }

    final roll = random.nextDouble();
    if (_shouldSpawnBonusObject()) {
      final bonus = BonusTarget()..position = Vector2(x, y);
      add(bonus);
      _spawnsSinceLastBonus = 0;
      _updateChainHighlighting();
      return bonus;
    }

    final laserChance = laserTargetSpawnChance;
    if (stageLevel >= 2 && roll < laserChance) {
      final target = LaserTarget(
        maxStageDurability: laserTargetStageDurabilityBase(stageLevel),
      )..position = Vector2(x, y);
      add(target);
      _recordNonBonusSpawn();
      _updateChainHighlighting();
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
      _recordNonBonusSpawn();
      _updateChainHighlighting();
      return obstacle;
    } else {
      final target = SlashTarget(
        durability: 1 + random.nextInt(maxTargetDurabilityForStage(stageLevel)),
      )..position = Vector2(x, y);
      add(target);
      _recordNonBonusSpawn();
      _updateChainHighlighting();
      return target;
    }
  }

  bool _shouldSpawnBonusObject() {
    return stageLevel >= 2 && _spawnsSinceLastBonus >= bonusSpawnInterval - 1;
  }

  void _recordNonBonusSpawn() {
    _spawnsSinceLastBonus++;
  }

  @visibleForTesting
  int get spawnsSinceLastBonusForTest => _spawnsSinceLastBonus;

  @override
  void render(Canvas canvas) {
    canvas.save();

    // Apply screen shake
    if (shakeIntensity > 0) {
      final double dx = (random.nextDouble() - 0.5) * shakeIntensity;
      final double dy = (random.nextDouble() - 0.5) * shakeIntensity;
      canvas.translate(dx, dy);
    }

    super.render(canvas);

    canvas.restore();
    _renderLowHealthWarning(canvas);
    _renderLaserTargetIndicators(canvas);
  }

  void _renderLowHealthWarning(Canvas canvas) {
    final intensity = lowHealthWarningIntensity;
    if (intensity <= 0) {
      return;
    }

    // Handled by LowEnergyWarningPainter which is defined in the HUD Overlay module, but we import and call it here.
    // LowEnergyWarningPainter is exported/imported.
    LowEnergyWarningPainter(intensity).paint(canvas, Size(size.x, size.y));
  }

  Offset? laserTargetIndicatorOffsetForTest(LaserTarget target) {
    return _laserTargetIndicatorOffset(target);
  }

  Offset? _laserTargetIndicatorOffset(LaserTarget target) {
    if (size.x <= 0 || size.y <= 0 || isFloatingObjectVisible(target)) {
      return null;
    }
    const inset = 38.0;
    return Offset(
      target.position.x.clamp(inset, size.x - inset).toDouble(),
      target.position.y.clamp(inset, size.y - inset).toDouble(),
    );
  }

  void _renderLaserTargetIndicators(Canvas canvas) {
    for (final target in children.whereType<LaserTarget>()) {
      final indicator = _laserTargetIndicatorOffset(target);
      if (indicator == null) {
        continue;
      }
      final targetOffset = Offset(target.position.x, target.position.y);
      final angle = atan2(
        targetOffset.dy - indicator.dy,
        targetOffset.dx - indicator.dx,
      );
      _drawLaserTargetIndicator(canvas, indicator, angle);
    }
  }

  void _drawLaserTargetIndicator(Canvas canvas, Offset center, double angle) {
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

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    return KeyEventResult.ignored;
  }
}

@visibleForTesting
class LowEnergyWarningPainter extends CustomPainter {
  final double intensity;

  const LowEnergyWarningPainter(this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0 || size.isEmpty) {
      return;
    }

    final clampedIntensity = intensity.clamp(0.0, 1.0).toDouble();
    final edgeWidth = max(72.0, min(size.width, size.height) * 0.18);
    final edgeOpacity = 0.09 + clampedIntensity * 0.23;
    final red = const Color(0xFFFF003C);

    void drawEdge(Rect rect, Alignment begin, Alignment end) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: begin,
          end: end,
          colors: [
            red.withValues(alpha: edgeOpacity),
            red.withValues(alpha: edgeOpacity * 0.28),
            Colors.transparent,
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }

    drawEdge(
      Rect.fromLTWH(0, 0, size.width, edgeWidth),
      Alignment.topCenter,
      Alignment.bottomCenter,
    );
    drawEdge(
      Rect.fromLTWH(0, size.height - edgeWidth, size.width, edgeWidth),
      Alignment.bottomCenter,
      Alignment.topCenter,
    );
    drawEdge(
      Rect.fromLTWH(0, 0, edgeWidth, size.height),
      Alignment.centerLeft,
      Alignment.centerRight,
    );
    drawEdge(
      Rect.fromLTWH(size.width - edgeWidth, 0, edgeWidth, size.height),
      Alignment.centerRight,
      Alignment.centerLeft,
    );
  }

  @override
  bool shouldRepaint(covariant LowEnergyWarningPainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}
