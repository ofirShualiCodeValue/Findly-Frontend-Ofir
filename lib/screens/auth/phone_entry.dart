import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/auth_api.dart';
import '../../api/client.dart';
import '../../theme.dart';
import '../../widgets/findly_logo.dart';
import '../../widgets/gradient_background.dart';
import 'otp_verify.dart';

/// Step 1 of the auth flow: just collect the phone number. The backend
/// no longer requires role / name here — those are filled later in the
/// register screen, only when the phone turns out to be new.
class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _request() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'יש להזין מספר טלפון');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AuthApi.requestSms(phone: phone);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(
            phone: phone,
            devCode: result['dev_code'] as String?,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'שגיאת רשת — בדוק שהשרת רץ');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const SizedBox(height: 32),
                const FindlyLogo(fontSize: 56, subtitle: 'BUSINESS'),
                const SizedBox(height: 48),
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
                        'ברוכים הבאים',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.heebo(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: FindlyColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'הזן את מספר הטלפון שלך כדי להתחיל',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.heebo(
                          fontSize: 14,
                          color: FindlyColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'מספר טלפון',
                          hintText: '0501234567',
                          prefixIcon: Icon(Icons.phone, size: 20),
                        ),
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
                        onPressed: _loading ? null : _request,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('שליחת קוד אימות'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'הקוד יוצג ב-DEV mode בתשובת ה-API',
                  style: GoogleFonts.heebo(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
