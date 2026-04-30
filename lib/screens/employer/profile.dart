import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/client.dart';
import '../../api/employer_api.dart';
import '../../store/auth_store.dart';
import '../../theme.dart';
import '../../widgets/error_view.dart';
import '../../widgets/gradient_background.dart';

class EmployerProfileScreen extends StatefulWidget {
  const EmployerProfileScreen({super.key});

  @override
  State<EmployerProfileScreen> createState() => _EmployerProfileScreenState();
}

class _EmployerProfileScreenState extends State<EmployerProfileScreen> {
  Map<String, dynamic>? _profile;
  String? _error;
  bool _loading = true;
  final _businessName = TextEditingController();
  final _ownerName = TextEditingController();
  final _vat = TextEditingController();
  final _address = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await EmployerApi.getProfile();
      final business = p['business'] as Map<String, dynamic>?;
      setState(() {
        _profile = p;
        _businessName.text = business?['business_name'] ?? '';
        _ownerName.text = business?['owner_name'] ?? '';
        _vat.text = business?['vat_number'] ?? '';
        _address.text = business?['address'] ?? '';
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await EmployerApi.patchProfile({
        'business_name': _businessName.text.trim(),
        'owner_name': _ownerName.text.trim(),
        'vat_number': _vat.text.trim(),
        'address': _address.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('הפרופיל עודכן')));
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('המוביל שלי')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('המוביל שלי')),
        body: ErrorView(message: _error ?? 'נכשל לטעון פרופיל', onRetry: _load),
      );
    }
    final business = _profile!['business'] as Map<String, dynamic>?;
    return Scaffold(
      body: SurfaceGradientBackground(
        topGradientHeight: 280,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                const Spacer(),
                Text('המוביל שלי',
                    style: GoogleFonts.heebo(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                const SizedBox(width: 48),
              ]),
              const SizedBox(height: 8),
              _Avatar(name: _profile!['full_name'] ?? '?'),
              const SizedBox(height: 12),
              Text(_profile!['full_name'] ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.heebo(fontSize: 22, fontWeight: FontWeight.w700)),
              if (business?['business_name'] != null)
                Text(business!['business_name'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textSecondary)),
              const SizedBox(height: 24),
              _SectionTitle('פרטי עסק'),
              _Card(children: [
                _LabeledField('שם העסק', _businessName),
                const _Divider(),
                _LabeledField('שם הבעלים', _ownerName),
                const _Divider(),
                _LabeledField('מס׳ עוסק', _vat),
                const _Divider(),
                _LabeledField('כתובת', _address),
              ]),
              const SizedBox(height: 24),
              _SectionTitle('אזורי פעילות'),
              _Card(children: [
                _ReadonlyRow(label: 'אזורי שירות', value: _formatTaxonomy(_profile!['activity_areas'])),
                const _Divider(),
                _ReadonlyRow(label: 'סוגי אירועים', value: _formatTaxonomy(_profile!['event_categories'])),
              ]),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('שמור שינויים'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => authStore.clear(),
                style: TextButton.styleFrom(foregroundColor: FindlyColors.warningRed),
                child: const Text('התנתקות'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTaxonomy(dynamic raw) {
    if (raw is! List || raw.isEmpty) return 'לא נבחרו עדיין';
    return raw.map((e) => e['name']).join(' · ');
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first : '?';
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(initial,
              style: GoogleFonts.heebo(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(label,
          style: GoogleFonts.heebo(fontSize: 13, fontWeight: FontWeight.w700, color: FindlyColors.textSecondary)),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1));
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _LabeledField(this.label, this.controller);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );
  }
}

class _ReadonlyRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReadonlyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text('$label: ',
              style: GoogleFonts.heebo(color: FindlyColors.textSecondary, fontSize: 13)),
          Expanded(
            child: Text(value, style: GoogleFonts.heebo(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
