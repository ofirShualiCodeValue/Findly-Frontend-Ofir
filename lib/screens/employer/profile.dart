import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../api/employer_api.dart';
import '../../widgets/error_view.dart';

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
      setState(() {
        _profile = p;
        final business = p['business'] as Map<String, dynamic>?;
        _businessName.text = business?['business_name'] ?? '';
        _ownerName.text = business?['owner_name'] ?? '';
        _vat.text = business?['vat_number'] ?? '';
        _address.text = business?['address'] ?? '';
        _error = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('הפרופיל עודכן')));
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('הפרופיל שלי')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('הפרופיל שלי')),
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('הפרופיל שלי')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_profile!['full_name'] ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          Text(_profile!['phone'] ?? '', style: const TextStyle(color: Colors.grey)),
          const Divider(height: 32),
          const Text('פרטי עסק', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(controller: _businessName, decoration: const InputDecoration(labelText: 'שם העסק', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _ownerName, decoration: const InputDecoration(labelText: 'שם הבעלים', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _vat, decoration: const InputDecoration(labelText: 'מס\' עוסק', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'כתובת', border: OutlineInputBorder())),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('שמור שינויים'),
          ),
        ],
      ),
    );
  }
}
