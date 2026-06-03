import 'package:flutter/material.dart';

import '../game/quick_draw_game.dart';

class CommunityOverlay extends StatefulWidget {
  const CommunityOverlay({super.key, required this.game});

  final QuickDrawGame game;

  @override
  State<CommunityOverlay> createState() => _CommunityOverlayState();
}

class _CommunityOverlayState extends State<CommunityOverlay> {
  bool _isSigningIn = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final t = game.text;
    final uid = game.currentUserIdForRanking ?? '-';
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF101522).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00FFCC).withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.community,
                            style: const TextStyle(
                              color: Color(0xFF00FFCC),
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('community-close-button'),
                          tooltip: t.close,
                          onPressed: game.hideCommunity,
                          icon: const Icon(Icons.close),
                          iconSize: 30,
                          color: Colors.white,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                            fixedSize: const Size(52, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _IdPanel(label: t.myUniqueId, uid: uid),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: OutlinedButton.icon(
                        key: const ValueKey('community-google-login-button'),
                        onPressed: _isSigningIn ? null : _signIn,
                        icon: _isSigningIn
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00FFCC),
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(t.googleLogin),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white.withValues(
                            alpha: 0.55,
                          ),
                          side: const BorderSide(
                            color: Color(0xFF00FFCC),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        key: const ValueKey('community-friend-list-button'),
                        onPressed: () {
                          game.playSound(GameSound.uiSelect);
                          game.showFriends();
                        },
                        icon: const Icon(Icons.groups),
                        label: Text(t.friendList),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FFCC),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    final game = widget.game;
    game.playSound(GameSound.uiSelect);
    setState(() {
      _isSigningIn = true;
      _message = null;
    });
    try {
      await game.signInWithGoogleAndSyncProgress();
      _message = game.text.isKo
          ? 'Google 로그인 화면으로 이동합니다.'
          : 'Opening Google sign-in.';
    } catch (_) {
      _message = game.text.isKo ? 'Google 로그인 실패' : 'Google sign-in failed';
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }
}

class _IdPanel extends StatelessWidget {
  const _IdPanel({required this.label, required this.uid});

  final String label;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            uid,
            maxLines: 2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
