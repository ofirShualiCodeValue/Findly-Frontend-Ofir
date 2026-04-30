import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/employer_api.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _venue = TextEditingController();
  final _description = TextEditingController();
  final _budget = TextEditingController();
  final _required = TextEditingController(text: '1');
  DateTime? _startAt;
  DateTime? _endAt;
  int? _categoryId;
  int? _areaId;
  bool _saving = false;
  String? _error;
  bool _loadingTaxonomies = true;
  List<dynamic> _categories = [];
  List<dynamic> _areas = [];

  @override
  void initState() {
    super.initState();
    _loadTaxonomies();
  }

  Future<void> _loadTaxonomies() async {
    try {
      final results = await Future.wait([
        EmployerApi.getCategories(),
        EmployerApi.getAreas(),
      ]);
      setState(() {
        _categories = results[0];
        _areas = results[1];
        _loadingTaxonomies = false;
      });
    } catch (e) {
      setState(() {
        _error = 'נכשל לטעון רשימות';
        _loadingTaxonomies = false;
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final base = isStart ? (_startAt ?? DateTime.now()) : (_endAt ?? _startAt ?? DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    setState(() {
      final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        _startAt = dt;
      } else {
        _endAt = dt;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startAt == null || _endAt == null || _categoryId == null || _areaId == null) {
      setState(() => _error = 'יש למלא את כל השדות');
      return;
    }
    if (!_endAt!.isAfter(_startAt!)) {
      setState(() => _error = 'שעת סיום חייבת להיות אחרי שעת התחלה');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await EmployerApi.createEvent({
        'name': _name.text.trim(),
        'venue': _venue.text.trim().isEmpty ? null : _venue.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'event_category_id': _categoryId,
        'activity_area_id': _areaId,
        'start_at': _startAt!.toIso8601String(),
        'end_at': _endAt!.toIso8601String(),
        'budget': double.tryParse(_budget.text.trim()) ?? 0,
        'required_employees': int.tryParse(_required.text.trim()) ?? 1,
        'status': 'active',
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    if (_loadingTaxonomies) {
      return Scaffold(
        appBar: AppBar(title: const Text('יצירת אירוע')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('יצירת אירוע חדש')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'שם האירוע *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'חובה' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'סוג אירוע *', border: OutlineInputBorder()),
              items: _categories
                  .map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(c['name'] as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _areaId,
              decoration: const InputDecoration(labelText: 'אזור *', border: OutlineInputBorder()),
              items: _areas
                  .map<DropdownMenuItem<int>>((a) => DropdownMenuItem(
                        value: a['id'] as int,
                        child: Text(a['name'] as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _areaId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _venue,
              decoration: const InputDecoration(labelText: 'מקום (כתובת)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: Colors.grey.withValues(alpha: 0.1),
              title: Text(_startAt != null ? 'התחלה: ${df.format(_startAt!)}' : 'בחר שעת התחלה *'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isStart: true),
            ),
            const SizedBox(height: 8),
            ListTile(
              tileColor: Colors.grey.withValues(alpha: 0.1),
              title: Text(_endAt != null ? 'סיום: ${df.format(_endAt!)}' : 'בחר שעת סיום *'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isStart: false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _budget,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'תקציב (₪)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _required,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'כמות עובדים נדרשים', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'תיאור', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('צור אירוע', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
