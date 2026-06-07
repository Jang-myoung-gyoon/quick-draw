import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/quick_draw_game.dart';
import '../services/firebase_game_progress_sync.dart';
import 'profile_avatar.dart';

enum AuthProviderKind { google, apple }

class CommunityOverlay extends StatefulWidget {
  const CommunityOverlay({super.key, required this.game});

  final QuickDrawGame game;

  @override
  State<CommunityOverlay> createState() => _CommunityOverlayState();
}

class _CommunityOverlayState extends State<CommunityOverlay> {
  late final TextEditingController _displayNameController;
  late final FocusNode _displayNameFocusNode;
  bool _isLoadingAccount = true;
  bool _isSigningIn = false;
  bool _isSavingName = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.game.currentUserDisplayName ?? '',
    );
    _displayNameFocusNode = FocusNode();
    _loadAccount();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _displayNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final t = game.text;
    final uid = game.currentUserIdForRanking ?? '-';
    final displayName = game.currentUserDisplayName ?? '';
    final photoUrl = game.currentUserPhotoUrl;
    final hasLinkedLogin = game.hasLinkedCommunityLogin;
    if (!_displayNameFocusNode.hasFocus &&
        _displayNameController.text != displayName) {
      _displayNameController.text = displayName;
    }
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.52),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF101522,
                            ).withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFF00FFCC,
                              ).withValues(alpha: 0.28),
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
                                    key: const ValueKey(
                                      'community-close-button',
                                    ),
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
                              _CurrentProfilePanel(
                                displayName: displayName,
                                photoUrl: photoUrl,
                              ),
                              const SizedBox(height: 12),
                              _DisplayNamePanel(
                                label: t.nickname,
                                hint: t.nicknameHint,
                                saveLabel: t.saveNickname,
                                controller: _displayNameController,
                                focusNode: _displayNameFocusNode,
                                isSaving: _isSavingName,
                                onSave: _saveDisplayName,
                              ),
                              const SizedBox(height: 12),
                              _IdPanel(
                                label: t.myUniqueId,
                                uid: _isLoadingAccount ? '...' : uid,
                                onCopy: () => _copyUid(uid),
                              ),
                              const SizedBox(height: 16),
                              if (hasLinkedLogin)
                                _AuthButton(
                                  keyValue: 'community-logout-button',
                                  label: t.googleLogout,
                                  icon: Icons.logout,
                                  isBusy: _isSigningIn,
                                  onPressed: _isSigningIn ? null : _logout,
                                  outlined: true,
                                )
                              else ...[
                                _AuthButton(
                                  keyValue: 'community-google-login-button',
                                  label: t.googleLogin,
                                  icon: Icons.login,
                                  isBusy: _isSigningIn,
                                  onPressed: _isSigningIn
                                      ? null
                                      : () => _authenticate(
                                          AuthProviderKind.google,
                                        ),
                                  outlined: true,
                                ),
                                const SizedBox(height: 12),
                                _AuthButton(
                                  keyValue: 'community-apple-login-button',
                                  label: t.appleLogin,
                                  icon: Icons.apple,
                                  isBusy: _isSigningIn,
                                  onPressed: _isSigningIn
                                      ? null
                                      : () => _authenticate(
                                          AuthProviderKind.apple,
                                        ),
                                  outlined: true,
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: ElevatedButton.icon(
                                  key: const ValueKey(
                                    'community-friend-list-button',
                                  ),
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
                                      fontSize: 18,
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
                                    fontSize: 18,
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
            },
          ),
        ),
      ),
    );
  }

  Future<void> _loadAccount() async {
    try {
      await widget.game.ensureCommunityUser();
    } catch (_) {
      if (mounted) {
        _message = widget.game.text.isKo
            ? '계정 정보를 불러오지 못했습니다.'
            : 'Could not load account.';
      }
    } finally {
      if (mounted) {
        _displayNameController.text = widget.game.currentUserDisplayName ?? '';
        setState(() {
          _isLoadingAccount = false;
        });
      }
    }
  }

  Future<void> _authenticate(AuthProviderKind provider) async {
    final game = widget.game;
    game.playSound(GameSound.uiSelect);
    final isSignedInProvider = switch (provider) {
      AuthProviderKind.google => game.isGoogleUserSignedIn,
      AuthProviderKind.apple => game.isAppleUserSignedIn,
    };
    setState(() {
      _isSigningIn = true;
      _message = null;
    });
    try {
      if (isSignedInProvider) {
        await game.signOutCommunityUser();
        _displayNameController.text = game.currentUserDisplayName ?? '';
        _message = game.text.isKo ? '로그아웃했습니다.' : 'Signed out.';
      } else {
        switch (provider) {
          case AuthProviderKind.google:
            await game.signInWithGoogleAndSyncProgress();
          case AuthProviderKind.apple:
            await game.signInWithAppleAndSyncProgress();
        }
        _displayNameController.text = game.currentUserDisplayName ?? '';
        _message = switch (provider) {
          AuthProviderKind.google =>
            game.text.isKo ? 'Google 로그인에 성공했습니다.' : 'Google sign-in complete.',
          AuthProviderKind.apple =>
            game.text.isKo ? 'Apple 로그인에 성공했습니다.' : 'Apple sign-in complete.',
        };
      }
    } on AnonymousAccountReplacementRequired catch (replacement) {
      final shouldReplace = await _confirmReplaceAnonymous();
      if (shouldReplace) {
        await replacement.replace();
        _displayNameController.text = game.currentUserDisplayName ?? '';
        _message = game.text.isKo
            ? '로그인 계정으로 교체했습니다.'
            : 'Replaced with the signed-in account.';
      } else {
        _message = null;
      }
    } catch (_) {
      _message = switch (provider) {
        AuthProviderKind.google =>
          game.text.isKo ? 'Google 로그인 실패' : 'Google sign-in failed',
        AuthProviderKind.apple =>
          game.text.isKo ? 'Apple 로그인 실패' : 'Apple sign-in failed',
      };
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final game = widget.game;
    game.playSound(GameSound.uiSelect);
    setState(() {
      _isSigningIn = true;
      _message = null;
    });
    try {
      await game.signOutCommunityUser();
      _displayNameController.text = game.currentUserDisplayName ?? '';
      _message = game.text.isKo ? '로그아웃했습니다.' : 'Signed out.';
    } catch (_) {
      _message = game.text.isKo ? '로그아웃 실패' : 'Sign out failed.';
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<bool> _confirmReplaceAnonymous() async {
    final t = widget.game.text;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              backgroundColor: const Color(0xFF101522),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text(
                t.replaceAnonymousTitle,
                style: const TextStyle(
                  color: Color(0xFF00FFCC),
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SingleChildScrollView(
                child: Text(
                  t.replaceAnonymousDescription,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  key: const ValueKey('community-replace-anonymous-cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(t.cancel),
                ),
                ElevatedButton(
                  key: const ValueKey('community-replace-anonymous-confirm'),
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFCC),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(t.continueLabel),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _saveDisplayName() async {
    final game = widget.game;
    final nextName = _displayNameController.text.trim();
    if (nextName.isEmpty) {
      return;
    }
    game.playSound(GameSound.uiSelect);
    setState(() {
      _isSavingName = true;
      _message = null;
    });
    try {
      await game.updateCommunityDisplayName(nextName);
      _displayNameController.text = game.currentUserDisplayName ?? nextName;
      _message = game.text.isKo ? '별명을 저장했습니다.' : 'Nickname saved.';
    } catch (_) {
      _message = game.text.isKo ? '별명 저장 실패' : 'Nickname save failed.';
    } finally {
      if (mounted) {
        setState(() {
          _isSavingName = false;
        });
      }
    }
  }

  Future<void> _copyUid(String uid) async {
    if (uid.isEmpty || uid == '-') {
      return;
    }
    widget.game.playSound(GameSound.uiSelect);
    await Clipboard.setData(ClipboardData(text: uid));
    if (!mounted) {
      return;
    }
    setState(() {
      _message = widget.game.text.isKo ? '고유 ID를 복사했습니다.' : 'Unique ID copied.';
    });
  }
}

class _CurrentProfilePanel extends StatelessWidget {
  const _CurrentProfilePanel({
    required this.displayName,
    required this.photoUrl,
  });

  final String displayName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final label = displayName.isEmpty ? '?' : displayName;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          ProfileAvatar(displayName: label, photoUrl: photoUrl, size: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisplayNamePanel extends StatelessWidget {
  const _DisplayNamePanel({
    required this.label,
    required this.hint,
    required this.saveLabel,
    required this.controller,
    required this.focusNode,
    required this.isSaving,
    required this.onSave,
  });

  final String label;
  final String hint;
  final String saveLabel;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSaving;
  final VoidCallback onSave;

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
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('community-display-name-field'),
                  controller: controller,
                  focusNode: focusNode,
                  maxLength: 24,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.34),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  key: const ValueKey('community-save-display-name-button'),
                  onPressed: isSaving ? null : onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFCC),
                    foregroundColor: Colors.black,
                    disabledForegroundColor: Colors.black.withValues(
                      alpha: 0.44,
                    ),
                    disabledBackgroundColor: const Color(
                      0xFF00FFCC,
                    ).withValues(alpha: 0.42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(saveLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.keyValue,
    required this.label,
    required this.icon,
    required this.isBusy,
    required this.onPressed,
    required this.outlined,
  });

  final String keyValue;
  final String label;
  final IconData icon;
  final bool isBusy;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final childIcon = isBusy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF00FFCC),
            ),
          )
        : Icon(icon);
    final textStyle = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w900,
    );
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: outlined
          ? OutlinedButton.icon(
              key: ValueKey(keyValue),
              onPressed: onPressed,
              icon: childIcon,
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.55),
                side: const BorderSide(color: Color(0xFF00FFCC), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: textStyle,
              ),
            )
          : ElevatedButton.icon(
              key: ValueKey(keyValue),
              onPressed: onPressed,
              icon: childIcon,
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFCC),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: textStyle,
              ),
            ),
    );
  }
}

class _IdPanel extends StatelessWidget {
  const _IdPanel({
    required this.label,
    required this.uid,
    required this.onCopy,
  });

  final String label;
  final String uid;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('community-copy-id-button'),
        onTap: onCopy,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      uid,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.copy, color: Color(0xFF00FFCC), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
