import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/employee_api.dart';
import '../../api/shared_api.dart';
import '../../config.dart';
import '../../theme.dart';
import '../../widgets/error_view.dart';
import '../../widgets/gradient_background.dart';
import 'settings.dart';

/// Redesigned employee profile, matching the Figma. Lazily loads three
/// resources in parallel — the profile itself, the worker rating, and the
/// monthly earnings rollup — then renders the cards: avatar+rating header,
/// monthly earnings, personal details, specialties, certifications.
class EmployeeProfileTab extends StatefulWidget {
  const EmployeeProfileTab({super.key});

  @override
  State<EmployeeProfileTab> createState() => _EmployeeProfileTabState();
}

class _EmployeeProfileTabState extends State<EmployeeProfileTab> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _rating;
  Map<String, dynamic>? _earnings;
  String? _error;
  bool _loading = true;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        EmployeeApi.getProfile(),
        EmployeeApi.getMyRating(),
        EmployeeApi.getEarnings(),
      ]);
      setState(() {
        _profile = results[0];
        _rating = results[1];
        _earnings = results[2];
        _error = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    try {
      await EmployeeApi.uploadAvatar(file.path);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editPersonalDetails() async {
    final profile = (_profile?['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PersonalDetailsSheet(initial: {
        'first_name': _profile?['first_name'] ?? '',
        'last_name': _profile?['last_name'] ?? '',
        'email': _profile?['email'] ?? '',
        'home_city': profile['home_city'] ?? '',
      }),
    );
    if (result == null) return;
    try {
      final updated = await EmployeeApi.updateProfile(result);
      setState(() => _profile = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editSpecialties() async {
    final selected = await _openMultiSelect(
      title: 'בחירת תפקידים',
      loader: _loadAllSubCategoriesFlat,
      currentIds: _selectedIds('industry_sub_categories'),
    );
    if (selected == null) return;
    try {
      final updated = await EmployeeApi.setIndustrySubCategories(selected);
      setState(() => _profile = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Industries endpoint returns industries with nested sub_categories;
  /// the multi-select sheet expects a flat list, so collapse here.
  Future<List<dynamic>> _loadAllSubCategoriesFlat() async {
    final industries = await SharedApi.industries();
    final flat = <dynamic>[];
    for (final ind in industries) {
      final subs = (ind as Map)['sub_categories'] as List? ?? [];
      flat.addAll(subs);
    }
    return flat;
  }

  Future<void> _editCertifications() async {
    final selected = await _openMultiSelect(
      title: 'בחירת תעודות',
      loader: SharedApi.certifications,
      currentIds: _selectedIds('certifications'),
    );
    if (selected == null) return;
    try {
      final updated = await EmployeeApi.setCertifications(selected);
      setState(() => _profile = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  List<int> _selectedIds(String key) {
    final raw = _profile?[key];
    if (raw is! List) return const [];
    return raw.map<int>((e) => (e as Map)['id'] as int).toList();
  }

  Future<List<int>?> _openMultiSelect({
    required String title,
    required Future<List<dynamic>> Function() loader,
    required List<int> currentIds,
  }) {
    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MultiSelectSheet(
        title: title,
        loader: loader,
        currentIds: currentIds,
      ),
    );
  }

  void _openSettings() {
    final notifications =
        (_profile?['notifications'] as Map?)?.cast<String, dynamic>() ?? const {};
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeSettingsScreen(
          notifications: Map<String, dynamic>.from(notifications),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('הפרופיל שלי')),
        body: ErrorView(message: _error ?? 'נכשל לטעון פרופיל', onRetry: _load),
      );
    }

    final profile = (_profile!['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
    final avatarUrl = profile['avatar_url'] as String?;
    final fullName = (_profile!['full_name'] as String?) ?? '';
    final ratingAvg = (_rating?['avg'] as num?)?.toDouble();
    final ratingCount = (_rating?['count'] as int?) ?? 0;
    final subs = (_profile!['industry_sub_categories'] as List?) ?? const [];
    final certs = (_profile!['certifications'] as List?) ?? const [];
    final history = (_rating?['history'] as List?) ?? const [];

    return Scaffold(
      body: SurfaceGradientBackground(
        topGradientHeight: 320,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _Header(onSettings: _openSettings),
              const SizedBox(height: 16),
              _AvatarBlock(
                logoUrl: avatarUrl,
                fallbackName: fullName,
                onEdit: _pickAndUploadAvatar,
              ),
              const SizedBox(height: 12),
              Text(
                fullName,
                textAlign: TextAlign.center,
                style: GoogleFonts.heebo(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              _RatingStrip(avg: ratingAvg, count: ratingCount),
              const SizedBox(height: 24),
              _EarningsCard(earnings: _earnings),
              const SizedBox(height: 16),
              _PersonalDetailsCard(
                profile: profile,
                fullName: fullName,
                phone: _profile!['phone'] as String?,
                email: _profile!['email'] as String?,
                onEdit: _editPersonalDetails,
              ),
              const SizedBox(height: 16),
              _ChipsCard(
                title: 'תפקידים',
                items: subs,
                emptyHint: 'לא נבחרו תפקידים',
                onEdit: _editSpecialties,
              ),
              const SizedBox(height: 16),
              _ChipsCard(
                title: 'תעודות',
                items: certs,
                emptyHint: 'לא נבחרו תעודות',
                onEdit: _editCertifications,
              ),
              if (history.isNotEmpty) ...[
                const SizedBox(height: 16),
                _RatingHistoryCard(history: history),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Header + avatar
// =====================================================================

class _Header extends StatelessWidget {
  final VoidCallback onSettings;
  const _Header({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Material(
            color: FindlyColors.brandGreen,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSettings,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.settings, color: Colors.white, size: 20),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'הפרופיל שלי',
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          // Spacer to balance the green settings circle on the other side.
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  final String? logoUrl;
  final String fallbackName;
  final VoidCallback onEdit;
  const _AvatarBlock({
    required this.logoUrl,
    required this.fallbackName,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 124,
        height: 124,
        child: Stack(
          children: [
            Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: logoUrl != null && logoUrl!.isNotEmpty
                    ? Image.network(
                        _absoluteUrl(logoUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => _Initial(name: fallbackName),
                      )
                    : _Initial(name: fallbackName),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Material(
                color: FindlyColors.brandGreen,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onEdit,
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.photo_camera, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _absoluteUrl(String path) =>
      path.startsWith('http') ? path : '$kApiBaseUrl$path';
}

class _Initial extends StatelessWidget {
  final String name;
  const _Initial({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim().characters.first : '?';
    return Container(
      color: const Color(0xFF1A1A2E),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.heebo(fontSize: 44, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

class _RatingStrip extends StatelessWidget {
  final double? avg;
  final int count;
  const _RatingStrip({required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    if (avg == null) {
      return Center(
        child: Text(
          'אין דירוג עדיין',
          style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary),
        ),
      );
    }
    final score = avg!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          score.toStringAsFixed(1),
          style: GoogleFonts.heebo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: FindlyColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        ...List.generate(5, (i) {
          if (score >= i + 1) {
            return const Icon(Icons.star_rounded, color: FindlyColors.brandGreen, size: 18);
          }
          if (score > i) {
            return const Icon(Icons.star_half_rounded, color: FindlyColors.brandGreen, size: 18);
          }
          return Icon(
            Icons.star_outline_rounded,
            color: FindlyColors.brandGreen.withValues(alpha: 0.4),
            size: 18,
          );
        }),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: GoogleFonts.heebo(fontSize: 12, color: FindlyColors.textSecondary),
        ),
      ],
    );
  }
}

// =====================================================================
// Earnings card
// =====================================================================

class _EarningsCard extends StatelessWidget {
  final Map<String, dynamic>? earnings;
  const _EarningsCard({required this.earnings});

  @override
  Widget build(BuildContext context) {
    final current = (earnings?['current_month'] as num?)?.toDouble() ?? 0;
    final previous = (earnings?['previous_month'] as num?)?.toDouble() ?? 0;
    return _CardWrap(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Title first (rightmost in RTL); icon trails on the left.
                Text(
                  'הכנסות חודשיות (ברוטו)',
                  style: GoogleFonts.heebo(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: FindlyColors.brandGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: FindlyColors.brandGreen,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _EarningsCell(label: 'החודש שעבר', amount: previous)),
                Container(
                  width: 1,
                  height: 44,
                  color: const Color(0xFFEEF0F4),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),
                Expanded(child: _EarningsCell(label: 'החודש', amount: current)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsCell extends StatelessWidget {
  final String label;
  final double amount;
  const _EarningsCell({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '₪${amount.toStringAsFixed(0)}',
          style: GoogleFonts.heebo(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.heebo(fontSize: 12, color: FindlyColors.textSecondary),
        ),
      ],
    );
  }
}

// =====================================================================
// Personal details / chips / rating history cards
// =====================================================================

class _CardWrap extends StatelessWidget {
  final Widget child;
  const _CardWrap({required this.child});

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
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;
  const _CardHeader({required this.title, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 4),
      child: Row(
        children: [
          // Title first (rightmost in RTL) so bold heading leads the row.
          Text(
            title,
            style: GoogleFonts.heebo(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              foregroundColor: FindlyColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'עריכה',
              style: GoogleFonts.heebo(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalDetailsCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String fullName;
  final String? phone;
  final String? email;
  final VoidCallback onEdit;
  const _PersonalDetailsCard({
    required this.profile,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final dob = profile['date_of_birth'] as String?;
    final yob = (dob != null && dob.length >= 4) ? dob.substring(0, 4) : null;
    final workStatus = profile['work_status'] as String?;
    final workStatusLabel = workStatus == 'freelancer'
        ? 'עצמאי'
        : workStatus == 'salaried'
            ? 'שכיר'
            : null;

    final rows = <_DetailRow>[
      _DetailRow('שם מלא', fullName.isEmpty ? null : fullName),
      _DetailRow('שנת לידה', yob),
      _DetailRow('מקום מגורים', profile['home_city'] as String?),
      _DetailRow('אימייל', email),
      _DetailRow('טלפון', phone),
      _DetailRow('סטטוס עבודה', workStatusLabel),
    ];
    return _CardWrap(
      child: Column(
        children: [
          _CardHeader(title: 'פרטים אישיים', onEdit: onEdit),
          const SizedBox(height: 4),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  Text(
                    '${r.label}:',
                    style: GoogleFonts.heebo(
                      fontSize: 13,
                      color: FindlyColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (r.value?.isNotEmpty ?? false) ? r.value! : '—',
                      textAlign: TextAlign.left,
                      style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final String? value;
  _DetailRow(this.label, this.value);
}

class _ChipsCard extends StatelessWidget {
  final String title;
  final List items;
  final String emptyHint;
  final VoidCallback onEdit;
  const _ChipsCard({
    required this.title,
    required this.items,
    required this.emptyHint,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return _CardWrap(
      child: Column(
        children: [
          _CardHeader(title: title, onEdit: onEdit),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: items.isEmpty
                  ? Text(
                      emptyHint,
                      style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: items
                          .map((e) => _Chip(label: (e as Map)['name'] as String? ?? ''))
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: FindlyColors.brandGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.heebo(
          fontSize: 13,
          color: FindlyColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _RatingHistoryCard extends StatelessWidget {
  final List history;
  const _RatingHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return _CardWrap(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  'היסטוריית דירוגים',
                  style: GoogleFonts.heebo(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
              ],
            ),
          ),
          ...history.map((h) => _RatingHistoryRow(entry: Map<String, dynamic>.from(h as Map))),
        ],
      ),
    );
  }
}

class _RatingHistoryRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _RatingHistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final score = (entry['rating'] as num?)?.toInt() ?? 0;
    final comment = entry['comment'] as String?;
    final ev = (entry['event'] as Map?)?.cast<String, dynamic>();
    final created = DateTime.tryParse(entry['created_at'] as String? ?? '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (i) {
                final on = i < score;
                return Icon(
                  on ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: on
                      ? FindlyColors.brandGreen
                      : FindlyColors.brandGreen.withValues(alpha: 0.4),
                  size: 16,
                );
              }),
              const Spacer(),
              if (created != null)
                Text(
                  DateFormat('d/M/yyyy', 'he').format(created),
                  style: GoogleFonts.heebo(fontSize: 11, color: FindlyColors.textSecondary),
                ),
            ],
          ),
          if (ev?['name'] != null) ...[
            const SizedBox(height: 4),
            Text(
              ev!['name'] as String,
              style: GoogleFonts.heebo(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              comment,
              style: GoogleFonts.heebo(fontSize: 12, color: FindlyColors.textSecondary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// Bottom sheets
// =====================================================================

class _PersonalDetailsSheet extends StatefulWidget {
  final Map<String, String> initial;
  const _PersonalDetailsSheet({required this.initial});

  @override
  State<_PersonalDetailsSheet> createState() => _PersonalDetailsSheetState();
}

class _PersonalDetailsSheetState extends State<_PersonalDetailsSheet> {
  late final TextEditingController _firstName =
      TextEditingController(text: widget.initial['first_name']);
  late final TextEditingController _lastName =
      TextEditingController(text: widget.initial['last_name']);
  late final TextEditingController _email =
      TextEditingController(text: widget.initial['email']);
  late final TextEditingController _homeCity =
      TextEditingController(text: widget.initial['home_city']);

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _homeCity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E5EE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'עריכת פרטים אישיים',
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'שם פרטי'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'שם משפחה'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'אימייל'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _homeCity,
              decoration: const InputDecoration(labelText: 'עיר מגורים'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'first_name': _firstName.text.trim(),
                'last_name': _lastName.text.trim(),
                'email': _email.text.trim(),
                'home_city': _homeCity.text.trim(),
              }),
              child: const Text('שמירה'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiSelectSheet extends StatefulWidget {
  final String title;
  final Future<List<dynamic>> Function() loader;
  final List<int> currentIds;
  const _MultiSelectSheet({
    required this.title,
    required this.loader,
    required this.currentIds,
  });

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late Future<List<dynamic>> _future;
  late final Set<int> _selected = {...widget.currentIds};

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E5EE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.heebo(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('שגיאה: ${snap.error}',
                        style: GoogleFonts.heebo(color: FindlyColors.warningRed)),
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('אין אפשרויות זמינות',
                        style: GoogleFonts.heebo(color: FindlyColors.textSecondary)),
                  );
                }
                return SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: items.map((raw) {
                      final m = raw as Map;
                      final id = m['id'] as int;
                      final name = m['name'] as String? ?? '';
                      final isOn = _selected.contains(id);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (isOn) {
                            _selected.remove(id);
                          } else {
                            _selected.add(id);
                          }
                        }),
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
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, _selected.toList()),
            child: const Text('שמירה'),
          ),
        ],
      ),
    );
  }
}
