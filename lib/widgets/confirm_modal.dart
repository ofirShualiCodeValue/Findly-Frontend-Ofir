import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

/// Centered confirmation dialog matching the "Cancel event" mockup.
/// 3D-feel icon at the top, then title, subtitle, primary (black pill) and
/// destructive (red outline) actions.
Future<bool> showConfirmModal(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? subtitle,
  required String confirmLabel,
  required String cancelLabel,
  bool destructiveConfirm = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 32, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GradientIcon(icon: icon),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.heebo(fontSize: 18, fontWeight: FontWeight.w700, color: FindlyColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textSecondary, height: 1.5)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(cancelLabel),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: destructiveConfirm ? FindlyColors.warningRed : FindlyColors.brandPurple,
                side: BorderSide(color: destructiveConfirm ? FindlyColors.warningRed : FindlyColors.brandPurple),
              ),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}

class _GradientIcon extends StatelessWidget {
  final IconData icon;
  const _GradientIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FindlyColors.gradientTop, FindlyColors.gradientMid, FindlyColors.gradientBottom],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: FindlyColors.brandPurple.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Icon(icon, size: 40, color: Colors.white),
    );
  }
}
