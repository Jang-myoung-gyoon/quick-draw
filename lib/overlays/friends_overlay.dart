import 'package:flutter/material.dart';

import '../game/quick_draw_game.dart';
import '../services/friend_community.dart';
import 'profile_avatar.dart';

class FriendsOverlay extends StatefulWidget {
  const FriendsOverlay({super.key, required this.game});

  final QuickDrawGame game;

  @override
  State<FriendsOverlay> createState() => _FriendsOverlayState();
}

class _FriendsOverlayState extends State<FriendsOverlay> {
  final TextEditingController _friendUidController = TextEditingController();
  Future<FriendCommunitySnapshot>? _communityLoad;
  bool _isSendingRequest = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _communityLoad = widget.game.loadCommunitySnapshot();
  }

  @override
  void dispose() {
    _friendUidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final t = game.text;
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.friendList,
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Color(0xFF00FFCC),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('friends-close-button'),
                        tooltip: t.close,
                        onPressed: game.hideFriends,
                        icon: const Icon(Icons.close),
                        iconSize: 30,
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          fixedSize: const Size(52, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _AddFriendPanel(
                    game: game,
                    controller: _friendUidController,
                    isSending: _isSendingRequest,
                    onSubmit: _sendFriendRequest,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          color: Color(0xFF00FFCC),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Expanded(
                    child: FutureBuilder<FriendCommunitySnapshot>(
                      future: _communityLoad,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF00FFCC),
                            ),
                          );
                        }
                        final community = snapshot.data;
                        if (community == null) {
                          return _EmptyText(text: t.rankingServerUnavailable);
                        }
                        return ListView(
                          children: [
                            _SectionTitle(text: t.incomingFriendRequests),
                            const SizedBox(height: 8),
                            if (community.incomingRequests.isEmpty)
                              _EmptyText(text: t.noFriendRequests)
                            else
                              for (final request in community.incomingRequests)
                                _IncomingRequestRow(
                                  game: game,
                                  user: request,
                                  onAccept: () => _acceptRequest(request.uid),
                                ),
                            const SizedBox(height: 18),
                            _SectionTitle(text: t.friendList),
                            const SizedBox(height: 8),
                            if (community.friends.isEmpty)
                              _EmptyText(text: t.noFriends)
                            else
                              for (final friend in community.friends)
                                _UserRow(game: game, user: friend),
                            if (community.outgoingRequests.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              _SectionTitle(text: t.outgoingFriendRequests),
                              const SizedBox(height: 8),
                              for (final request in community.outgoingRequests)
                                _UserRow(game: game, user: request),
                            ],
                          ],
                        );
                      },
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

  Future<void> _sendFriendRequest() async {
    setState(() {
      _isSendingRequest = true;
      _message = null;
    });
    try {
      await widget.game.sendFriendRequest(_friendUidController.text);
      _friendUidController.clear();
      _message = widget.game.text.friendRequestSent;
      _communityLoad = widget.game.loadCommunitySnapshot();
    } catch (_) {
      _message = widget.game.text.friendRequestFailed;
    } finally {
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
        });
      }
    }
  }

  Future<void> _acceptRequest(String uid) async {
    widget.game.playSound(GameSound.uiConfirm);
    try {
      final accepted = await widget.game.acceptFriendRequest(uid);
      if (mounted) {
        setState(() {
          _message = accepted
              ? widget.game.text.friendAccepted
              : widget.game.text.friendRequestUnavailable;
          _communityLoad = widget.game.loadCommunitySnapshot();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = widget.game.text.friendRequestFailed;
          _communityLoad = widget.game.loadCommunitySnapshot();
        });
      }
    }
  }
}

class _AddFriendPanel extends StatelessWidget {
  const _AddFriendPanel({
    required this.game,
    required this.controller,
    required this.isSending,
    required this.onSubmit,
  });

  final QuickDrawGame game;
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = game.text;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101522).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('community-friend-uid-input'),
              controller: controller,
              minLines: 1,
              maxLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: t.friendUidHint,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 18,
                ),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.28),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              key: const ValueKey('community-add-friend-button'),
              onPressed: isSending ? null : onSubmit,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.person_add),
              label: Text(t.addFriend),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFCC),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingRequestRow extends StatelessWidget {
  const _IncomingRequestRow({
    required this.game,
    required this.user,
    required this.onAccept,
  });

  final QuickDrawGame game;
  final CommunityUser user;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return _UserRow(
      game: game,
      user: user,
      trailing: ElevatedButton(
        key: ValueKey('accept-friend-${user.uid}'),
        onPressed: onAccept,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD166),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        child: Text(game.text.acceptFriend),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.game, required this.user, this.trailing});

  final QuickDrawGame game;
  final CommunityUser user;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayLabel(isKo: game.text.isKo);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101522).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          ProfileAvatar(
            displayName: displayName,
            photoUrl: user.photoUrl,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.uid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF00FFCC),
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.62),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
