import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/employer_api.dart';
import '../../theme.dart';
import '../../widgets/confirm_modal.dart';

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
  bool _loadingTaxonomies = true;
  String? _error;
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

  Future<void> _confirmCancel() async {
    final ok = await showConfirmModal(
      context,
      icon: Icons.priority_high_rounded,
      title: 'לבטל את האירוע?',
      subtitle: 'ביטול האירוע ימחק את כל הפרטים שהזנתם.',
      cancelLabel: 'להשאיר אירוע',
      confirmLabel: 'לבטל אירוע',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingTaxonomies) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final df = DateFormat('dd/MM/yyyy HH:mm', 'he');
    return Scaffold(
      appBar: AppBar(
        title: const Text('יצירת אירוע חדש'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _confirmCancel),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Text('בואו נתחיל להקים את האירוע שלך',
                textAlign: TextAlign.center,
                style: GoogleFonts.heebo(color: FindlyColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            _Field(
              label: 'שם האירוע',
              child: TextFormField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'שם האירוע'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'חובה' : null,
              ),
            ),
            _Field(
              label: 'תאריך האירוע',
              icon: Icons.calendar_today_rounded,
              child: InkWell(
                onTap: () => _pickDate(isStart: true),
                child: InputDecorator(
                  decoration: InputDecoration(hintText: _startAt != null ? df.format(_startAt!) : 'בחר תאריך התחלה'),
                  child: Text(
                    _startAt != null ? df.format(_startAt!) : 'בחר תאריך התחלה',
                    style: GoogleFonts.heebo(
                      color: _startAt == null ? FindlyColors.textSecondary : FindlyColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            _Field(
              label: 'תאריך סיום',
              icon: Icons.event_rounded,
              child: InkWell(
                onTap: () => _pickDate(isStart: false),
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Text(
                    _endAt != null ? df.format(_endAt!) : 'בחר תאריך סיום',
                    style: GoogleFonts.heebo(
                      color: _endAt == null ? FindlyColors.textSecondary : FindlyColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            _Field(
              label: 'מקום האירוע',
              icon: Icons.place_rounded,
              child: TextFormField(
                controller: _venue,
                decoration: const InputDecoration(hintText: 'מתחם / כתובת'),
              ),
            ),
            _Field(
              label: 'תקציב לאירוע',
              icon: Icons.account_balance_wallet_rounded,
              child: TextFormField(
                controller: _budget,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '20,000', prefixText: '₪ '),
              ),
            ),
            _Field(
              label: 'סוג האירוע',
              icon: Icons.category_rounded,
              child: DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(hintText: 'בחר סוג אירוע'),
                items: _categories
                    .map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                          value: c['id'] as int,
                          child: Text(c['name'] as String),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            ),
            _Field(
              label: 'אזור',
              icon: Icons.map_rounded,
              child: DropdownButtonFormField<int>(
                initialValue: _areaId,
                decoration: const InputDecoration(hintText: 'בחר אזור'),
                items: _areas
                    .map<DropdownMenuItem<int>>((a) => DropdownMenuItem(
                          value: a['id'] as int,
                          child: Text(a['name'] as String),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _areaId = v),
              ),
            ),
            _Field(
              label: 'כמות עובדים נדרשים',
              icon: Icons.group_rounded,
              child: TextFormField(
                controller: _required,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '1'),
              ),
            ),
            _Field(
              label: 'תיאור אירוע',
              icon: Icons.notes_rounded,
              child: TextFormField(
                controller: _description,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'תיאור האירוע...'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FindlyColors.warningRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!, style: const TextStyle(color: FindlyColors.warningRed)),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('המשך'),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget child;
  const _Field({required this.label, this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Text(label,
                  style: GoogleFonts.heebo(fontSize: 13, fontWeight: FontWeight.w600, color: FindlyColors.textSecondary)),
            ]),
          ),
          Stack(
            children: [
              child,
              if (icon != null)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: FindlyColors.brandGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 16, color: FindlyColors.brandGreen),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
