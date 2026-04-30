import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

/// Findly wordmark with the green dot above the "i".
/// `subtitle` is rendered below ("BUSINESS" on the splash, omitted in nav).
class FindlyLogo extends StatelessWidget {
  final double fontSize;
  final Color color;
  final String? subtitle;
  final Color subtitleColor;

  const FindlyLogo({
    super.key,
    this.fontSize = 64,
    this.color = Colors.white,
    this.subtitle,
    this.subtitleColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The wordmark itself: "Findly" with a small green dot floating above the "i".
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Text(
              'Findly',
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.5,
                color: color,
              ),
            ),
            Positioned(
              top: fontSize * 0.18,
              left: fontSize * 1.05,
              child: Container(
                width: fontSize * 0.18,
                height: fontSize * 0.18,
                decoration: const BoxDecoration(
                  color: FindlyColors.brandGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          SizedBox(height: fontSize * 0.05),
          Text(
            subtitle!,
            style: GoogleFonts.poppins(
              fontSize: fontSize * 0.18,
              fontWeight: FontWeight.w500,
              letterSpacing: fontSize * 0.06,
              color: subtitleColor,
            ),
          ),
        ],
      ],
    );
  }
}
