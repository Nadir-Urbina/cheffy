import 'package:flutter/material.dart';

/// Glossy green orb widget - Cheffy's AI avatar
/// 
/// A beautiful 3D-looking sphere with gradient colors and glossy highlights.
/// Use this across the app as Cheffy's visual identity.
class CheffyOrb extends StatelessWidget {
  final double size;

  const CheffyOrb({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 0.9,
          colors: [
            Color(0xFFCDDC39), // Lime/yellow highlight
            Color(0xFF8BC34A), // Light green
            Color(0xFF689F38), // Darker green
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF689F38).withValues(alpha: 0.4),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main glossy highlight (top-left)
          Positioned(
            top: size * 0.12,
            left: size * 0.15,
            child: Container(
              width: size * 0.35,
              height: size * 0.25,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size * 0.3),
                  topRight: Radius.circular(size * 0.15),
                  bottomLeft: Radius.circular(size * 0.1),
                  bottomRight: Radius.circular(size * 0.2),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.8),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Small secondary highlight
          Positioned(
            top: size * 0.18,
            left: size * 0.22,
            child: Container(
              width: size * 0.12,
              height: size * 0.08,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.1),
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
