import 'dart:async' as async_timer;
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/quick_draw_game.dart';
import 'overlays/achievements_overlay.dart';
import 'overlays/community_overlay.dart';
import 'overlays/friends_overlay.dart';
import 'overlays/game_over_overlay.dart';
import 'overlays/hud_overlay.dart';
import 'overlays/ranking_overlay.dart';
import 'overlays/settings_overlay.dart';
import 'overlays/start_overlay.dart';
import 'overlays/upgrade_overlay.dart';
import 'services/firebase_game_progress_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FirebaseGameProgressSync.instance.initialize();
  } catch (_) {
    // Firebase setup should not prevent the local web game from opening.
  }
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

class MyGameApp extends StatelessWidget {
  const MyGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: const GameText(GameLanguage.ko).appTitle,
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
  Future<void>? _startupAssetPreload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = QuickDrawGame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startupAssetPreload ??= _preloadStartupAssets();
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
      child: FutureBuilder<void>(
        future: _startupAssetPreload,
        builder: (context, snapshot) {
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
                      child: snapshot.connectionState == ConnectionState.done
                          ? GameWidget<QuickDrawGame>(
                              game: _game,
                              overlayBuilderMap: {
                                'StartScreen': (context, game) =>
                                    StartOverlay(game: game),
                                'GameOverScreen': (context, game) =>
                                    GameOverOverlay(game: game),
                                'HUD': (context, game) =>
                                    HUDOverlay(game: game),
                                'UpgradeScreen': (context, game) =>
                                    UpgradeOverlay(game: game),
                                'AchievementsScreen': (context, game) =>
                                    AchievementsOverlay(game: game),
                                'RankingScreen': (context, game) =>
                                    RankingOverlay(game: game),
                                'CommunityScreen': (context, game) =>
                                    CommunityOverlay(game: game),
                                'FriendsScreen': (context, game) =>
                                    FriendsOverlay(game: game),
                                'SettingsScreen': (context, game) =>
                                    SettingsOverlay(game: game),
                              },
                              initialActiveOverlays: const ['StartScreen'],
                            )
                          : const _InitialLoadingScreen(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _preloadStartupAssets() async {
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
    if (isTest) {
      return;
    }
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    if (!mounted) {
      return;
    }
    final imageAssets = manifest
        .listAssets()
        .where(_isGameImageAsset)
        .toList(growable: false);
    final audioAssets = manifest
        .listAssets()
        .where(_isGameAudioAsset)
        .toList(growable: false);

    await Future.wait([
      Future<void>.delayed(const Duration(seconds: 2)),
      _preloadFlutterImages(imageAssets),
      _game.images.loadAll([
        for (final assetPath in imageAssets)
          assetPath.replaceFirst('assets/images/', ''),
      ]),
      _preloadAudioAssets(audioAssets),
    ]);
  }

  Future<void> _preloadFlutterImages(List<String> imageAssets) {
    return Future.wait([
      for (final assetPath in imageAssets)
        precacheImage(AssetImage(assetPath), context),
    ]);
  }

  Future<void> _preloadAudioAssets(List<String> audioAssets) async {
    try {
      await FlameAudio.audioCache.loadAll([
        for (final assetPath in audioAssets)
          assetPath.replaceFirst('assets/audio/', ''),
      ]);
    } catch (_) {
      // Audio preloading should not prevent the game from opening.
    }
  }

  static bool _isGameImageAsset(String assetPath) {
    if (!assetPath.startsWith('assets/images/')) {
      return false;
    }
    final lower = assetPath.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }

  static bool _isGameAudioAsset(String assetPath) {
    if (!assetPath.startsWith('assets/audio/')) {
      return false;
    }
    final lower = assetPath.toLowerCase();
    return lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg');
  }
}

class _InitialLoadingScreen extends StatefulWidget {
  static const String loadingArtAsset = 'assets/images/ui/loading_chase.png';

  const _InitialLoadingScreen();

  @override
  State<_InitialLoadingScreen> createState() => _InitialLoadingScreenState();
}

class _InitialLoadingScreenState extends State<_InitialLoadingScreen> {
  bool _floatForward = true;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF102E46), Color(0xFF061424), Color(0xFF000104)],
        ),
      ),
      child: CustomPaint(
        painter: const _LoadingSpacePainter(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: _floatForward ? -1.0 : 1.0,
                  end: _floatForward ? 1.0 : -1.0,
                ),
                duration: const Duration(milliseconds: 1550),
                curve: Curves.easeInOut,
                onEnd: () {
                  if (mounted) {
                    setState(() => _floatForward = !_floatForward);
                  }
                },
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, value * 18),
                    child: Transform.rotate(angle: value * 0.025, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 54),
                  child: Image.asset(
                    _InitialLoadingScreen.loadingArtAsset,
                    width: 650,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const Align(
              alignment: Alignment(0, 0.58),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 5,
                      color: Color(0xFF00FFCC),
                    ),
                  ),
                  SizedBox(height: 28),
                  Text(
                    '로딩중',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '이미지와 사운드를 준비하고 있습니다',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingSpacePainter extends CustomPainter {
  const _LoadingSpacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final particlePaint = Paint()..style = PaintingStyle.fill;
    const particles = <({double x, double y, double radius, double alpha})>[
      (x: 0.12, y: 0.16, radius: 1.6, alpha: 0.36),
      (x: 0.22, y: 0.34, radius: 2.4, alpha: 0.22),
      (x: 0.32, y: 0.12, radius: 1.2, alpha: 0.30),
      (x: 0.48, y: 0.24, radius: 2.0, alpha: 0.25),
      (x: 0.62, y: 0.15, radius: 1.5, alpha: 0.34),
      (x: 0.76, y: 0.31, radius: 2.2, alpha: 0.24),
      (x: 0.88, y: 0.18, radius: 1.4, alpha: 0.32),
      (x: 0.16, y: 0.72, radius: 2.1, alpha: 0.20),
      (x: 0.38, y: 0.82, radius: 1.3, alpha: 0.28),
      (x: 0.58, y: 0.76, radius: 1.8, alpha: 0.22),
      (x: 0.82, y: 0.68, radius: 2.5, alpha: 0.20),
    ];
    for (final particle in particles) {
      particlePaint.color = const Color(
        0xFF8EDCFF,
      ).withValues(alpha: particle.alpha);
      canvas.drawCircle(
        Offset(size.width * particle.x, size.height * particle.y),
        particle.radius,
        particlePaint,
      );
    }

    final glowPaint = Paint()
      ..color = const Color(0xFF00FFCC).withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.42),
      size.width * 0.28,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoadingSpacePainter oldDelegate) => false;
}
