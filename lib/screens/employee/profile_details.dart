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

/// View + edit screen for the Personal Details flow. Handles all the
/// profile fields the completion form covered, plus avatar upload and
/// industry add/remove.
class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = EmployeeApi.getProfile();
  }

  Future<void> _refresh() async {
    setState(() => _future = EmployeeApi.getProfile());
    await _future;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    try {
      await EmployeeApi.uploadAvatar(file.path);
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editField({
    required String title,
    required String backendKey,
    required String? currentValue,
    TextInputType keyboard = TextInputType.text,
  }) async {
    final ctrl = TextEditingController(text: currentValue ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ביטול')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('שמור')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await EmployeeApi.updateProfile({backendKey: ctrl.text.trim()});
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editRange(int currentKm) async {
    double value = currentKm.toDouble();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setStateDialog) {
        return AlertDialog(
          title: Text('טווח חיפוש (${value.round()} ק"מ)'),
          content: Slider(
            min: 5,
            max: 200,
            divisions: 39,
            label: value.round().toString(),
            value: value,
            onChanged: (v) => setStateDialog(() => value = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ביטול')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('שמור')),
          ],
        );
      }),
    );
    if (ok != true) return;
    try {
      await EmployeeApi.updateProfile({'location_range_km': value.round()});
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editWorkStatus(String current) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('סטטוס עבודה'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'freelancer'),
            child: const Text('פרילנסר'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'self_employed'),
            child: const Text('עצמאי'),
          ),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    try {
      await EmployeeApi.updateProfile({'work_status': picked});
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _manageIndustries(List<dynamic> currentIndustries) async {
    final selected = {...currentIndustries.map((c) => c['id'] as int)};
    final allCategories = await SharedApi.categories();

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setStateDialog) {
        return AlertDialog(
          title: const Text('תחומים'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allCategories.map((c) {
                  final id = c['id'] as int;
                  final name = c['name'] as String;
                  return FilterChip(
                    label: Text(name),
                    selected: selected.contains(id),
                    onSelected: (yes) => setStateDialog(() {
                      if (yes) {
                        selected.add(id);
                      } else {
                        selected.remove(id);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ביטול')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('שמור')),
          ],
        );
      }),
    );
    if (ok != true) return;

    final originalIds = currentIndustries.map((c) => c['id'] as int).toSet();
    final toAdd = selected.difference(originalIds);
    final toRemove = originalIds.difference(selected);
    try {
      for (final id in toAdd) {
        await EmployeeApi.addIndustry(id);
      }
      for (final id in toRemove) {
        await EmployeeApi.removeIndustry(id);
      }
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('פרטים אישיים')),
      body: SurfaceGradientBackground(
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ErrorView(message: snap.error.toString(), onRetry: _refresh);
              }
              final user = snap.data!;
              final profile = (user['profile'] ?? {}) as Map<String, dynamic>;
              final industries = (user['industries'] ?? []) as List<dynamic>;
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _AvatarHeader(
                      avatarUrl: profile['avatar_url'] as String?,
                      fullName: user['full_name'] as String? ?? '',
                      onTap: _pickAvatar,
                    ),
                    const SizedBox(height: 24),
                    _Section(title: 'פרטי קשר', items: [
                      _Item(
                        icon: Icons.person_outline,
                        label: 'שם מלא',
                        value: user['full_name'] as String?,
                        onTap: () => _editField(
                          title: 'שם מלא',
                          backendKey: 'full_name',
                          currentValue: user['full_name'] as String?,
                        ),
                      ),
                      _Item(icon: Icons.phone_outlined, label: 'טלפון', value: user['phone'] as String?),
                      _Item(
                        icon: Icons.email_outlined,
                        label: 'אימייל',
                        value: user['email'] as String? ?? 'לא הוגדר',
                        onTap: () => _editField(
                          title: 'אימייל',
                          backendKey: 'email',
                          currentValue: user['email'] as String?,
                          keyboard: TextInputType.emailAddress,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _Section(title: 'פרטים אישיים', items: [
                      _Item(
                        icon: Icons.cake_outlined,
                        label: 'תאריך לידה',
                        value: profile['date_of_birth'] != null
                            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(profile['date_of_birth'] as String))
                            : 'לא הוגדר',
                      ),
                      _Item(
                        icon: Icons.work_outline,
                        label: 'סטטוס עבודה',
                        value: _workStatusLabel(profile['work_status'] as String?),
                        onTap: () => _editWorkStatus(profile['work_status'] as String? ?? 'freelancer'),
                      ),
                      _Item(
                        icon: Icons.payments_outlined,
                        label: 'שכר בסיס לשעה',
                        value: profile['base_hourly_rate'] != null
                            ? '₪${profile['base_hourly_rate']}'
                            : 'לא הוגדר',
                        onTap: () => _editField(
                          title: 'שכר בסיס לשעה (₪)',
                          backendKey: 'base_hourly_rate',
                          currentValue: profile['base_hourly_rate']?.toString(),
                          keyboard: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      _Item(
                        icon: Icons.tune,
                        label: 'טווח חיפוש',
                        value: profile['location_range_km'] != null
                            ? '${profile['location_range_km']} ק"מ'
                            : 'לא הוגדר',
                        onTap: () => _editRange((profile['location_range_km'] as num?)?.toInt() ?? 30),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'תחומים',
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _manageIndustries(industries),
                      ),
                      items: industries.isEmpty
                          ? [const _Item(icon: Icons.label_outline, label: '—', value: 'לא נבחרו תחומים')]
                          : industries
                              .map((c) => _Item(icon: Icons.label_outline, label: c['name'] as String))
                              .toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _workStatusLabel(String? value) {
    switch (value) {
      case 'freelancer':
        return 'פרילנסר';
      case 'self_employed':
        return 'עצמאי';
      default:
        return 'לא הוגדר';
    }
  }
}

class _AvatarHeader extends StatelessWidget {
  final String? avatarUrl;
  final String fullName;
  final VoidCallback onTap;
  const _AvatarHeader({required this.avatarUrl, required this.fullName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = fullName.isNotEmpty ? fullName.characters.first : '?';
    final fullUrl = avatarUrl != null ? '$kApiBaseUrl$avatarUrl' : null;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [FindlyColors.gradientMid, FindlyColors.gradientBottom],
                ),
                shape: BoxShape.circle,
                image: fullUrl != null
                    ? DecorationImage(image: NetworkImage(fullUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: fullUrl != null
                  ? null
                  : Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.heebo(fontSize: 44, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: FindlyColors.brandPurple,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_Item> items;
  final Widget? trailing;
  const _Section({required this.title, required this.items, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.heebo(fontSize: 13, fontWeight: FontWeight.w600, color: FindlyColors.textSecondary),
                ),
              ),
              if (trailing != null) trailing!,
            ]),
          ),
          ...items,
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  const _Item({required this.icon, required this.label, this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: FindlyColors.brandPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: FindlyColors.brandPurple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary)),
                  if (value != null)
                    Text(value!, style: GoogleFonts.heebo(fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_left, color: FindlyColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
