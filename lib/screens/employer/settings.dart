import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/client.dart';
import '../../api/employer_api.dart';
import '../../store/auth_store.dart';
import '../../theme.dart';
import '../../widgets/gradient_background.dart';
import '../auth/phone_entry.dart';

class EmployerSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> notifications;
  const EmployerSettingsScreen({super.key, required this.notifications});

  @override
  State<EmployerSettingsScreen> createState() => _EmployerSettingsScreenState();
}

class _EmployerSettingsScreenState extends State<EmployerSettingsScreen> {
  late bool _push;
  late bool _email;
  late bool _sms;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _push = widget.notifications['push'] as bool? ?? true;
    _email = widget.notifications['email'] as bool? ?? true;
    _sms = widget.notifications['sms'] as bool? ?? false;
  }

  Future<void> _patchNotifications() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await EmployerApi.patchProfile({
        'notifications': {'push': _push, 'email': _email, 'sms': _sms},
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await authStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SurfaceGradientBackground(
        topGradientHeight: 200,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _Header(onBack: () => Navigator.pop(context)),
              const SizedBox(height: 16),
              _Card(
                children: [
                  _SectionLabel('התראות'),
                  _ToggleRow(
                    label: 'התראות פוש',
                    value: _push,
                    onChanged: (v) {
                      setState(() => _push = v);
                      _patchNotifications();
                    },
                  ),
                  const _Divider(),
                  _ToggleRow(
                    label: 'התראות במייל',
                    value: _email,
                    onChanged: (v) {
                      setState(() => _email = v);
                      _patchNotifications();
                    },
                  ),
                  const _Divider(),
                  _ToggleRow(
                    label: 'SMS',
                    value: _sms,
                    onChanged: (v) {
                      setState(() => _sms = v);
                      _patchNotifications();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Card(
                children: [
                  _SectionLabel('פרטיות ואבטחה'),
                  _NavRow(
                    label: 'ביטול הרשאות',
                    onTap: () => _comingSoon(context),
                  ),
                  const _Divider(),
                  _NavRow(
                    label: 'מדיניות פרטיות',
                    subtitle: 'קרא איך אנו שומרים על הפרטיות שלך',
                    onTap: () => _comingSoon(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _LogoutButton(onPressed: _logout),
            ],
          ),
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('בקרוב')),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Text(
              'הגדרות',
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_forward, color: FindlyColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: GoogleFonts.heebo(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: FindlyColors.textPrimary,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: FindlyColors.brandGreen,
          ),
          const Spacer(),
          Text(
            label,
            style: GoogleFonts.heebo(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _NavRow({required this.label, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.arrow_forward, size: 20, color: FindlyColors.textSecondary),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: GoogleFonts.heebo(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.heebo(fontSize: 12, color: FindlyColors.textSecondary),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 1, color: Color(0xFFEEF0F4)),
      );
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _LogoutButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FindlyColors.brandGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, color: FindlyColors.brandGreen, size: 20),
              ),
              const Spacer(),
              Text(
                'התנתקות מהחשבון',
                style: GoogleFonts.heebo(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
