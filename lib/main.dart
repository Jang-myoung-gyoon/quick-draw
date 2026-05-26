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

class MyGameApp extends StatelessWidget {
  const MyGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battoujutsu Slasher',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
      ),
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
  late QuickDrawGame _game;

  @override
  void initState() {
    super.initState();
    _game = QuickDrawGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<QuickDrawGame>(
        game: _game,
        overlayBuilderMap: {
          'StartScreen': (context, game) => StartOverlay(game: game),
          'GameOverScreen': (context, game) => GameOverOverlay(game: game),
          'HUD': (context, game) => HUDOverlay(game: game),
        },
        initialActiveOverlays: const ['StartScreen'],
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
  int score = 0;
  int combo = 0;
  int health = 3;
  final int maxHealth = 3;
  
  // Chain variables
  final List<SlashTarget> currentChain = [];
  SlashPathLine? activePathLine;
  double chainTimer = 0.0;
  final double maxChainTime = 1.5; // 1.5s to complete chain after first selection
  final int maxChainLength = 4;
  
  // Spawning variables
  double spawnTimer = 0.0;
  double spawnInterval = 1.0;
  final Random random = Random();
  
  // Screen shake
  double shakeIntensity = 0.0;
  
  // Slow motion factor when chaining targets (bullet time)
  double get speedMultiplier => (currentChain.isNotEmpty && !player.isDashing) ? 0.25 : 1.0;

  QuickDrawGame() {
    // Enable debug mode or priority settings if needed
  }

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
    // Reset state
    score = 0;
    combo = 0;
    health = maxHealth;
    isGameOver = false;
    isPlaying = true;
    
    currentChain.clear();
    _removePathLine();
    
    // Clear any existing targets/obstacles
    children.whereType<FloatingObject>().forEach((obj) => obj.removeFromParent());
    children.whereType<SlicedHalfComponent>().forEach((obj) => obj.removeFromParent());
    children.whereType<SliceParticleEmitter>().forEach((obj) => obj.removeFromParent());

    player.resetToBasePosition();

    // Configure overlays
    overlays.remove('StartScreen');
    overlays.remove('GameOverScreen');
    overlays.add('HUD');
  }

  void gameOver() {
    isPlaying = false;
    isGameOver = true;
    currentChain.clear();
    _removePathLine();

    overlays.remove('HUD');
    overlays.add('GameOverScreen');
  }

  // Chain Management
  void addToChain(SlashTarget target) {
    if (currentChain.length >= maxChainLength || player.isDashing) return;

    currentChain.add(target);
    target.isTargeted = true;
    target.chainIndex = currentChain.length - 1;

    // Reset timer on tap
    chainTimer = 0.0;

    // Redraw preview line
    _removePathLine();
    activePathLine = SlashPathLine(targets: currentChain);
    add(activePathLine!);

    // Start dash immediately if chain limit reached
    if (currentChain.length == maxChainLength) {
      _executeChainSlash();
    }
  }

  void _executeChainSlash() {
    if (currentChain.isEmpty) return;
    
    player.startChainDash(currentChain);
    currentChain.clear();
    _removePathLine();
  }

  void resetChain() {
    for (final target in currentChain) {
      target.isTargeted = false;
      target.chainIndex = -1;
    }
    currentChain.clear();
    _removePathLine();
    combo = 0;
  }

  void _removePathLine() {
    if (activePathLine != null) {
      activePathLine!.removeFromParent();
      activePathLine = null;
    }
  }

  // Game Logic Triggered by Components
  void triggerTargetSliced() {
    score += 100 + (combo * 10);
    combo++;
    shakeIntensity = min(shakeIntensity + 10.0, 25.0);
  }

  void triggerObstacleHit(Vector2 hitPos) {
    resetChain();
    health--;
    shakeIntensity = 25.0; // Strong screen shake
    
    spawnSliceParticles(hitPos, const Color(0xFFFF5500)); // Orange sparks
    
    if (health <= 0) {
      gameOver();
    }
  }

  void spawnSliceParticles(Vector2 position, Color color) {
    add(SliceParticleEmitter(position: position, color: color));
  }

  @override
  void update(double dt) {
    // Screen shake decay
    if (shakeIntensity > 0) {
      shakeIntensity = max(0.0, shakeIntensity - dt * 50.0);
    }

    // Apply speed multiplier (time dilation)
    final double adjustedDt = dt * speedMultiplier;
    super.update(adjustedDt);

    if (!isPlaying) return;

    // Handle chain expiration timer
    if (currentChain.isNotEmpty && !player.isDashing) {
      chainTimer += dt; // use real time for timer so bullet time doesn't freeze it
      if (chainTimer >= maxChainTime) {
        _executeChainSlash();
      }
    }

    // Spawning logic
    spawnTimer += adjustedDt;
    if (spawnTimer >= spawnInterval) {
      spawnTimer = 0.0;
      _spawnRandomObject();
    }
  }

  void _spawnRandomObject() {
    final double xPos = 40.0 + random.nextDouble() * (size.x - 80.0);
    
    // 75% target, 25% obstacle
    if (random.nextDouble() < 0.75) {
      final target = SlashTarget()
        ..position = Vector2(xPos, -40.0);
      add(target);
    } else {
      final obstacle = ObstacleTarget()
        ..position = Vector2(xPos, -40.0);
      add(obstacle);
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
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // No keyboard movement in final game (tap/drag focus only), handled by gesture
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
      color: Colors.black.withOpacity(0.85),
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
                    color: const Color(0xFF00FFCC).withOpacity(0.6),
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
                    color: const Color(0xFFFF2D55).withOpacity(0.6),
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
                color: const Color(0xFF1E2135).withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E2135)),
              ),
              child: const Column(
                children: [
                  Text(
                    'HOW TO PLAY',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '1. Tap 3-4 cyan targets in quick succession.\n'
                    '2. Player enters "Slow Motion" while targeting.\n'
                    '3. Player will dash and slice targets sequentially.\n'
                    '4. Avoid orange obstacles (tapping or hitting them hurts!).',
                    textAlign: TextAlign.left,
                    style: TextStyle(fontSize: 14, color: Colors.white54, height: 1.5),
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
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'TAP TO SLICE',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
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
      color: Colors.black.withOpacity(0.9),
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
                    color: const Color(0xFFFF2D55).withOpacity(0.8),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'FINAL SCORE',
              style: TextStyle(fontSize: 16, letterSpacing: 2, color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 8),
            Text(
              '${game.score}',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: game.startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                foregroundColor: Colors.white,
                shadowColor: const Color(0xFFFF2D55),
                elevation: 10,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'TRY AGAIN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ),
          ],
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
  async_timer.Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateTimer = async_timer.Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {});
      }
    });
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // HUD Header (Score & Health)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SCORE',
                        style: TextStyle(fontSize: 12, letterSpacing: 1.5, color: Colors.white60),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.game.score}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  // Health (Hearts)
                  Row(
                    children: List.generate(widget.game.maxHealth, (index) {
                      final bool active = index < widget.game.health;
                      return Icon(
                        active ? Icons.favorite : Icons.favorite_border,
                        color: active ? const Color(0xFFFF2D55) : Colors.white24,
                        size: 28,
                      );
                    }),
                  ),
                ],
              ),
              // HUD Footer (Combo Multiplier)
              if (widget.game.combo > 0)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFCC).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00FFCC).withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '${widget.game.combo} SLICES',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: const Color(0xFF00FFCC),
                      shadows: [
                        Shadow(
                          color: const Color(0xFF00FFCC).withOpacity(0.8),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
