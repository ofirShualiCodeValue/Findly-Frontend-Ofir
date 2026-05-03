import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

/// One action button on a [FindlyAlert]. Set [primary] true for the dark
/// filled button, false for a subtle text button.
class FindlyAlertAction {
  final String label;
  final bool primary;
  /// Override the primary button color (e.g. red for destructive).
  final Color? backgroundColor;

  const FindlyAlertAction({
    required this.label,
    this.primary = true,
    this.backgroundColor,
  });
}

/// Show a Findly-branded alert dialog. Returns the index of the tapped
/// action (0-based), or null if the dialog was dismissed without one.
///
/// All in-app popups should use this instead of [showDialog]+[AlertDialog]
/// so they share the same look-and-feel.
Future<int?> showFindlyAlert(
  BuildContext context, {
  required Widget badge,
  required String title,
  required String message,
  required List<FindlyAlertAction> actions,
  bool barrierDismissible = true,
}) {
  return showDialog<int>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: _FindlyAlertCard(
        badge: badge,
        title: title,
        message: message,
        actions: actions,
      ),
    ),
  );
}

/// Convenience: a 96px gradient circle with a centered child (text or icon)
/// plus four small sparkle dots in the corners — matches the Figma popups.
class FindlyAlertBadge extends StatelessWidget {
  final Widget child;
  final List<Color> colors;

  const FindlyAlertBadge({
    super.key,
    required this.child,
    this.colors = const [FindlyColors.gradientMid, FindlyColors.gradientBottom],
  });

  /// Shorthand for an "+18" age badge.
  static const ageBadge = FindlyAlertBadge(
    child: Text(
      '+18',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 22,
      ),
    ),
  );

  /// Shorthand for a single-icon badge.
  static FindlyAlertBadge icon(IconData icon) {
    return FindlyAlertBadge(
      child: Icon(icon, color: Colors.white, size: 36),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Center(child: child),
          ),
          // Sparkle decorations.
          Positioned(top: 6, right: 18, child: _sparkle(8)),
          Positioned(top: 24, left: 12, child: _sparkle(6)),
          Positioned(bottom: 18, right: 8, child: _sparkle(7)),
          Positioned(bottom: 8, left: 24, child: _sparkle(5)),
        ],
      ),
    );
  }

  Widget _sparkle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: FindlyColors.brandGreen,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FindlyAlertCard extends StatelessWidget {
  final Widget badge;
  final String title;
  final String message;
  final List<FindlyAlertAction> actions;

  const _FindlyAlertCard({
    required this.badge,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          badge,
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.heebo(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: FindlyColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.heebo(
              fontSize: 13.5,
              height: 1.5,
              color: FindlyColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ..._buildActions(context),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    if (actions.isEmpty) return const [];
    if (actions.length == 1) {
      return [_actionButton(context, actions.first, 0, fullWidth: true)];
    }
    // Two actions: primary on top, secondary below for visual weight.
    final primary = actions.indexWhere((a) => a.primary);
    final ordered = primary >= 0
        ? [actions[primary], ...actions.where((a) => a != actions[primary])]
        : actions;
    return [
      for (int i = 0; i < ordered.length; i++) ...[
        _actionButton(context, ordered[i], actions.indexOf(ordered[i]), fullWidth: true),
        if (i < ordered.length - 1) const SizedBox(height: 8),
      ],
    ];
  }

  Widget _actionButton(BuildContext context, FindlyAlertAction action, int index, {required bool fullWidth}) {
    final btn = action.primary
        ? FilledButton(
            onPressed: () => Navigator.of(context).pop(index),
            style: FilledButton.styleFrom(
              backgroundColor: action.backgroundColor ?? const Color(0xFF1A1A2E),
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(action.label),
          )
        : TextButton(
            onPressed: () => Navigator.of(context).pop(index),
            style: TextButton.styleFrom(
              foregroundColor: FindlyColors.textSecondary,
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(action.label),
          );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
