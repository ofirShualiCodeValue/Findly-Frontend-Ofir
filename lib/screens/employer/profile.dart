import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/client.dart';
import '../../api/employer_api.dart';
import '../../config.dart';
import '../../theme.dart';
import '../../widgets/error_view.dart';
import '../../widgets/gradient_background.dart';
import 'settings.dart';

class EmployerProfileScreen extends StatefulWidget {
  const EmployerProfileScreen({super.key});

  @override
  State<EmployerProfileScreen> createState() => _EmployerProfileScreenState();
}

class _EmployerProfileScreenState extends State<EmployerProfileScreen> {
  Map<String, dynamic>? _profile;
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
      final p = await EmployerApi.getProfile();
      setState(() {
        _profile = p;
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

  Future<void> _pickAndUploadLogo() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    try {
      final updated = await EmployerApi.uploadLogo(file);
      setState(() => _profile = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editBusinessDetails() async {
    final business = (_profile!['business'] as Map?) ?? {};
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BusinessDetailsSheet(initial: {
        'business_name': business['business_name'] ?? '',
        'owner_name': business['owner_name'] ?? '',
        'contact_phone': business['contact_phone'] ?? _profile!['phone'] ?? '',
        'contact_email': business['contact_email'] ?? _profile!['email'] ?? '',
        'address': business['address'] ?? '',
      }),
    );
    if (result == null) return;
    try {
      final updated = await EmployerApi.patchProfile(result);
      setState(() => _profile = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editAreas() async {
    final selected = await _openMultiSelect(
      title: 'בחירת אזורי פעילות',
      loader: EmployerApi.getAreas,
      currentIds: _selectedIds('activity_areas'),
    );
    if (selected == null) return;
    try {
      final updated = await EmployerApi.setActivityAreas(selected);
      setState(() => _profile = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editCategories() async {
    final selected = await _openMultiSelect(
      title: 'בחירת תחומי עסק',
      loader: EmployerApi.getCategories,
      currentIds: _selectedIds('event_categories'),
    );
    if (selected == null) return;
    try {
      final updated = await EmployerApi.setEventCategories(selected);
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
    final notifications = (_profile?['notifications'] as Map?)?.cast<String, dynamic>() ?? const {};
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployerSettingsScreen(notifications: Map<String, dynamic>.from(notifications)),
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

    final business = (_profile!['business'] as Map?)?.cast<String, dynamic>() ?? const {};
    final logoUrl = business['logo_url'] as String?;
    final displayName = (business['business_name'] as String?)?.isNotEmpty == true
        ? business['business_name'] as String
        : (_profile!['full_name'] as String? ?? '');

    return Scaffold(
      body: SurfaceGradientBackground(
        topGradientHeight: 320,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _Header(onSettings: _openSettings, onBack: () => Navigator.pop(context)),
              const SizedBox(height: 16),
              _AvatarBlock(
                logoUrl: logoUrl,
                fallbackName: displayName,
                onEdit: _pickAndUploadLogo,
              ),
              const SizedBox(height: 24),
              _BusinessDetailsCard(
                business: business,
                fallbackPhone: _profile!['phone'] as String?,
                fallbackEmail: _profile!['email'] as String?,
                onEdit: _editBusinessDetails,
              ),
              const SizedBox(height: 16),
              _ChipsCard(
                title: 'אזור פעילות',
                items: (_profile!['activity_areas'] as List?) ?? const [],
                emptyHint: 'לא נבחרו אזורים',
                onEdit: _editAreas,
              ),
              const SizedBox(height: 16),
              _ChipsCard(
                title: 'תחומי עסק',
                items: (_profile!['event_categories'] as List?) ?? const [],
                emptyHint: 'לא נבחרו תחומים',
                onEdit: _editCategories,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onBack;
  const _Header({required this.onSettings, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Green settings/circle button (top-left in RTL = first child).
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
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_forward, color: FindlyColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  final String? logoUrl;
  final String fallbackName;
  final VoidCallback onEdit;
  const _AvatarBlock({required this.logoUrl, required this.fallbackName, required this.onEdit});

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

  String _absoluteUrl(String path) {
    if (path.startsWith('http')) return path;
    return '$kApiBaseUrl$path';
  }
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
          // Title first (rightmost in RTL) so the bold heading sits on the
          // start side, matching how Hebrew websites lead the eye.
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

class _BusinessDetailsCard extends StatelessWidget {
  final Map<String, dynamic> business;
  final String? fallbackPhone;
  final String? fallbackEmail;
  final VoidCallback onEdit;
  const _BusinessDetailsCard({
    required this.business,
    required this.fallbackPhone,
    required this.fallbackEmail,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <_DetailRow>[
      _DetailRow('שם העסק', business['business_name'] as String?),
      _DetailRow('איש קשר', business['owner_name'] as String?),
      _DetailRow(null, (business['contact_phone'] as String?) ?? fallbackPhone),
      _DetailRow('אימייל', (business['contact_email'] as String?) ?? fallbackEmail),
      _DetailRow('כתובת', business['address'] as String?),
    ];
    return _CardWrap(
      child: Column(
        children: [
          _CardHeader(title: 'פרטי העסק', onEdit: onEdit),
          const SizedBox(height: 4),
          ...rows.expand((r) => [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Row(
                    children: [
                      if (r.label != null) ...[
                        Text(
                          '${r.label}:',
                          style: GoogleFonts.heebo(
                            fontSize: 13,
                            color: FindlyColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
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
              ]),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DetailRow {
  final String? label;
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

// ---------- Bottom sheets ----------

class _BusinessDetailsSheet extends StatefulWidget {
  final Map<String, String> initial;
  const _BusinessDetailsSheet({required this.initial});

  @override
  State<_BusinessDetailsSheet> createState() => _BusinessDetailsSheetState();
}

class _BusinessDetailsSheetState extends State<_BusinessDetailsSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initial['business_name']);
  late final TextEditingController _owner = TextEditingController(text: widget.initial['owner_name']);
  late final TextEditingController _phone = TextEditingController(text: widget.initial['contact_phone']);
  late final TextEditingController _email = TextEditingController(text: widget.initial['contact_email']);
  late final TextEditingController _address = TextEditingController(text: widget.initial['address']);

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
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
              'עריכת פרטי העסק',
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'שם העסק')),
            const SizedBox(height: 12),
            TextField(controller: _owner, decoration: const InputDecoration(labelText: 'איש קשר')),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'טלפון'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'אימייל'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'כתובת')),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'business_name': _name.text.trim(),
                'owner_name': _owner.text.trim(),
                'contact_phone': _phone.text.trim(),
                'contact_email': _email.text.trim(),
                'address': _address.text.trim(),
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
