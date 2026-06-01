import 'dart:async' as async_timer;
import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'components/background.dart';
import 'components/effects.dart';
import 'components/player.dart';
import 'components/target.dart';
import 'audio/html_audio_stub.dart'
    if (dart.library.html) 'audio/html_audio_web.dart'
    as html_audio;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureFullscreenSystemUi();
  runApp(const MyGameApp());
}

@visibleForTesting
Future<void> configureFullscreenSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}

enum UpgradeType {
  bladePower,
  criticalStrike,
  chainLength,
  scrollRecovery,
  energyEfficiency,
  focusTime,
  luck,
  shadowClone,
  shield,
  lightfootGauge,
  chainStrike,
}

class UpgradeOption {
  final UpgradeType type;
  final String title;
  final String description;
  final Color color;
  final bool isRare;
  final String? currentValue;

  const UpgradeOption({
    required this.type,
    required this.title,
    required this.description,
    required this.color,
    this.isRare = false,
    this.currentValue,
  });

  String get iconAssetPath => type.iconAssetPath;
}

class SlashDamageRoll {
  final int damage;
  final bool isCritical;

  const SlashDamageRoll({required this.damage, required this.isCritical});
}

enum AchievementGroup { upgrade, stage, character, score }

class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementGroup group;
  final bool unlocked;
  final double progress;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.group,
    required this.unlocked,
    required this.progress,
  });
}

enum GameSound {
  slashSwing('elevenlabs/slash_swing.mp3'),
  targetSlice('elevenlabs/target_slice_soft.mp3'),
  targetHit('elevenlabs/target_hit.mp3'),
  obstacleHit('elevenlabs/obstacle_hit.mp3'),
  bonusCollect('elevenlabs/bonus_collect.mp3'),
  laserAttack('elevenlabs/laser_attack.mp3'),
  energyShardAbsorb('elevenlabs/energy_shard_absorb.mp3'),
  experienceShardAbsorb('elevenlabs/experience_shard_absorb.mp3'),
  uiSelect('elevenlabs/ui_select.mp3'),
  uiConfirm('elevenlabs/ui_confirm.mp3'),
  uiVolumePreview('elevenlabs/ui_volume_preview.mp3');

  final String assetPath;

  const GameSound(this.assetPath);

  double get volumeMultiplier => switch (this) {
    GameSound.energyShardAbsorb || GameSound.experienceShardAbsorb => 0.6,
    GameSound.uiSelect ||
    GameSound.uiConfirm ||
    GameSound.uiVolumePreview => 0.72,
    _ => 1.0,
  };
}

enum GameMusic {
  mainLoop('gemini_bgm/quick_draw_loop.mp3');

  final String assetPath;

  const GameMusic(this.assetPath);
}

extension UpgradeTypeIconAsset on UpgradeType {
  String get iconAssetPath => switch (this) {
    UpgradeType.bladePower => 'assets/images/icons/upgrades/blade_power.png',
    UpgradeType.criticalStrike =>
      'assets/images/icons/upgrades/critical_chance.png',
    UpgradeType.chainLength => 'assets/images/icons/upgrades/chain_length.png',
    UpgradeType.scrollRecovery =>
      'assets/images/icons/upgrades/scroll_recovery.png',
    UpgradeType.energyEfficiency =>
      'assets/images/icons/upgrades/energy_efficiency.png',
    UpgradeType.focusTime => 'assets/images/icons/upgrades/focus_time.png',
    UpgradeType.luck => 'assets/images/icons/upgrades/luck.png',
    UpgradeType.shadowClone => 'assets/images/icons/upgrades/shadow_clone.png',
    UpgradeType.shield => 'assets/images/icons/upgrades/shield.png',
    UpgradeType.lightfootGauge =>
      'assets/images/icons/upgrades/lightfoot_gauge.png',
    UpgradeType.chainStrike => 'assets/images/icons/upgrades/chain_strike.png',
  };
}

class MyGameApp extends StatelessWidget {
  const MyGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battoujutsu Slasher',
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  static const double _mobileViewportWidth = 780.0;
  static const double _mobileViewportHeight = 1688.0;

  late QuickDrawGame _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = QuickDrawGame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      async_timer.unawaited(configureFullscreenSystemUi());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _game.handleSystemBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF05060A),
        body: SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _mobileViewportWidth,
                height: _mobileViewportHeight,
                child: ClipRect(
                  child: GameWidget<QuickDrawGame>(
                    game: _game,
                    overlayBuilderMap: {
                      'StartScreen': (context, game) =>
                          StartOverlay(game: game),
                      'GameOverScreen': (context, game) =>
                          GameOverOverlay(game: game),
                      'HUD': (context, game) => HUDOverlay(game: game),
                      'UpgradeScreen': (context, game) =>
                          UpgradeOverlay(game: game),
                      'AchievementsScreen': (context, game) =>
                          AchievementsOverlay(game: game),
                      'SettingsScreen': (context, game) =>
                          SettingsOverlay(game: game),
                    },
                    initialActiveOverlays: const ['StartScreen'],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
        GameMusic.mainLoop.assetPath,
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
      GameMusic.mainLoop.assetPath,
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

  void _startBackgroundMusic() {
    if (!_canUseAudio) {
      return;
    }
    async_timer.unawaited(_playBackgroundMusic());
  }

  Future<void> _playBackgroundMusic() async {
    if (html_audio.supportsHtmlAudio) {
      html_audio.playBgm(GameMusic.mainLoop.assetPath, effectiveBgmVolume);
      return;
    }
    try {
      await _initializeAudio();
      await FlameAudio.bgm.play(
        GameMusic.mainLoop.assetPath,
        volume: effectiveBgmVolume,
      );
    } catch (_) {
      _audioInitialization = null;
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
    if (html_audio.supportsHtmlAudio) {
      html_audio.stopBgm();
      return;
    }
    if (!_canUseAudio) {
      return;
    }
    async_timer.unawaited(FlameAudio.bgm.stop());
  }

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

    // Clear any existing targets/obstacles
    children.whereType<FloatingObject>().forEach(
      (obj) => obj.removeFromParent(),
    );
    children.whereType<SlicedHalfComponent>().forEach(
      (obj) => obj.removeFromParent(),
    );
    children.whereType<SliceParticleEmitter>().forEach(
      (obj) => obj.removeFromParent(),
    );

    player.resetToBasePosition();

    _removeOverlayIfRegistered('StartScreen');
    _removeOverlayIfRegistered('GameOverScreen');
    _removeOverlayIfRegistered('AchievementsScreen');
    _removeOverlayIfRegistered('UpgradeScreen');
    _addOverlayIfRegistered('HUD');
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
    final options = <UpgradeOption>[
      UpgradeOption(
        type: UpgradeType.bladePower,
        title: 'Blade Power',
        description: 'Increase attack power by 1.',
        color: const Color(0xFFFF335F),
        currentValue: 'CURRENT $playerAttackPower',
      ),
      UpgradeOption(
        type: UpgradeType.criticalStrike,
        title: 'Critical Draw',
        description: 'Add +10% chance to deal double damage.',
        color: const Color(0xFFFF1744),
        currentValue:
            'CURRENT ${(criticalStrikeChance * 100).toStringAsFixed(0)}%',
      ),
      if (maxChainLength < 6)
        UpgradeOption(
          type: UpgradeType.chainLength,
          title: 'Longer Chain',
          description: 'Add one more slash waypoint.',
          color: const Color(0xFF00E5FF),
          currentValue: 'CURRENT $maxChainLength',
        ),
      if (scrollEnergyGainMultiplier < 1.75)
        UpgradeOption(
          type: UpgradeType.scrollRecovery,
          title: 'Aerial Flow',
          description: 'Gain more energy from upward scroll.',
          color: const Color(0xFF00FFCC),
          currentValue:
              'CURRENT ${(scrollEnergyGainMultiplier * 100).round()}%',
        ),
      if (passiveDrainRate > 0.026)
        UpgradeOption(
          type: UpgradeType.energyEfficiency,
          title: 'Calm Breathing',
          description: 'Slow passive energy drain.',
          color: const Color(0xFFFFB020),
          currentValue:
              'CURRENT ${(passiveDrainRate * 100).toStringAsFixed(1)}',
        ),
      if (maxChainTime < 2.3)
        UpgradeOption(
          type: UpgradeType.focusTime,
          title: 'Focus Window',
          description: 'More time to finish a chain.',
          color: const Color(0xFFA855F7),
          currentValue: 'CURRENT ${maxChainTime.toStringAsFixed(2)}s',
        ),
      UpgradeOption(
        type: UpgradeType.luck,
        title: 'Luck',
        description: 'Reduce the bonus object spawn interval by 10%.',
        color: const Color(0xFFFFD166),
        currentValue: 'CURRENT 1 / $bonusSpawnInterval',
      ),
      if (shadowCloneLevel < 4)
        UpgradeOption(
          type: UpgradeType.shadowClone,
          title: 'Shadow Clone',
          description: 'Add one side clone to widen slash range.',
          color: const Color(0xFF38BDF8),
          currentValue: 'CURRENT $shadowCloneLevel / 4',
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
    return <UpgradeOption>[
      if (!shieldUnlocked)
        const UpgradeOption(
          type: UpgradeType.shield,
          title: 'Guard Seal',
          description: 'Block one collision hit.',
          color: Color(0xFFEAB308),
          isRare: true,
        ),
      if (!lightfootGaugeUnlocked)
        const UpgradeOption(
          type: UpgradeType.lightfootGauge,
          title: 'Lightfoot',
          description: 'Movement fills an ultimate gauge.',
          color: Color(0xFF22C55E),
          isRare: true,
        ),
      if (!chainStrikeUnlocked)
        const UpgradeOption(
          type: UpgradeType.chainStrike,
          title: 'Chain Strike',
          description: 'Damaged targets bounce into the next cut.',
          color: Color(0xFFF97316),
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
    children.whereType<FloatingObject>().forEach(
      (obj) => obj.removeFromParent(),
    );
    children.whereType<SlicedHalfComponent>().forEach(
      (obj) => obj.removeFromParent(),
    );
    children.whereType<SliceParticleEmitter>().forEach(
      (obj) => obj.removeFromParent(),
    );
    children.whereType<ExperienceShardEmitter>().forEach(
      (obj) => obj.removeFromParent(),
    );
    children.whereType<EnergyShard>().forEach((obj) => obj.removeFromParent());
    children.whereType<LaserBeamEffect>().forEach(
      (obj) => obj.removeFromParent(),
    );
    children.whereType<CriticalTextEffect>().forEach(
      (obj) => obj.removeFromParent(),
    );
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
        _achievementToastQueue.add(
          'ACHIEVEMENT UNLOCKED: ${achievement.title}',
        );
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
    const definitions = <UpgradeType, String>{
      UpgradeType.bladePower: 'Blade Power',
      UpgradeType.criticalStrike: 'Critical Draw',
      UpgradeType.chainLength: 'Longer Chain',
      UpgradeType.scrollRecovery: 'Aerial Flow',
      UpgradeType.energyEfficiency: 'Calm Breathing',
      UpgradeType.focusTime: 'Focus Window',
      UpgradeType.luck: 'Luck',
      UpgradeType.shadowClone: 'Shadow Clone',
      UpgradeType.shield: 'Guard Seal',
      UpgradeType.lightfootGauge: 'Lightfoot',
      UpgradeType.chainStrike: 'Chain Strike',
    };
    return definitions.entries
        .expand(
          (entry) => [
            Achievement(
              id: 'upgrade-${entry.key.name}-selected',
              title: '${entry.value} Selected',
              description: 'Choose this upgrade for the first time.',
              group: AchievementGroup.upgrade,
              unlocked: selectedUpgradeAchievements.contains(entry.key),
              progress: selectedUpgradeAchievements.contains(entry.key)
                  ? 1.0
                  : 0.0,
            ),
            Achievement(
              id: 'upgrade-${entry.key.name}-maxed',
              title: '${entry.value} Mastered',
              description: 'Reach the maximum state for this upgrade.',
              group: AchievementGroup.upgrade,
              unlocked: maxedUpgradeAchievements.contains(entry.key),
              progress: maxedUpgradeAchievements.contains(entry.key)
                  ? 1.0
                  : 0.0,
            ),
          ],
        )
        .toList(growable: false);
  }

  List<Achievement> _stageAchievements() {
    const levelTargets = [3, 5, 10, 15, 20];
    return levelTargets
        .map(
          (level) => Achievement(
            id: 'stage-$level',
            title: 'Stage $level Reached',
            description: 'Reach stage level $level.',
            group: AchievementGroup.stage,
            unlocked: bestStageLevel >= level,
            progress: (bestStageLevel / level).clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
  }

  List<Achievement> _characterAchievements() {
    const levelTargets = [3, 5, 10, 15, 20];
    return levelTargets
        .map(
          (level) => Achievement(
            id: 'character-$level',
            title: 'Character Level $level',
            description: 'Raise the character to level $level.',
            group: AchievementGroup.character,
            unlocked: bestCharacterLevel >= level,
            progress: (bestCharacterLevel / level).clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
  }

  List<Achievement> _scoreAchievements() {
    const thresholds = [1000, 3000, 5000, 10000, 20000, 50000];
    return thresholds
        .map(
          (scoreTarget) => Achievement(
            id: 'score-$scoreTarget',
            title: '$scoreTarget Score',
            description: 'Reach a score of $scoreTarget.',
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
      _updateEnergyShardsDuringUpgrade(adjustedDt);
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

  void _updateEnergyShardsDuringUpgrade(double dt) {
    for (final shard in children.whereType<EnergyShard>().toList()) {
      shard.update(dt);
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

// ==========================================
// UI Overlays (Flutter Widgets)
// ==========================================

class StartOverlay extends StatelessWidget {
  static const String homeBackgroundAsset =
      'assets/images/concepts/home_background.png';
  static const String homeTitleAsset =
      'assets/images/concepts/home_title_battoujutsu.png';

  final QuickDrawGame game;
  const StartOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(homeBackgroundAsset, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.36),
                  ],
                  stops: const [0.0, 0.52, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 74,
            left: 34,
            right: 34,
            child: Image.asset(homeTitleAsset, fit: BoxFit.contain),
          ),
          Align(
            alignment: const Alignment(0, 0.78),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 420,
                  height: 62,
                  child: ElevatedButton(
                    onPressed: () {
                      game.playSound(GameSound.uiConfirm);
                      game.startGame();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFCC),
                      foregroundColor: Colors.black,
                      shadowColor: const Color(0xFF00FFCC),
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'GAME START',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 420,
                  height: 62,
                  child: OutlinedButton(
                    onPressed: () {
                      game.playSound(GameSound.uiSelect);
                      game.showAchievements();
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.38),
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFFA29BFE),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'ACHIEVEMENTS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AchievementsOverlay extends StatelessWidget {
  final QuickDrawGame game;
  const AchievementsOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.achievementRevision,
      builder: (context, revision, child) {
        final achievements = game.achievementsForDisplay();
        final visibleAchievements = QuickDrawGame.visibleAchievementsFrom(
          achievements,
        );
        return _buildContent(context, achievements, visibleAchievements);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Achievement> achievements,
    List<Achievement> visibleAchievements,
  ) {
    final unlockedCount = achievements
        .where((achievement) => achievement.unlocked)
        .length;
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 54),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ACHIEVEMENTS',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: Color(0xFFA29BFE),
                      ),
                    ),
                  ),
                  Text(
                    '$unlockedCount / ${achievements.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00FFCC),
                    ),
                  ),
                  const SizedBox(width: 18),
                  IconButton(
                    onPressed: game.hideAchievements,
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _AchievementSection(
                        title: 'UPGRADES',
                        achievements: achievementsByGroup(
                          visibleAchievements,
                          AchievementGroup.upgrade,
                        ),
                      ),
                      _AchievementSection(
                        title: 'STAGE LEVEL',
                        achievements: achievementsByGroup(
                          visibleAchievements,
                          AchievementGroup.stage,
                        ),
                      ),
                      _AchievementSection(
                        title: 'CHARACTER LEVEL',
                        achievements: achievementsByGroup(
                          visibleAchievements,
                          AchievementGroup.character,
                        ),
                      ),
                      _AchievementSection(
                        title: 'SCORE',
                        achievements: achievementsByGroup(
                          visibleAchievements,
                          AchievementGroup.score,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<Achievement> achievementsByGroup(
    List<Achievement> achievements,
    AchievementGroup group,
  ) {
    return achievements
        .where((achievement) => achievement.group == group)
        .toList(growable: false);
  }
}

class _AchievementSection extends StatelessWidget {
  final String title;
  final List<Achievement> achievements;

  const _AchievementSection({required this.title, required this.achievements});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: Color(0xFF00FFCC),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final achievement in achievements)
                _AchievementTile(achievement: achievement),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;

  const _AchievementTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final accent = unlocked
        ? const Color(0xFFFFD166)
        : Colors.white.withValues(alpha: 0.28);
    return SizedBox(
      width: 220,
      height: 116,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: unlocked
              ? const Color(0xFF161A2A).withValues(alpha: 0.94)
              : const Color(0xFF101322).withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.75), width: 1.4),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    unlocked ? Icons.emoji_events : Icons.lock_outline,
                    size: 18,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      achievement.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: unlocked
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  achievement.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: Colors.white.withValues(alpha: 0.54),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: achievement.progress.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  final QuickDrawGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'DEFEATED',
              style: TextStyle(
                fontSize: 54,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
                color: const Color(0xFFFF2D55),
                shadows: [
                  Shadow(
                    color: const Color(0xFFFF2D55).withValues(alpha: 0.8),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'FINAL SCORE',
              style: TextStyle(
                fontSize: 16,
                letterSpacing: 2,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${game.score}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: game.startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                foregroundColor: Colors.white,
                shadowColor: const Color(0xFFFF2D55),
                elevation: 10,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'TRY AGAIN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpgradeOverlay extends StatefulWidget {
  final QuickDrawGame game;
  const UpgradeOverlay({super.key, required this.game});

  @override
  State<UpgradeOverlay> createState() => _UpgradeOverlayState();
}

class _UpgradeOverlayState extends State<UpgradeOverlay> {
  async_timer.Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    _lockTimer = async_timer.Timer.periodic(const Duration(milliseconds: 80), (
      _,
    ) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choices = widget.game.currentUpgradeChoices;
    final canChoose = widget.game.canChooseUpgrade;
    return SizedBox.expand(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 72),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LevelUpAnnouncement(
                    title: widget.game.levelUpAnnouncementTitle,
                    level: widget.game.levelUpAnnouncementLevel,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'UPGRADE',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 288,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < choices.length; i++) ...[
                          if (i > 0) const SizedBox(width: 18),
                          Expanded(
                            child: _UpgradeButton(
                              option: choices[i],
                              enabled: canChoose,
                              onPressed: () =>
                                  widget.game.chooseUpgrade(choices[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelUpAnnouncement extends StatelessWidget {
  final String title;
  final int level;

  const _LevelUpAnnouncement({required this.title, required this.level});

  @override
  Widget build(BuildContext context) {
    final isStageLevelUp = title == 'STAGE LEVEL UP';
    final accentColor = isStageLevelUp
        ? const Color(0xFFFF8A3D)
        : const Color(0xFFA29BFE);
    final levelColor = isStageLevelUp
        ? const Color(0xFFFFD166)
        : const Color(0xFFE9E5FF);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accentColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            shadows: [
              Shadow(color: accentColor.withValues(alpha: 0.8), blurRadius: 14),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'LEVEL $level',
          style: TextStyle(
            color: levelColor,
            fontSize: 54,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: accentColor.withValues(alpha: 0.55),
                blurRadius: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  final UpgradeOption option;
  final bool enabled;
  final VoidCallback onPressed;

  const _UpgradeButton({
    required this.option,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF101322).withValues(alpha: 0.94),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(
          0xFF101322,
        ).withValues(alpha: 0.94),
        disabledForegroundColor: Colors.white,
        elevation: 10,
        shadowColor: option.color.withValues(alpha: 0.45),
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 210),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: option.color.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconSize = min(
            constraints.maxWidth * 0.96,
            constraints.maxHeight * 0.70,
          );

          return Stack(
            children: [
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: option.color,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: option.color.withValues(alpha: 0.65),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 28,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox.square(
                    dimension: iconSize,
                    child: Image.asset(
                      option.iconAssetPath,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080B15).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: option.color.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (option.isRare)
                        Text(
                          'RARE',
                          style: TextStyle(
                            color: option.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        )
                      else if (option.currentValue != null)
                        Text(
                          option.currentValue!,
                          style: TextStyle(
                            color: option.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        option.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.18,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsIconButton extends StatelessWidget {
  final QuickDrawGame game;

  const _SettingsIconButton({required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Settings',
        child: IconButton(
          key: const ValueKey('settings-button'),
          onPressed: game.openSettings,
          icon: const Icon(Icons.settings),
          color: Colors.white,
          iconSize: 30,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF05060A).withValues(alpha: 0.58),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
            fixedSize: const Size(56, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsOverlay extends StatefulWidget {
  final QuickDrawGame game;

  const SettingsOverlay({super.key, required this.game});

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  void _setMasterVolume(double value) {
    setState(() {
      widget.game.setMasterVolume(value);
      widget.game.previewUiVolume();
    });
  }

  void _setBgmVolume(double value) {
    setState(() {
      widget.game.setBgmVolume(value);
      widget.game.previewUiVolume();
    });
  }

  void _setSfxVolume(double value) {
    setState(() {
      widget.game.setSfxVolume(value);
      widget.game.previewUiVolume();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.62),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              decoration: BoxDecoration(
                color: const Color(0xFF101322).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00FFCC).withValues(alpha: 0.34),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'SETTINGS',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('settings-close-button'),
                        tooltip: 'Close',
                        onPressed: widget.game.closeSettings,
                        icon: const Icon(Icons.close),
                        color: Colors.white70,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _VolumeSlider(
                    key: const ValueKey('master-volume-slider'),
                    label: 'MASTER',
                    value: widget.game.masterVolume,
                    accentColor: const Color(0xFF00FFCC),
                    onChanged: _setMasterVolume,
                  ),
                  const SizedBox(height: 14),
                  _VolumeSlider(
                    key: const ValueKey('bgm-volume-slider'),
                    label: 'BGM',
                    value: widget.game.bgmVolume,
                    accentColor: const Color(0xFFA29BFE),
                    onChanged: _setBgmVolume,
                  ),
                  const SizedBox(height: 14),
                  _VolumeSlider(
                    key: const ValueKey('sfx-volume-slider'),
                    label: 'SFX',
                    value: widget.game.sfxVolume,
                    accentColor: const Color(0xFFFFD166),
                    onChanged: _setSfxVolume,
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    key: const ValueKey('settings-home-button'),
                    onPressed: widget.game.returnHomeFromSettings,
                    icon: const Icon(Icons.home),
                    label: const Text('HOME'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: const Color(0xFFFF2D55).withValues(alpha: 0.78),
                        width: 1.4,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color accentColor;
  final ValueChanged<double> onChanged;

  const _VolumeSlider({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: accentColor,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accentColor,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
            thumbColor: Colors.white,
            overlayColor: accentColor.withValues(alpha: 0.18),
            trackHeight: 5,
          ),
          child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
        ),
      ],
    );
  }
}

class _AchievementToast extends StatelessWidget {
  final String message;

  const _AchievementToast({required this.message});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('achievement-toast'),
      decoration: BoxDecoration(
        color: const Color(0xFF05060A).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFD166).withValues(alpha: 0.78),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD166).withValues(alpha: 0.18),
            blurRadius: 18,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Text(
          message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFFD166),
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class HUDOverlay extends StatefulWidget {
  final QuickDrawGame game;
  const HUDOverlay({super.key, required this.game});

  @override
  State<HUDOverlay> createState() => _HUDOverlayState();
}

class _HUDOverlayState extends State<HUDOverlay> {
  static const int rareSkillSlotCount = 2;
  async_timer.Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateTimer = async_timer.Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              key: const ValueKey('hud-passive-layer'),
              child: Stack(
                children: [
                  _LowEnergyWarningOverlay(
                    intensity: widget.game.lowHealthWarningIntensity,
                  ),

                  // ── Top Bar: Score & Combo ──
                  Positioned(
                    top: 50,
                    left: 24,
                    right: 92,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Score
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SCORE',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.5,
                                color: Colors.white60,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.game.score}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                for (
                                  var i = 0;
                                  i < rareSkillSlotCount;
                                  i++
                                ) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  _buildRareSkillSlot(
                                    slotIndex: i,
                                    i < widget.game.acquiredRareUpgrades.length
                                        ? widget.game.acquiredRareUpgrades[i]
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        // Combo indicator
                        if (widget.game.combo > 0)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF00FFCC,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(
                                  0xFF00FFCC,
                                ).withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '${widget.game.combo} SLICES',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: const Color(0xFF00FFCC),
                                shadows: [
                                  Shadow(
                                    color: const Color(
                                      0xFF00FFCC,
                                    ).withValues(alpha: 0.8),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (widget.game.levelUpAnnouncementTimer > 0)
                    Positioned(
                      top: 178,
                      left: 24,
                      right: 24,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: widget.game.levelUpAnnouncementTimer > 0
                            ? 1
                            : 0,
                        child: _LevelUpAnnouncement(
                          title: widget.game.levelUpAnnouncementTitle,
                          level: widget.game.levelUpAnnouncementLevel,
                        ),
                      ),
                    ),

                  if (widget.game.achievementToastMessage != null)
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 116,
                      child: Center(
                        child: _AchievementToast(
                          message: widget.game.achievementToastMessage!,
                        ),
                      ),
                    ),

                  // ── Bottom-right vertical gauges ──
                  Positioned(
                    bottom: 32,
                    right: 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildVerticalGauge(
                          label: 'ENERGY',
                          value: widget.game.displayedEnergy,
                          gradientColors: widget.game.displayedEnergy < 0.25
                              ? [
                                  const Color(0xFFFF0055),
                                  const Color(0xFFFF5500),
                                ]
                              : [
                                  const Color(0xFFFF2D55),
                                  const Color(0xFF00FFCC),
                                ],
                          glowColor: widget.game.displayedEnergy < 0.25
                              ? const Color(0xFFFF0055)
                              : const Color(0xFF00FFCC),
                          icon: '⚡',
                        ),
                        const SizedBox(width: 10),
                        _buildVerticalGauge(
                          label: 'C.${widget.game.characterLevel}',
                          value: widget.game.experience.clamp(0.0, 1.0),
                          gradientColors: const [
                            Color(0xFF6C5CE7),
                            Color(0xFFA29BFE),
                          ],
                          glowColor: const Color(0xFFA29BFE),
                          icon: '✦',
                        ),
                        if (widget.game.lightfootGaugeUnlocked) ...[
                          const SizedBox(width: 10),
                          _buildVerticalGauge(
                            label: 'STEP',
                            value: widget.game.lightfootGauge.clamp(0.0, 1.0),
                            gradientColors: const [
                              Color(0xFF16A34A),
                              Color(0xFF86EFAC),
                            ],
                            glowColor: const Color(0xFF22C55E),
                            icon: '⇧',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 44,
            right: 24,
            child: _SettingsIconButton(game: widget.game),
          ),
        ],
      ),
    );
  }

  Widget _buildRareSkillSlot(
    UpgradeType? upgradeType, {
    required int slotIndex,
  }) {
    return Container(
      key: ValueKey('rare-skill-slot-$slotIndex'),
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFF05060A).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.12),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: upgradeType == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                upgradeType.iconAssetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
    );
  }

  Widget _buildVerticalGauge({
    required String label,
    required double value,
    required List<Color> gradientColors,
    required Color glowColor,
    required String icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: TextStyle(fontSize: 13, color: glowColor)),
        const SizedBox(height: 5),
        Container(
          width: 18,
          height: 132,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2135).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: glowColor.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: constraints.maxWidth,
                    height: constraints.maxHeight * value,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: gradientColors,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: glowColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _LowEnergyWarningOverlay extends StatelessWidget {
  final double intensity;

  const _LowEnergyWarningOverlay({required this.intensity});

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0) {
      return const SizedBox.shrink(key: ValueKey('low-energy-warning-off'));
    }
    return Positioned.fill(
      key: const ValueKey('low-energy-warning'),
      child: CustomPaint(painter: LowEnergyWarningPainter(intensity)),
    );
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
