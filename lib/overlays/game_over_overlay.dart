import 'package:flutter/material.dart';
import '../game/quick_draw_game.dart';

class GameOverOverlay extends StatelessWidget {
  final QuickDrawGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final t = game.text;
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t.defeated,
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
              t.finalScore,
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
              child: Text(
                t.tryAgain,
                style: const TextStyle(
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
