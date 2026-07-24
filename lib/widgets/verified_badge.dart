import 'package:daaymn/globals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VerifiedBadge extends StatelessWidget {
  final Profile profile;
  final double size;
  final bool showText;

  const VerifiedBadge({
    super.key,
    required this.profile,
    this.size = 14.0,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!profile.isVerified) {
      return const SizedBox.shrink();
    }

    final icon = SvgPicture.asset(
      'assets/images/daaymnv.svg',
      width: size,
      height: size,
    );

    if (showText) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            icon,
            const SizedBox(width: 4),
            Text(
              'Verified',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: size * 0.85,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(top: 2.0), // Nudge icon down slightly
        child: icon,
      );
    }
  }
}
