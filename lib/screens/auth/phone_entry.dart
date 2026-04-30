import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/auth_api.dart';
import '../../api/client.dart';
import '../../theme.dart';
import '../../widgets/findly_logo.dart';
import '../../widgets/gradient_background.dart';
import 'otp_verify.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _role = 'employer';
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
      final result = await AuthApi.requestSms(
        phone: phone,
        role: _role,
        fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      );
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
    } catch (e) {
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
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('ברוכים הבאים',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.heebo(fontSize: 24, fontWeight: FontWeight.w700, color: FindlyColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('הזן את מספר הטלפון שלך כדי להתחיל',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textSecondary)),
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'שם מלא (להרשמה ראשונית)',
                          prefixIcon: Icon(Icons.person, size: 20),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('סוג חשבון',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary)),
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
                          child: Text(_error!,
                              style: const TextStyle(color: FindlyColors.warningRed),
                              textAlign: TextAlign.center),
                        ),
                      FilledButton(
                        onPressed: _loading ? null : _request,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('שליחת קוד אימות'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('הקוד יוצג ב-DEV mode בתשובת ה-API',
                    style: GoogleFonts.heebo(fontSize: 11, color: Colors.white70)),
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
          Expanded(child: _option('employer', 'מעסיק', Icons.business)),
          Expanded(child: _option('employee', 'עובד', Icons.work_outline)),
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
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? FindlyColors.brandPurple : FindlyColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.heebo(
                  fontWeight: FontWeight.w600,
                  color: selected ? FindlyColors.textPrimary : FindlyColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}
