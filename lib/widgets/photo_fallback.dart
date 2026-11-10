import 'package:flutter/material.dart';

/// Drawn where a profile photo failed to load: the person's initial on the
/// app's gradient, so a card never shows as a blank box. With [onRetry] it
/// also says so in plain words and retries when tapped. [compact] is for
/// small avatars: just the initial.
class PhotoFallback extends StatelessWidget {
  final String name;
  final VoidCallback? onRetry;
  final bool compact;

  const PhotoFallback({
    super.key,
    required this.name,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    final body = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B4A5E), Color(0xFF3F51B5)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.biggest.shortestSide;
          final size = (side.isFinite ? side : 80) * (compact ? 0.5 : 0.28);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 12),
                  Text(
                    onRetry == null
                        ? "Photo didn't load"
                        : "Photo didn't load. Tap to retry",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
    if (onRetry == null) {
      return Semantics(
        label: compact ? name : "$name's photo didn't load",
        child: body,
      );
    }
    return Semantics(
      button: true,
      label: "$name's photo didn't load. Tap to retry",
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: body,
      ),
    );
  }
}
