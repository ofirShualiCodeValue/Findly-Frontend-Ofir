import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/auth_api.dart';
import '../../api/client.dart';
import '../../api/employee_api.dart';
import '../../store/auth_store.dart';
import '../../theme.dart';
import '../../widgets/findly_logo.dart';
import '../../widgets/gradient_background.dart';
import '../employer/profile_complete.dart' as employer;
import '../employee/home.dart';
import '../employee/profile_complete.dart';

/// Final step of signup, reached only when `/sms/verify` reports the
/// phone is new to the system. Collects the full name + role and calls
/// `/auth/register` with the OTP-bound registration token. On success,
/// the user is logged in and routed to the role-appropriate home.
class RegisterScreen extends StatefulWidget {
  final String phone;
  final String registrationToken;
  const RegisterScreen({
    super.key,
    required this.phone,
    required this.registrationToken,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  String _role = 'employee';
  bool _loading = false;
  String? _error;

  Future<Widget> _resolveEmployeeDestination() async {
    try {
      final profile = await EmployeeApi.getProfile();
      final p = profile['profile'] as Map<String, dynamic>?;
      final isComplete = p?['is_complete'] == true;
      return isComplete ? const EmployeeHomeScreen() : const ProfileCompleteScreen();
    } catch (_) {
      return const ProfileCompleteScreen();
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'יש להזין שם מלא');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AuthApi.register(
        registrationToken: widget.registrationToken,
        fullName: name,
        role: _role,
      );
      await authStore.setSession(
        result['token'] as String,
        Map<String, dynamic>.from(result['user']),
      );
      if (!mounted) return;

      // Fresh accounts always go through the role-specific completion
      // form before landing on the feed. The employee form sets matcher
      // fields (year of birth, work status, etc.); the employer form
      // collects business details + activity areas + categories +
      // industries.
      Widget destination = const SizedBox.shrink();
      switch (_role) {
        case 'employer':
          destination = const employer.EmployerProfileCompleteScreen();
          break;
        case 'employee':
          destination = await _resolveEmployeeDestination();
          break;
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'שגיאת רשת');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BrandGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const FindlyLogo(fontSize: 40),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'הרשמה למערכת',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.heebo(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'מספר ${widget.phone} עדיין לא רשום, נמשיך להרשמה',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'שם מלא',
                          prefixIcon: Icon(Icons.person, size: 20),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'סוג חשבון',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      _RolePicker(
                        value: _role,
                        onChanged: (v) => setState(() => _role = v),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: FindlyColors.warningRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: FindlyColors.warningRed),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('סיום הרשמה'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RolePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _RolePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F8),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        children: [
          Expanded(child: _option('employee', 'עובד', Icons.work_outline)),
          Expanded(child: _option('employer', 'מעסיק', Icons.business)),
        ],
      ),
    );
  }

  Widget _option(String v, String label, IconData icon) {
    final selected = value == v;
    return GestureDetector(
      onTap: () => onChanged(v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(36),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? FindlyColors.brandPurple : FindlyColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.heebo(
                fontWeight: FontWeight.w600,
                color: selected ? FindlyColors.textPrimary : FindlyColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
