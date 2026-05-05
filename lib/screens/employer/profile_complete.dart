import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/client.dart';
import '../../api/employer_api.dart';
import '../../api/shared_api.dart';
import '../../store/auth_store.dart';
import '../../theme.dart';
import '../../widgets/findly_logo.dart';
import '../../widgets/gradient_background.dart';
import 'home.dart';

/// First-time post-signup completion form for an employer. Routed to
/// after register, or after login if `business.is_complete` is false.
/// Mirrors the employee-side `ProfileCompleteScreen` but with the
/// business + service-area fields the employer flow needs.
class EmployerProfileCompleteScreen extends StatefulWidget {
  const EmployerProfileCompleteScreen({super.key});

  @override
  State<EmployerProfileCompleteScreen> createState() => _EmployerProfileCompleteScreenState();
}

class _EmployerProfileCompleteScreenState extends State<EmployerProfileCompleteScreen> {
  // Free-text fields. `fullName` is pre-populated from authStore so the
  // employer doesn't have to retype it.
  late final TextEditingController _fullNameCtrl =
      TextEditingController(text: authStore.fullName ?? '');
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _vatCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Multi-select state. The lists are loaded lazily; while loading we
  // disable the submit button.
  late final Future<_TaxonomyData> _taxonomies = _loadTaxonomies();
  final Set<int> _activityAreaIds = {};
  final Set<int> _eventCategoryIds = {};
  final Set<int> _industryIds = {};

  bool _saving = false;
  String? _error;

  Future<_TaxonomyData> _loadTaxonomies() async {
    final results = await Future.wait([
      SharedApi.areas(),
      SharedApi.categories(),
      SharedApi.industries(),
    ]);
    return _TaxonomyData(
      areas: results[0],
      categories: results[1],
      industries: results[2],
    );
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _vatCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_businessNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'יש להזין שם עסק');
      return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      setState(() => _error = 'יש להזין כתובת');
      return;
    }
    if (_activityAreaIds.isEmpty) {
      setState(() => _error = 'יש לבחור לפחות אזור פעילות אחד');
      return;
    }
    if (_eventCategoryIds.isEmpty) {
      setState(() => _error = 'יש לבחור לפחות תחום עיסוק אחד');
      return;
    }
    if (_industryIds.isEmpty) {
      setState(() => _error = 'יש לבחור לפחות תעשייה אחת');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await EmployerApi.completeRegistration(
        fullName:
            _fullNameCtrl.text.trim().isEmpty ? null : _fullNameCtrl.text.trim(),
        businessName: _businessNameCtrl.text.trim(),
        ownerName:
            _ownerNameCtrl.text.trim().isEmpty ? null : _ownerNameCtrl.text.trim(),
        vatNumber: _vatCtrl.text.trim().isEmpty ? null : _vatCtrl.text.trim(),
        contactEmail:
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        activityAreaIds: _activityAreaIds.toList(),
        eventCategoryIds: _eventCategoryIds.toList(),
        industryIds: _industryIds.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const EmployerHomeScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'שגיאת רשת');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                const FindlyLogo(fontSize: 36, subtitle: 'BUSINESS'),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.97),
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
                        'השלמת פרטי עסק',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.heebo(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'נשלים כמה פרטים כדי שנוכל לחבר אותך לעובדים מתאימים',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      _section('פרטים אישיים'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _fullNameCtrl,
                        decoration: const InputDecoration(labelText: 'שם מלא'),
                      ),
                      const SizedBox(height: 16),
                      _section('פרטי העסק'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _businessNameCtrl,
                        decoration: const InputDecoration(labelText: 'שם העסק *'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ownerNameCtrl,
                        decoration: const InputDecoration(labelText: 'שם הבעלים'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _vatCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'מספר עוסק'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'אימייל ליצירת קשר'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(labelText: 'כתובת *'),
                      ),
                      const SizedBox(height: 20),
                      FutureBuilder<_TaxonomyData>(
                        future: _taxonomies,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snap.hasError) {
                            return Text(
                              'שגיאה בטעינת רשימות: ${snap.error}',
                              style: const TextStyle(color: FindlyColors.warningRed),
                            );
                          }
                          final data = snap.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _section('אזורי פעילות *'),
                              const SizedBox(height: 8),
                              _ChipsPicker(
                                items: data.areas,
                                selected: _activityAreaIds,
                                onTap: (id) => setState(() {
                                  if (!_activityAreaIds.add(id)) _activityAreaIds.remove(id);
                                }),
                              ),
                              const SizedBox(height: 16),
                              _section('תחומי עיסוק *'),
                              const SizedBox(height: 8),
                              _ChipsPicker(
                                items: data.categories,
                                selected: _eventCategoryIds,
                                onTap: (id) => setState(() {
                                  if (!_eventCategoryIds.add(id)) _eventCategoryIds.remove(id);
                                }),
                              ),
                              const SizedBox(height: 16),
                              _section('תעשיות *'),
                              const SizedBox(height: 8),
                              _ChipsPicker(
                                items: data.industries,
                                selected: _industryIds,
                                onTap: (id) => setState(() {
                                  if (!_industryIds.add(id)) _industryIds.remove(id);
                                }),
                              ),
                            ],
                          );
                        },
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
                        onPressed: _saving ? null : _submit,
                        child: _saving
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

  Widget _section(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: GoogleFonts.heebo(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: FindlyColors.textPrimary,
        ),
      ),
    );
  }
}

class _TaxonomyData {
  final List<dynamic> areas;
  final List<dynamic> categories;
  final List<dynamic> industries;
  _TaxonomyData({required this.areas, required this.categories, required this.industries});
}

/// Multi-select tag picker — green pill when selected, faded green when
/// not. Used for areas / categories / industries.
class _ChipsPicker extends StatelessWidget {
  final List<dynamic> items;
  final Set<int> selected;
  final ValueChanged<int> onTap;
  const _ChipsPicker({
    required this.items,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: items.map((raw) {
        final m = raw as Map;
        final id = m['id'] as int;
        final name = m['name'] as String? ?? '';
        final isOn = selected.contains(id);
        return GestureDetector(
          onTap: () => onTap(id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOn
                  ? FindlyColors.brandGreen
                  : FindlyColors.brandGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              name,
              style: GoogleFonts.heebo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isOn ? Colors.white : FindlyColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
