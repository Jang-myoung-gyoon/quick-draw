import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/quick_draw_game.dart';

Future<void> showFriendInviteDialog(
  BuildContext context, {
  required QuickDrawGame game,
}) async {
  final t = game.text;
  final selection = await showDialog<_InviteLinkChoice>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF101522),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          t.friendInviteTitle,
          style: const TextStyle(
            color: Color(0xFF00FFCC),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          t.friendInviteDescription,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.74),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_InviteLinkChoice.plain),
            child: Text(t.copyPlainLink),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(_InviteLinkChoice.request),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFCC),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(t.copyInviteRequestLink),
          ),
        ],
      );
    },
  );
  if (selection == null) {
    return;
  }

  final link = selection == _InviteLinkChoice.request
      ? await game.buildFriendInviteLink()
      : game.buildPlainAppLink();
  if (link == null || link.isEmpty) {
    return;
  }
  await Clipboard.setData(ClipboardData(text: link));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(t.linkCopied),
        backgroundColor: const Color(0xFF101522),
      ),
    );
}

enum _InviteLinkChoice { request, plain }
