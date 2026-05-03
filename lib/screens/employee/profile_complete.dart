import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/employee_api.dart';
import '../../api/shared_api.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../widgets/gradient_background.dart';
import 'home.dart';

/// First-time registration form for employees. Mandatory before they can
/// browse the Job Offers feed (the matcher needs all of these fields).
class ProfileCompleteScreen extends StatefulWidget {
  const ProfileCompleteScreen({super.key});

  @override
  State<ProfileCompleteScreen> createState() => _ProfileCompleteScreenState();
}

class _ProfileCompleteScreenState extends State<ProfileCompleteScreen> {
  DateTime? _dateOfBirth;
  String _workStatus = 'freelancer';
  double _rangeKm = 30;
  final _rateCtrl = TextEditingController();
  double? _homeLat;
  double? _homeLng;
  bool _resolvingLocation = false;
  final Set<int> _selectedIndustries = {};

  late Future<List<dynamic>> _industriesFuture;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _industriesFuture = SharedApi.categories();
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(today.year - 25, today.month, today.day),
      firstDate: DateTime(today.year - 100),
      lastDate: today,
      helpText: 'תאריך לידה',
      cancelText: 'ביטול',
      confirmText: 'בחר',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _resolveLocation() async {
    setState(() => _resolvingLocation = true);
    try {
      final pos = await LocationService.currentPosition();
      if (pos != null) {
        setState(() {
          _homeLat = pos.latitude;
          _homeLng = pos.longitude;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא הצלחנו לקבל מיקום — בדוק הרשאות והפעלה של GPS')),
        );
      }
    } finally {
      if (mounted) setState(() => _resolvingLocation = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_dateOfBirth == null) {
      setState(() => _error = 'בחר תאריך לידה');
      return;
    }
    final rate = double.tryParse(_rateCtrl.text.trim());
    if (rate == null || rate < 0) {
      setState(() => _error = 'הזן שכר בסיס תקין');
      return;
    }
    if (_homeLat == null || _homeLng == null) {
      setState(() => _error = 'אישור מיקום הבית חובה');
      return;
    }

    setState(() => _submitting = true);
    try {
      await EmployeeApi.completeRegistration(
        dateOfBirth: _dateOfBirth!,
        workStatus: _workStatus,
        locationRangeKm: _rangeKm.round(),
        baseHourlyRate: rate,
        homeLatitude: _homeLat!,
        homeLongitude: _homeLng!,
        industryIds: _selectedIndustries.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const EmployeeHomeScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (e.errorCode == 'AGE_REQUIREMENT_NOT_MET') {
        if (mounted) await _showAgeRequirementDialog(e.data);
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = 'שגיאת רשת');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showAgeRequirementDialog(Map<String, dynamic>? data) async {
    final minAge = data?['minimum_age'] ?? 18;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
        title: const Text('דרישת גיל'),
        content: Text(
          'לצערנו, השימוש ב-Findly מותר רק מגיל $minAge ומעלה.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('הבנתי'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SurfaceGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'נשמח להכיר אותך',
                  style: GoogleFonts.heebo(fontSize: 24, fontWeight: FontWeight.w700, color: FindlyColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'כדי שנתאים לך אירועים, נצטרך כמה פרטים',
                  style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _Card(child: _section(
                  title: 'תאריך לידה',
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(),
                        hintText: 'בחר תאריך',
                      ),
                      child: Text(_dateOfBirth == null ? '' : DateFormat('dd/MM/yyyy').format(_dateOfBirth!)),
                    ),
                  ),
                )),
                const SizedBox(height: 16),
                _Card(child: _section(
                  title: 'סטטוס עבודה',
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'freelancer', label: Text('פרילנסר')),
                      ButtonSegment(value: 'self_employed', label: Text('עצמאי')),
                    ],
                    selected: {_workStatus},
                    onSelectionChanged: (s) => setState(() => _workStatus = s.first),
                  ),
                )),
                const SizedBox(height: 16),
                _Card(child: _section(
                  title: 'מיקום הבית',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _homeLat == null
                            ? 'לא נקבע מיקום עדיין'
                            : 'מיקום נקבע: ${_homeLat!.toStringAsFixed(4)}, ${_homeLng!.toStringAsFixed(4)}',
                        style: TextStyle(color: _homeLat == null ? FindlyColors.warningRed : FindlyColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _resolvingLocation ? null : _resolveLocation,
                        icon: _resolvingLocation
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location),
                        label: const Text('זהה מיקום נוכחי'),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                _Card(child: _section(
                  title: 'טווח חיפוש (${_rangeKm.round()} ק"מ)',
                  child: Slider(
                    min: 5,
                    max: 200,
                    divisions: 39,
                    label: '${_rangeKm.round()}',
                    value: _rangeKm,
                    onChanged: (v) => setState(() => _rangeKm = v),
                  ),
                )),
                const SizedBox(height: 16),
                _Card(child: _section(
                  title: 'שכר בסיס לשעה (₪)',
                  child: TextField(
                    controller: _rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                      hintText: 'לדוגמה: 50',
                    ),
                  ),
                )),
                const SizedBox(height: 16),
                _Card(child: _section(
                  title: 'תחומים (אפשר לבחור כמה)',
                  child: FutureBuilder<List<dynamic>>(
                    future: _industriesFuture,
                    builder: (_, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Text('שגיאה בטעינת תחומים: ${snap.error}', style: const TextStyle(color: FindlyColors.warningRed));
                      }
                      final cats = snap.data ?? [];
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cats.map((c) {
                          final id = c['id'] as int;
                          final name = c['name'] as String;
                          final selected = _selectedIndustries.contains(id);
                          return FilterChip(
                            label: Text(name),
                            selected: selected,
                            onSelected: (yes) => setState(() {
                              if (yes) {
                                _selectedIndustries.add(id);
                              } else {
                                _selectedIndustries.remove(id);
                              }
                            }),
                          );
                        }).toList(),
                      );
                    },
                  ),
                )),
                const SizedBox(height: 24),
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
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('סיום הרשמה'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: GoogleFonts.heebo(fontSize: 14, fontWeight: FontWeight.w600, color: FindlyColors.textPrimary),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}
