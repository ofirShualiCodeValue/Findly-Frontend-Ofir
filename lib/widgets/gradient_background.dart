import 'package:flutter/material.dart';
import '../theme.dart';

/// Full-screen brand gradient (cyan → blue → violet).
/// Used on splash and the auth flow.
class BrandGradientBackground extends StatelessWidget {
  final Widget child;
  const BrandGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: brandGradient),
      child: child,
    );
  }
}

/// Soft pastel gradient at the top, fading into the standard scaffold background.
/// Mirrors the in-app screens (notifications list, home header).
class SurfaceGradientBackground extends StatelessWidget {
  final Widget child;
  final double topGradientHeight;

  const SurfaceGradientBackground({
    super.key,
    required this.child,
    this.topGradientHeight = 320,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topGradientHeight,
          child: const DecoratedBox(decoration: BoxDecoration(gradient: surfaceGradient)),
        ),
        child,
      ],
    );
  }
}
