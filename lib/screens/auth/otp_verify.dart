import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/auth_api.dart';
import '../../api/client.dart';
import '../../api/employee_api.dart';
import '../../api/employer_api.dart';
import '../../store/auth_store.dart';
import '../../theme.dart';
import '../../widgets/findly_logo.dart';
import '../../widgets/gradient_background.dart';
import '../employer/home.dart';
import '../employer/profile_complete.dart' as employer;
import '../employee/home.dart';
import '../employee/profile_complete.dart';
import 'register.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phone;
  final String? devCode;
  const OtpVerifyScreen({super.key, required this.phone, this.devCode});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.devCode != null) _codeCtrl.text = widget.devCode!;
  }

  /// Calls /v1/employee/profile and decides between home feed and the
  /// first-time completion form. Falls back to the completion form on any
  /// fetch failure — safer than dropping the user into a feed that will
  /// silently filter everything out.
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

  /// Same idea as the employee path: if the employer never finished the
  /// post-signup completion form, route them there instead of the home.
  Future<Widget> _resolveEmployerDestination() async {
    try {
      final profile = await EmployerApi.getProfile();
      final business = profile['business'] as Map<String, dynamic>?;
      final isComplete = business?['is_complete'] == true;
      return isComplete
          ? const EmployerHomeScreen()
          : const employer.EmployerProfileCompleteScreen();
    } catch (_) {
      return const employer.EmployerProfileCompleteScreen();
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'הזן את הקוד');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AuthApi.verifySms(phone: widget.phone, code: code);
      if (!mounted) return;

      // Phone is unknown to the system → push the register screen with the
      // OTP-bound registration_token so the user can finish signup.
      if (result['is_new_user'] == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RegisterScreen(
              phone: widget.phone,
              registrationToken: result['registration_token'] as String,
            ),
          ),
        );
        return;
      }

      // Existing user — full session.
      await authStore.setSession(
        result['token'] as String,
        Map<String, dynamic>.from(result['user']),
      );
      if (!mounted) return;

      // Both roles have a completion form — if the profile isn't fully
      // set up, we route there instead of dropping the user on the home
      // feed.
      Widget destination = const SizedBox.shrink();
      switch (authStore.role) {
        case 'employer':
          destination = await _resolveEmployerDestination();
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
    } catch (e) {
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
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('אימות קוד',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.heebo(fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('שלחנו קוד ל-${widget.phone}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textSecondary)),
                      if (widget.devCode != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3D6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('🛠️ DEV: ${widget.devCode}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.heebo(fontWeight: FontWeight.w600)),
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.heebo(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w700),
                        maxLength: 6,
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '------',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: FindlyColors.warningRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_error!,
                              style: const TextStyle(color: FindlyColors.warningRed),
                              textAlign: TextAlign.center),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _verify,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('אישור והיכנס'),
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
