import 'dart:async' as async_timer;
import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components/background.dart';
import 'components/effects.dart';
import 'components/player.dart';
import 'components/target.dart';

void main() {
  runApp(const MyGameApp());
}

enum UpgradeType {
  bladePower,
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

extension UpgradeTypeIconAsset on UpgradeType {
  String get iconAssetPath => switch (this) {
    UpgradeType.bladePower => 'assets/images/icons/upgrades/blade_power.png',
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

class _GamePageState extends State<GamePage> {
  static const double _mobileViewportWidth = 780.0;
  static const double _mobileViewportHeight = 1688.0;

  late QuickDrawGame _game;

  @override
  void initState() {
    super.initState();
    _game = QuickDrawGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    'StartScreen': (context, game) => StartOverlay(game: game),
                    'GameOverScreen': (context, game) =>
                        GameOverOverlay(game: game),
                    'HUD': (context, game) => HUDOverlay(game: game),
                    'UpgradeScreen': (context, game) =>
                        UpgradeOverlay(game: game),
                  },
                  initialActiveOverlays: const ['StartScreen'],
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
  FallingBackground? background;
  late PlayerComponent player;

  // Game states
  bool isPlaying = false;
  bool isGameOver = false;
  bool isChoosingUpgrade = false;
  int score = 0;
  int combo = 0;

  // Health Gauge (0.0 to 1.0)
  double health = 1.0;
  final double maxHealth = 1.0;
  double passiveDrainRate = 0.045; // Drains fully in ~22 seconds if idle

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
  final List<UpgradeType> acquiredRareUpgrades = [];
  int _pendingExperienceHits = 0;

  // Chain variables (now using raw screen coordinates instead of targets)
  final List<Vector2> currentChainPoints = [];
  SlashPathLine? activePathLine;
  double chainTimer = 0.0;
  double maxChainTime = 1.5; // 1.5s to complete chain after first selection
  int maxChainLength = 1;
  double inputDrainMultiplier = 1.0;

  // Spawning variables
  double totalAltitude = 0.0; // Total distance climbed
  static const int baseFloatingObjects = 9;
  static const int maxFloatingObjects = 20;
  static const double _spawnInset = 48.0;
  static const double _replacementSpawnEdgeBand = 72.0;
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

  int get experienceRequiredForCharacterLevel => 3 + characterLevel * 2;
  int get turnsRequiredForNextStage => min(8, 4 + stageLevel);
  double get bonusSpawnChance => 0.01 + luckLevel * 0.005;

  @visibleForTesting
  double obstacleSpawnChanceForStage(int level) {
    if (level < 2) return 0;
    return min(0.50, (level - 1) * 0.10);
  }

  final Random random = Random();
  Vector2 _lastCameraShift = Vector2(0, 1);
  static const int maxRareUpgradeCount = 3;
  static const double rareUpgradeChance = 0.3;
  static const double lightfootGaugeDistance = 16000.0;
  double _replacementSpawnBudget = 0.0;

  // Screen shake
  double shakeIntensity = 0.0;
  double get lowHealthWarningIntensity {
    const threshold = 0.2;
    if (health > threshold) {
      return 0.0;
    }
    return ((threshold - health) / threshold).clamp(0.0, 1.0);
  }

  // Slow motion factor when chaining targets (bullet time)
  double get speedMultiplier =>
      (currentChainPoints.isNotEmpty && !player.isDashing) ? 0.25 : 1.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. Background
    background = FallingBackground();
    add(background!);

    // 2. Player
    player = PlayerComponent();
    add(player);
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
    passiveDrainRate = 0.045;
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
    acquiredRareUpgrades.clear();
    _pendingExperienceHits = 0;
    totalAltitude = 0.0;
    _replacementSpawnBudget = 0.0;
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

    overlays.remove('StartScreen');
    overlays.remove('GameOverScreen');
    overlays.remove('UpgradeScreen');
    overlays.add('HUD');

    // Spawn initial objects scattered across the screen
    _spawnInitialObjects();
  }

  void gameOver() {
    isPlaying = false;
    isGameOver = true;
    isChoosingUpgrade = false;
    currentChainPoints.clear();
    _removePathLine();

    overlays.remove('HUD');
    overlays.remove('UpgradeScreen');
    overlays.add('GameOverScreen');
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
    }

    // Reset timer on tap
    chainTimer = 0.0;

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
    score += 100 + (combo * 10);
    combo++;
    shakeIntensity = min(shakeIntensity + 10.0, 25.0);
    if (target != null) {
      _pendingExperienceHits += target.requiredHits;
      _spawnExperienceShards(hitPoint, target.requiredHits);
    }
  }

  void onInputTurnCompleted() {
    if (!isPlaying || isChoosingUpgrade) return;

    inputTurnsThisStage++;
    if (inputTurnsThisStage >= turnsRequiredForNextStage) {
      _advanceStageLevel();
    }
  }

  void _gainExperienceForRemovedHits(int requiredHits) {
    if (!isPlaying || isChoosingUpgrade) {
      return;
    }
    experience += requiredHits / experienceRequiredForCharacterLevel;
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

  void _spawnExperienceShards(Vector2 origin, int requiredHits) {
    add(
      ExperienceShardEmitter(
        origins: _experienceShardOrigins(origin, requiredHits),
        burstDirection: -player.experienceShardBurstDirection,
      ),
    );
  }

  List<Vector2> _experienceShardOrigins(Vector2 origin, int requiredHits) {
    final origins = <Vector2>[];
    final shardCount = min(8, max(2, requiredHits + 1));
    for (var i = 0; i < shardCount; i++) {
      final angle = (i / shardCount) * pi * 2;
      origins.add(origin + Vector2(cos(angle), sin(angle)) * 14.0);
    }
    return origins;
  }

  void _advanceCharacterLevel() {
    characterLevel++;
    levelUpAnnouncementLevel = characterLevel;
    levelUpAnnouncementTitle = 'CHARACTER LEVEL UP';
    levelUpAnnouncementTimer = 2.4;
    experience = 0.0;
    _offerUpgradeChoices();
  }

  void _advanceStageLevel() {
    stageLevel++;
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
        description: 'Bonus object spawn chance +0.5%.',
        color: const Color(0xFFFFD166),
        currentValue: 'CURRENT ${(bonusSpawnChance * 100).toStringAsFixed(1)}%',
      ),
    ];

    options.sort((a, b) => _upgradePriority(b).compareTo(_upgradePriority(a)));
    final choices = options.take(3).toList(growable: true);
    final rare = _rollRareUpgrade();
    if (rare != null && choices.isNotEmpty) {
      final replaceIndex = choices.lastIndexWhere(
        (choice) => choice.type != UpgradeType.bladePower,
      );
      if (replaceIndex >= 0) {
        choices[replaceIndex] = rare;
      }
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
      if (shadowCloneLevel == 0)
        const UpgradeOption(
          type: UpgradeType.shadowClone,
          title: 'Shadow Clone',
          description: 'Side clones widen slash range.',
          color: Color(0xFF38BDF8),
          isRare: true,
        ),
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

  int _upgradePriority(UpgradeOption option) {
    switch (option.type) {
      case UpgradeType.bladePower:
        return children.whereType<SlashTarget>().any(
              (target) => target.armor > 1,
            )
            ? 100
            : 70;
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
      case UpgradeType.shield:
      case UpgradeType.lightfootGauge:
      case UpgradeType.chainStrike:
        return 80;
    }
  }

  void chooseUpgrade(UpgradeOption option) {
    switch (option.type) {
      case UpgradeType.bladePower:
        playerAttackPower++;
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
        shadowCloneLevel++;
        rareUpgradeCount++;
        _recordRareUpgrade(option.type);
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
    isChoosingUpgrade = false;
    overlays.remove('UpgradeScreen');
    _updateChainHighlighting();
  }

  void _recordRareUpgrade(UpgradeType type) {
    if (!acquiredRareUpgrades.contains(type)) {
      acquiredRareUpgrades.add(type);
    }
  }

  bool triggerObstacleHit(Vector2 hitPos) {
    resetChain();

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

  void rechargeEnergyFromScroll(double scrolledPixels) {
    if (scrolledPixels <= 0) {
      return;
    }
    health = min(
      maxHealth,
      health + energyRechargeForScroll(scrolledPixels, player.baseY),
    );
  }

  double energyRechargeForScroll(
    double scrolledPixels,
    double referenceHeight,
  ) {
    if (scrolledPixels <= 0 || referenceHeight <= 0) {
      return 0.0;
    }
    const baseGain = 0.025;
    const maxScrollGain = 0.125;
    final normalizedScroll = (scrolledPixels / referenceHeight).clamp(0.0, 1.0);
    return (baseGain + maxScrollGain * normalizedScroll) *
        scrollEnergyGainMultiplier;
  }

  /// Called every frame while the camera follows the player after a dash.
  void shiftWorldForCamera(Vector2 delta) {
    if (delta.length2 > 0) {
      _lastCameraShift = delta.clone();
      _addReplacementSpawnBudget(delta.length);
    }
    addLightfootDistance(delta.length);
    rechargeEnergyFromScroll(max(0.0, delta.y));

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

    // Background scroll boost
    final bg = background;
    if (bg != null) {
      bg.applyScrollBoost(delta);
    }
  }

  @override
  void update(double dt) {
    // Screen shake decay
    if (shakeIntensity > 0) {
      shakeIntensity = max(0.0, shakeIntensity - dt * 50.0);
    }
    if (levelUpAnnouncementTimer > 0) {
      levelUpAnnouncementTimer = max(0.0, levelUpAnnouncementTimer - dt);
    }

    if (isChoosingUpgrade) return;

    // Apply speed multiplier (time dilation)
    final double adjustedDt = dt * speedMultiplier;
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

    _maintainFloatingObjectCount();
  }

  /// Spawn initial objects scattered across the upper portion of the screen
  void _spawnInitialObjects() {
    for (int i = 0; i < targetFloatingObjectCount; i++) {
      final double xPos = 40.0 + random.nextDouble() * (size.x - 80.0);
      final double yPos = 80.0 + random.nextDouble() * (size.y * 0.62);
      _spawnSingleObject(xPos, yPos);
    }
  }

  void _maintainFloatingObjectCount() {
    if (!isPlaying) return;

    final visibleObjects = children
        .whereType<FloatingObject>()
        .where(isFloatingObjectVisible)
        .toList();
    final missing = missingVisibleFloatingObjectCount(visibleObjects);
    final spawnCount = min(missing, _replacementSpawnBudget.floor());
    for (int i = 0; i < spawnCount; i++) {
      final spawned = _spawnReplacementObject(visibleObjects);
      visibleObjects.add(spawned);
      _replacementSpawnBudget -= 1.0;
    }
  }

  void _addReplacementSpawnBudget(double scrolledPixels) {
    if (scrolledPixels <= 0) {
      return;
    }
    _replacementSpawnBudget = min(
      targetFloatingObjectCount.toDouble(),
      _replacementSpawnBudget +
          scrolledPixels / replacementSpawnPixelsPerObject,
    );
  }

  @visibleForTesting
  double replacementSpawnBudgetForTest() => _replacementSpawnBudget;

  @visibleForTesting
  void addReplacementSpawnBudgetForTest(double scrolledPixels) {
    _addReplacementSpawnBudget(scrolledPixels);
  }

  @visibleForTesting
  void maintainFloatingObjectCountForTest() {
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
        return Vector2(x, _randomInRange(_spawnInset, size.y - _spawnInset));
      }

      final enteringFromTop = cameraShift.y >= 0;
      final y = enteringFromTop
          ? _randomInRange(_spawnInset, _spawnInset + edgeBand)
          : _randomInRange(
              size.y - _spawnInset - edgeBand,
              size.y - _spawnInset,
            );
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
      final target = SlashTarget(armor: 1, requiredHits: 1)
        ..position = Vector2(x, y);
      add(target);
      _updateChainHighlighting();
      return target;
    }

    final roll = random.nextDouble();
    final bonusChance = bonusSpawnChance;
    if (stageLevel >= 2 && roll < bonusChance) {
      final bonus = BonusTarget()..position = Vector2(x, y);
      add(bonus);
      _updateChainHighlighting();
      return bonus;
    }

    final obstacleChance = obstacleSpawnChanceForStage(stageLevel);
    if (roll < bonusChance + obstacleChance) {
      final obstacle = ObstacleTarget()..position = Vector2(x, y);
      add(obstacle);
      _updateChainHighlighting();
      return obstacle;
    } else {
      final maxArmor = min(4, 1 + (stageLevel - 1) ~/ 2);
      final maxRequiredHits = min(4, 1 + (stageLevel - 1) ~/ 2);
      final target = SlashTarget(
        armor: 1 + random.nextInt(maxArmor),
        requiredHits: 1 + random.nextInt(maxRequiredHits),
      )..position = Vector2(x, y);
      add(target);
      _updateChainHighlighting();
      return target;
    }
  }

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
  }

  void _renderLowHealthWarning(Canvas canvas) {
    final intensity = lowHealthWarningIntensity;
    if (intensity <= 0) {
      return;
    }

    final rect = Offset.zero & Size(size.x, size.y);
    final center = Offset(size.x / 2, size.y / 2);
    final edgeOpacity = 0.16 + intensity * 0.38;
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.82,
        colors: [
          Colors.transparent,
          const Color(0xFFFF003C).withValues(alpha: edgeOpacity * 0.18),
          const Color(0xFFFF003C).withValues(alpha: edgeOpacity),
        ],
        stops: const [0.54, 0.78, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.length));

    canvas.drawRect(rect, paint);
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
  final QuickDrawGame game;
  const StartOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cyber Title
            Text(
              'BATTOUJUTSU',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: const Color(0xFF00FFCC),
                shadows: [
                  Shadow(
                    color: const Color(0xFF00FFCC).withValues(alpha: 0.6),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'FALLING SLASHER',
              style: TextStyle(
                fontSize: 18,
                letterSpacing: 4,
                color: const Color(0xFFFF2D55),
                shadows: [
                  Shadow(
                    color: const Color(0xFFFF2D55).withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            // Tutorial Instructions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2135).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E2135)),
              ),
              child: const Column(
                children: [
                  Text(
                    'HOW TO PLAY',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '1. Tap ANYWHERE on the screen (up to 4 taps) to draw a path.\n'
                    '2. Entering target mode slows down time.\n'
                    '3. Slicing targets RECHARGES your decaying energy. Higher air slices recharge more!\n'
                    '4. Avoid orange spiked obstacles. Hitting them stops your dash and costs 30% energy.',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            // Play Button
            ElevatedButton(
              onPressed: game.startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFCC),
                foregroundColor: Colors.black,
                shadowColor: const Color(0xFF00FFCC),
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
                'TAP TO SLICE',
                style: TextStyle(
                  fontSize: 20,
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

class UpgradeOverlay extends StatelessWidget {
  final QuickDrawGame game;
  const UpgradeOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final choices = game.currentUpgradeChoices;
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
                    title: game.levelUpAnnouncementTitle,
                    level: game.levelUpAnnouncementLevel,
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
                              onPressed: () => game.chooseUpgrade(choices[i]),
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
  final VoidCallback onPressed;

  const _UpgradeButton({required this.option, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF101322).withValues(alpha: 0.94),
        foregroundColor: Colors.white,
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
      child: IgnorePointer(
        child: Stack(
          children: [
            // ── Top Bar: Score & Combo ──
            Positioned(
              top: 50,
              left: 24,
              right: 24,
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
                          for (var i = 0; i < rareSkillSlotCount; i++) ...[
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
                        color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00FFCC).withValues(alpha: 0.5),
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
                  opacity: widget.game.levelUpAnnouncementTimer > 0 ? 1 : 0,
                  child: _LevelUpAnnouncement(
                    title: widget.game.levelUpAnnouncementTitle,
                    level: widget.game.levelUpAnnouncementLevel,
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
                    value: widget.game.health.clamp(0.0, 1.0),
                    gradientColors: widget.game.health < 0.25
                        ? [const Color(0xFFFF0055), const Color(0xFFFF5500)]
                        : [const Color(0xFFFF2D55), const Color(0xFF00FFCC)],
                    glowColor: widget.game.health < 0.25
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
