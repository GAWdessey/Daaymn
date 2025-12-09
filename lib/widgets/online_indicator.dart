import 'package:flutter/material.dart';

class OnlineIndicator extends StatelessWidget {
  final double size;

  const OnlineIndicator({super.key, this.size = 12.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(right: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base green orb
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                stops: const [0.0, 0.5, 1.0],
                colors: [
                  const Color(0xFFc3f7c3),
                  const Color(0xFF5ef55e),
                  const Color(0xFF00ff00),
                ],
              ),
            ),
          ),
          // Highlight
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.4),
                stops: const [0.0, 0.4, 1.0],
                colors: [
                  Colors.white.withOpacity(0.6),
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
          ),
          // Checkmark
          Icon(
            Icons.check,
            color: Colors.white,
            size: size * 0.6,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 2.0,
                offset: const Offset(0, 1.0),
              )
            ],
          ),
        ],
      ),
    );
  }
}
