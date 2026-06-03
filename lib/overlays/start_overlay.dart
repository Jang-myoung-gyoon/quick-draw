import 'package:flutter/material.dart';
import '../game/quick_draw_game.dart';
import 'friend_invite_dialog.dart';

class StartOverlay extends StatefulWidget {
  static const String homeBackgroundAsset =
      'assets/images/ui/home_background.png';
  static const String homeTitleAsset =
      'assets/images/ui/home_title_battoujutsu.png';

  final QuickDrawGame game;
  const StartOverlay({super.key, required this.game});

  @override
  State<StartOverlay> createState() => _StartOverlayState();
}

class _StartOverlayState extends State<StartOverlay> {
  bool _audioTriggered = false;

  @override
  void initState() {
    super.initState();
    widget.game.startHomeBgm();
  }

  void _handleInteraction() {
    if (!_audioTriggered) {
      _audioTriggered = true;
      widget.game.startHomeBgm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final t = game.text;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _handleInteraction(),
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                StartOverlay.homeBackgroundAsset,
                fit: BoxFit.cover,
              ),
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
              top: 44,
              left: 24,
              child: SizedBox(
                width: 76,
                height: 76,
                child: IconButton(
                  key: const ValueKey('home-community-button'),
                  tooltip: t.community,
                  onPressed: () {
                    game.playSound(GameSound.uiSelect);
                    game.showCommunity();
                  },
                  icon: const Icon(Icons.groups),
                  iconSize: 38,
                  color: const Color(0xFF00FFCC),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF05060A,
                    ).withValues(alpha: 0.68),
                    side: const BorderSide(color: Color(0xFF00FFCC), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 44,
              right: 24,
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('home-tutorial-button'),
                    tooltip: t.isKo ? '튜토리얼' : 'Tutorial',
                    onPressed: game.startTutorial,
                    icon: const Icon(Icons.help_outline),
                    iconSize: 30,
                    color: const Color(0xFFA29BFE),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF05060A,
                      ).withValues(alpha: 0.58),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                      fixedSize: const Size(56, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    key: const ValueKey('home-mute-button'),
                    tooltip: game.isMuted
                        ? (t.isKo ? '음소거 해제' : 'Unmute')
                        : (t.isKo ? '음소거' : 'Mute'),
                    onPressed: () {
                      setState(() {
                        game.toggleMute();
                      });
                    },
                    icon: Icon(
                      game.isMuted ? Icons.volume_off : Icons.volume_up,
                    ),
                    iconSize: 30,
                    color: game.isMuted
                        ? const Color(0xFFFF2D55)
                        : const Color(0xFF00FFCC),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF05060A,
                      ).withValues(alpha: 0.58),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                      fixedSize: const Size(56, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 560,
              left: 34,
              right: 34,
              child: Image.asset(
                StartOverlay.homeTitleAsset,
                fit: BoxFit.contain,
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.74),
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
                      child: Text(
                        t.gameStart,
                        style: const TextStyle(
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
                    child: OutlinedButton.icon(
                      key: const ValueKey('home-share-link-button'),
                      onPressed: () {
                        game.playSound(GameSound.uiSelect);
                        showFriendInviteDialog(context, game: game);
                      },
                      icon: const Icon(Icons.ios_share),
                      label: Text(t.shareLink),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.38),
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xFF00FFCC),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
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
                      key: const ValueKey('home-ranking-button'),
                      onPressed: () {
                        game.playSound(GameSound.uiSelect);
                        game.showRanking();
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.38),
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xFFFFD166),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        t.ranking,
                        style: const TextStyle(
                          fontSize: 18,
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
                      child: Text(
                        t.achievements,
                        style: const TextStyle(
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
      ),
    );
  }
}
