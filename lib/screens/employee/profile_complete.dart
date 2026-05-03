import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/client.dart';
import '../../api/employee_api.dart';
import '../../api/shared_api.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../widgets/findly_alert.dart';
import '../../widgets/gradient_background.dart';
import 'home.dart';

/// Multi-step Employee registration matching the Findly Figma:
///   1. בואו נכיר קצת — first/last name, year of birth, home city, work mode
///      (with hidden 18+ gate after submit)
///   2. תמונת פרופיל — optional avatar, with "דלג" (skip)
///   3. איזה תחומים מתאימים לך? — pick 1+ industries (chips)
///   4. For each selected industry: pick sub-categories (specialties) in a
///      bottom sheet. Submit on the last step.
class ProfileCompleteScreen extends StatefulWidget {
  const ProfileCompleteScreen({super.key});

  @override
  State<ProfileCompleteScreen> createState() => _ProfileCompleteScreenState();
}

class _ProfileCompleteScreenState extends State<ProfileCompleteScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  static const _totalSteps = 4;

  // Step 1
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _homeCityCtrl = TextEditingController();
  int? _yearOfBirth;
  String _workStatus = 'salaried';

  // Step 2
  String? _avatarFilePath;

  // Step 3-4
  late Future<List<dynamic>> _industriesFuture;
  // Map of industry id -> selected sub-category ids
  final Map<int, Set<int>> _selectedSubCatsByIndustry = {};
  final Set<int> _selectedIndustries = {};

  // Submission helpers
  final _rateCtrl = TextEditingController(text: '50');
  double _rangeKm = 30;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _industriesFuture = SharedApi.industries();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _homeCityCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  // ---------- Step transitions ----------

  void _next() async {
    // Block advancing past step 1 (basics) when the user is under 18.
    // Doing it here — not on submit — means they don't fill out the rest of
    // the form first.
    if (_step == 0 && _yearOfBirth != null) {
      final age = DateTime.now().year - _yearOfBirth!;
      if (age < 18) {
        await _showAgeRequirementDialog();
        return;
      }
    }
    if (_step == _totalSteps - 1) {
      _submit();
      return;
    }
    setState(() => _step += 1);
    _pageCtrl.animateToPage(_step, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _showAgeRequirementDialog() async {
    if (!mounted) return;
    await showFindlyAlert(
      context,
      badge: FindlyAlertBadge.ageBadge,
      title: 'מצטערים אבל לא ניתן להמשיך בהרשמה',
      message: 'Findly מיועדת בשלב זה למשתמשים מגיל 18 ומעלה.\n'
          'נשמח לראות אותך כאן כשתגיע/י לגיל המתאים.',
      actions: const [FindlyAlertAction(label: 'הבנתי')],
    );
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step -= 1);
    _pageCtrl.animateToPage(_step, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  bool _canAdvance() {
    switch (_step) {
      case 0:
        return _firstNameCtrl.text.trim().isNotEmpty &&
            _lastNameCtrl.text.trim().isNotEmpty &&
            _yearOfBirth != null &&
            _homeCityCtrl.text.trim().isNotEmpty;
      case 1:
        return true; // photo step has skip
      case 2:
        return _selectedIndustries.isNotEmpty;
      case 3:
        // Each selected industry must have at least one sub-category picked.
        return _selectedIndustries.every((id) => (_selectedSubCatsByIndustry[id] ?? {}).isNotEmpty);
      default:
        return false;
    }
  }

  // ---------- Validations + submit ----------

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 50;

    // Best-effort GPS, fall back to server-side geocoding by city.
    double? lat;
    double? lng;
    final pos = await LocationService.currentPosition();
    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
    }

    try {
      // Optional avatar upload first; non-fatal if it fails.
      if (_avatarFilePath != null) {
        try {
          await EmployeeApi.uploadAvatar(_avatarFilePath!);
        } catch (_) {
          // ignore — registration proceeds
        }
      }

      final allSubCats =
          _selectedIndustries.expand((id) => _selectedSubCatsByIndustry[id] ?? const <int>{}).toList();

      await EmployeeApi.completeRegistration(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        yearOfBirth: _yearOfBirth,
        workStatus: _workStatus,
        locationRangeKm: _rangeKm.round(),
        baseHourlyRate: rate,
        homeCity: _homeCityCtrl.text.trim(),
        homeLatitude: lat,
        homeLongitude: lng,
        industryIds: _selectedIndustries.toList(),
        industrySubCategoryIds: allSubCats,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const EmployeeHomeScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (e.errorCode == 'AGE_REQUIREMENT_NOT_MET') {
        // Should be unreachable because _next() blocks before the user
        // gets here, but keep the safety net for the bypass case.
        if (mounted) await _showAgeRequirementDialog();
        setState(() => _step = 0);
        _pageCtrl.jumpToPage(0);
      } else {
        setState(() => _submitError = e.message);
      }
    } catch (_) {
      setState(() => _submitError = 'שגיאת רשת');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SurfaceGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _ProgressBar(step: _step, total: _totalSteps, onBack: _back),
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildBasicsStep(),
                    _buildPhotoStep(),
                    _buildIndustriesStep(),
                    _buildSubCategoriesStep(),
                  ],
                ),
              ),
              _BottomBar(
                step: _step,
                canAdvance: _canAdvance(),
                submitting: _submitting,
                onNext: _next,
                onSkipPhoto: _step == 1 ? () => _next() : null,
                error: _submitError,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 1: בואו נכיר קצת ---
  Widget _buildBasicsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'בואו נכיר קצת...',
            style: GoogleFonts.heebo(fontSize: 26, fontWeight: FontWeight.w700, color: FindlyColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'כמה פרטים בסיסיים שיעזרו לנו להתאים לכם משמרות',
            style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _LabeledField(
            label: 'שם פרטי',
            child: TextField(
              controller: _firstNameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'יונתן'),
            ),
          ),
          _LabeledField(
            label: 'שם משפחה',
            child: TextField(
              controller: _lastNameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'אוחנה'),
            ),
          ),
          _LabeledField(
            label: 'שנת לידה',
            child: InkWell(
              onTap: _pickYearOfBirth,
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.cake_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'בחרו',
                ),
                child: Text(_yearOfBirth?.toString() ?? ''),
              ),
            ),
          ),
          _LabeledField(
            label: 'מקום מגורים',
            child: TextField(
              controller: _homeCityCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
                hintText: 'ראשון לציון',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'בחרו איך אתם רוצים לעבוד?',
            style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textSecondary),
          ),
          RadioListTile<String>(
            value: 'salaried',
            groupValue: _workStatus,
            onChanged: (v) => setState(() => _workStatus = v ?? _workStatus),
            title: const Text('שכיר/ה'),
          ),
          RadioListTile<String>(
            value: 'freelancer',
            groupValue: _workStatus,
            onChanged: (v) => setState(() => _workStatus = v ?? _workStatus),
            title: const Text('פרילנסר/ית (עצמאי/ת)'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickYearOfBirth() async {
    final now = DateTime.now().year;
    final initial = _yearOfBirth ?? (now - 25);
    int selected = initial;
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        return SizedBox(
          height: 280,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'שנת לידה',
                  style: GoogleFonts.heebo(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                // Allow trackpad/mouse drag scrolling on Chrome web — by
                // default ListWheelScrollView only accepts touch input.
                child: ScrollConfiguration(
                  behavior: const _AllPointerScrollBehavior(),
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 36,
                    diameterRatio: 1.6,
                    physics: const FixedExtentScrollPhysics(),
                    controller: FixedExtentScrollController(initialItem: now - initial),
                    onSelectedItemChanged: (i) => selected = now - i,
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (_, i) {
                        final y = now - i;
                        if (y < 1900) return null;
                        return Center(
                          child: Text(
                            y.toString(),
                            style: GoogleFonts.heebo(fontSize: 18),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(selected),
                  child: const Text('אישור'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) setState(() => _yearOfBirth = picked);
  }

  // --- Step 2: תמונת פרופיל ---
  Widget _buildPhotoStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'תמונת פרופיל',
            style: GoogleFonts.heebo(fontSize: 26, fontWeight: FontWeight.w700, color: FindlyColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'תמונה טובה וברורה עושה את כל ההבדל. זה יעזור למעסיקים לזהות אתכם בקלות.',
            style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textSecondary),
          ),
          const Spacer(),
          Center(
            child: GestureDetector(
              onTap: _pickFromGallery,
              child: Stack(
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [FindlyColors.gradientMid, FindlyColors.gradientBottom],
                      ),
                      shape: BoxShape.circle,
                      image: _avatarFilePath != null
                          ? DecorationImage(image: NetworkImage('file://$_avatarFilePath'), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _avatarFilePath != null
                        ? null
                        : const Icon(Icons.person_outline, color: Colors.white, size: 80),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _pickFromCamera,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('לצלם עכשיו'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.image_outlined),
            label: const Text('העלאת תמונה מהגלריה'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (f != null) setState(() => _avatarFilePath = f.path);
  }

  Future<void> _pickFromCamera() async {
    final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1024, imageQuality: 85);
    if (f != null) setState(() => _avatarFilePath = f.path);
  }

  // --- Step 3: תחומים ---
  Widget _buildIndustriesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'איזה תחומים מתאימים לך?',
            style: GoogleFonts.heebo(fontSize: 24, fontWeight: FontWeight.w700, color: FindlyColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'בחרו לפחות 1-2 תחומים שמתאימים לכם',
            style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textSecondary),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<dynamic>>(
            future: _industriesFuture,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Text('שגיאה בטעינת תחומים: ${snap.error}',
                    style: const TextStyle(color: FindlyColors.warningRed));
              }
              final inds = snap.data ?? [];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: inds.map((i) {
                  final id = i['id'] as int;
                  final name = i['name'] as String;
                  final selected = _selectedIndustries.contains(id);
                  return ChoiceChip(
                    label: Text(name),
                    selected: selected,
                    onSelected: (yes) => setState(() {
                      if (yes) {
                        _selectedIndustries.add(id);
                        _selectedSubCatsByIndustry.putIfAbsent(id, () => <int>{});
                      } else {
                        _selectedIndustries.remove(id);
                        _selectedSubCatsByIndustry.remove(id);
                      }
                    }),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Step 4: תת-תחומים לכל תחום שנבחר ---
  Widget _buildSubCategoriesStep() {
    return FutureBuilder<List<dynamic>>(
      future: _industriesFuture,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data ?? [];
        final picked = all.where((i) => _selectedIndustries.contains(i['id'])).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'מה אתם יודעים לעשות?',
                style: GoogleFonts.heebo(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: FindlyColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'בחרו את התפקידים שאתם יכולים למלא בכל תחום',
                style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...picked.map((i) => _industryGroup(i as Map<String, dynamic>)),
              const SizedBox(height: 16),
              _LabeledField(
                label: 'טווח חיפוש (${_rangeKm.round()} ק"מ)',
                child: Slider(
                  min: 5,
                  max: 200,
                  divisions: 39,
                  label: _rangeKm.round().toString(),
                  value: _rangeKm,
                  onChanged: (v) => setState(() => _rangeKm = v),
                ),
              ),
              _LabeledField(
                label: 'שכר בסיס לשעה (₪)',
                child: TextField(
                  controller: _rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _industryGroup(Map<String, dynamic> industry) {
    final id = industry['id'] as int;
    final name = industry['name'] as String;
    final subs = (industry['sub_categories'] as List? ?? const []).cast<Map<String, dynamic>>();
    final selectedIds = _selectedSubCatsByIndustry[id] ?? <int>{};
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: GoogleFonts.heebo(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (subs.isEmpty)
            const Text('אין תת-תחומים לתחום הזה',
                style: TextStyle(color: FindlyColors.textSecondary))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subs.map((s) {
                final sid = s['id'] as int;
                final sname = s['name'] as String;
                final picked = selectedIds.contains(sid);
                return FilterChip(
                  label: Text(sname),
                  selected: picked,
                  onSelected: (yes) => setState(() {
                    final set = _selectedSubCatsByIndustry.putIfAbsent(id, () => <int>{});
                    if (yes) {
                      set.add(sid);
                    } else {
                      set.remove(sid);
                    }
                  }),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  final VoidCallback onBack;
  const _ProgressBar({required this.step, required this.total, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close), onPressed: onBack),
          Expanded(
            child: Row(
              children: List.generate(total, (i) {
                final filled = i <= step;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 4,
                    decoration: BoxDecoration(
                      color: filled ? Colors.green : Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, color: Colors.transparent),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int step;
  final bool canAdvance;
  final bool submitting;
  final VoidCallback onNext;
  final VoidCallback? onSkipPhoto;
  final String? error;
  const _BottomBar({
    required this.step,
    required this.canAdvance,
    required this.submitting,
    required this.onNext,
    required this.onSkipPhoto,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FindlyColors.warningRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: FindlyColors.warningRed)),
              ),
            ),
          if (step == 1)
            TextButton(onPressed: onSkipPhoto, child: const Text('דלג')),
          FilledButton(
            onPressed: !canAdvance || submitting ? null : onNext,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size.fromHeight(52),
            ),
            child: submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(step == 3 ? 'סיום' : 'המשך'),
          ),
        ],
      ),
    );
  }
}

/// Lets ListWheelScrollView accept mouse drag on web/desktop, where the
/// default ScrollBehavior only enables touch.
class _AllPointerScrollBehavior extends MaterialScrollBehavior {
  const _AllPointerScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
