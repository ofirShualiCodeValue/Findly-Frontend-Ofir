import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/employer_api.dart';
import '../../theme.dart';
import '../../widgets/confirm_modal.dart';

/// Common Israeli event venues — used as autocomplete suggestions while
/// the user types a venue. Free-form input is also accepted.
const List<String> _venueSuggestions = [
  'אולמי האחוזה, ראשון לציון',
  'היכל מנחם בגין, רמת גן',
  'מנורה מבטחים ארנה, תל אביב',
  'מתחם רידינג, תל אביב',
  'היכל התרבות, תל אביב',
  'הפעמון, רמת גן',
  'ארמונות חן, נהריה',
  'אולמי כפר המכביה, רמת גן',
  'מתחם פאוור פארק, חיפה',
  'מצודת דוד, ירושלים',
  'גני התערוכה, תל אביב',
  'מתחם ארנה, חיפה',
  'יד אליהו, תל אביב',
  'גני יהושע, תל אביב',
  'נמל תל אביב',
  'נמל יפו',
  'מתחם הסינמטק, ירושלים',
  'אולם בלומפילד, ירושלים',
  'בנייני האומה, ירושלים',
  'מתחם אירועים עין גדי',
  'גני עירייה, נתניה',
  'אולם פעמונים, ראשון לציון',
];

class CreateEventScreen extends StatefulWidget {
  /// Pre-fills the date picker with the day the employer was looking at on
  /// the home calendar. They can still change it inside the form.
  final DateTime? initialDate;
  const CreateEventScreen({super.key, this.initialDate});

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
  DateTime? _date; // single date — exact times come from shifts later
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
    _date = widget.initialDate;
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

  Future<void> _pickDate() async {
    final base = _date ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    setState(() => _date = DateUtils.dateOnly(date));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _categoryId == null || _areaId == null) {
      setState(() => _error = 'יש למלא תאריך, סוג אירוע ואזור');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Real start/end times will be set by shifts later. For now we mark the
      // event as spanning the whole calendar day so backend's start<end check
      // passes and the home calendar shows it on the correct day.
      final dayStart = DateTime(_date!.year, _date!.month, _date!.day, 0, 0, 0);
      final dayEnd = DateTime(_date!.year, _date!.month, _date!.day, 23, 59, 0);

      await EmployerApi.createEvent({
        'name': _name.text.trim(),
        'venue': _venue.text.trim().isEmpty ? null : _venue.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'event_category_id': _categoryId,
        'activity_area_id': _areaId,
        'start_at': dayStart.toIso8601String(),
        'end_at': dayEnd.toIso8601String(),
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
    final df = DateFormat('EEEE, d בMMMM yyyy', 'he');
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
            const SizedBox(height: 4),
            Text('שעות מדויקות יוגדרו בהמשך כשתוסיף משמרות',
                textAlign: TextAlign.center,
                style: GoogleFonts.heebo(color: FindlyColors.textSecondary, fontSize: 11)),
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
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Text(
                    _date != null ? df.format(_date!) : 'בחר תאריך',
                    style: GoogleFonts.heebo(
                      color: _date == null ? FindlyColors.textSecondary : FindlyColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            _Field(
              label: 'מקום האירוע',
              icon: Icons.place_rounded,
              child: _VenueAutocomplete(controller: _venue),
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
                isExpanded: true,
                // Show ~6 items, scroll for the rest (each item ≈ 48 px).
                menuMaxHeight: 6 * 48.0,
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
                isExpanded: true,
                items: _areas
                    .map<DropdownMenuItem<int>>((a) => DropdownMenuItem(
                          value: a['id'] as int,
                          child: Text(a['name'] as String),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _areaId = v),
              ),
            ),
            // "כמות עובדים נדרשים" intentionally omitted from the create-event
            // form. Staffing is determined per-shift, added later in the shifts flow.
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

/// Stateful so the FocusNode is stable across rebuilds. The previous
/// stateless version created a new FocusNode every build, which made the
/// autocomplete reset (suggestions only worked on the first character).
class _VenueAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  const _VenueAutocomplete({required this.controller});

  @override
  State<_VenueAutocomplete> createState() => _VenueAutocompleteState();
}

class _VenueAutocompleteState extends State<_VenueAutocomplete> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) {
        final query = value.text.trim();
        if (query.isEmpty) return const Iterable<String>.empty();
        return _venueSuggestions.where((v) => v.contains(query));
      },
      fieldViewBuilder: (_, c, fn, onSubmit) => TextFormField(
        controller: c,
        focusNode: fn,
        decoration: const InputDecoration(hintText: 'התחל להקליד כתובת או שם מקום…'),
      ),
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                shrinkWrap: true,
                itemBuilder: (_, i) {
                  final opt = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(opt),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.place_outlined, size: 18, color: FindlyColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(opt, style: GoogleFonts.heebo(fontSize: 13))),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
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
