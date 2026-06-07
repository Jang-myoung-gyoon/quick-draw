import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.displayName,
    required this.photoUrl,
    this.size = 42,
  });

  final String displayName;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final fallback = _fallbackLetter(displayName);
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFF00FFCC).withValues(alpha: 0.18),
        child: url == null || url.isEmpty
            ? _FallbackAvatar(letter: fallback, size: size)
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return _FallbackAvatar(letter: fallback, size: size);
                },
              ),
      ),
    );
  }

  static String _fallbackLetter(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.characters.first.toUpperCase();
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.letter, required this.size});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: const Color(0xFF00FFCC),
          fontSize: size * 0.46,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
