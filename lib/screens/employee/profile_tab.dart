import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../store/auth_store.dart';
import '../../theme.dart';
import '../../widgets/gradient_background.dart';

class EmployeeProfileTab extends StatelessWidget {
  const EmployeeProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SurfaceGradientBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const SizedBox(height: 16),
            _Avatar(name: authStore.fullName ?? '?'),
            const SizedBox(height: 12),
            Text(
              authStore.fullName ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(fontSize: 22, fontWeight: FontWeight.w700, color: FindlyColors.textPrimary),
            ),
            Text(
              authStore.user?['phone'] ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textSecondary),
            ),
            const SizedBox(height: 32),
            _SettingsCard(children: [
              _Row(icon: Icons.person_outline, label: 'פרטים אישיים', onTap: () {}),
              _Row(icon: Icons.notifications_outlined, label: 'התראות', onTap: () {}),
              _Row(icon: Icons.lock_outline, label: 'אבטחה', onTap: () {}),
            ]),
            const SizedBox(height: 16),
            _SettingsCard(children: [
              _Row(icon: Icons.help_outline, label: 'תמיכה', onTap: () {}),
              _Row(icon: Icons.description_outlined, label: 'תנאי שימוש', onTap: () {}),
            ]),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: FindlyColors.warningRed,
              ),
              onPressed: () => authStore.clear(),
              child: const Text('התנתקות'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first : '?';
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [FindlyColors.gradientMid, FindlyColors.gradientBottom],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: FindlyColors.brandPurple.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            initial,
            style: GoogleFonts.heebo(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: FindlyColors.brandPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: FindlyColors.brandPurple),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: GoogleFonts.heebo(fontSize: 15, fontWeight: FontWeight.w500))),
            const Icon(Icons.chevron_left, color: FindlyColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
