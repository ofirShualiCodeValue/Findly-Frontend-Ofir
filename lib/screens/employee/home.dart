import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/employee_api.dart';
import '../../store/auth_store.dart';
import '../../theme.dart';
import '../../widgets/calendar_strip.dart';
import '../../widgets/error_view.dart';
import '../../widgets/findly_alert.dart';
import '../../widgets/gradient_background.dart';
import '../auth/phone_entry.dart';
import '../employer/home.dart';
import 'notifications.dart';
import 'profile_tab.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _bottomTab = 0;

  @override
  void initState() {
    super.initState();
    // Defensive routing — guarantees no employer ever lands here.
    WidgetsBinding.instance.addPostFrameCallback((_) => _enforceRole());
  }

  void _enforceRole() {
    if (!mounted) return;
    final role = authStore.role;
    if (role == 'employee') return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => role == 'employer' ? const EmployerHomeScreen() : const PhoneEntryScreen(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (authStore.role != 'employee') {
      // Render nothing while the post-frame redirect runs.
      return const SizedBox.shrink();
    }
    return Scaffold(
      body: IndexedStack(
        index: _bottomTab,
        children: const [
          _HomeFeed(),
          EmployeeProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomTab,
        onDestinationSelected: (i) => setState(() => _bottomTab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'בית'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'פרופיל'),
        ],
      ),
    );
  }
}

/// Top-level employee feed: greeting header + segmented (Job Offers / My Shifts)
/// + a list of event cards matching the Figma.
class _HomeFeed extends StatefulWidget {
  const _HomeFeed();

  @override
  State<_HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<_HomeFeed> {
  // The segmented control's value: 'offers' or 'shifts'.
  String _segment = 'offers';
  // Selected date for the calendar strip filter; null = no filter.
  DateTime? _selectedDate;
  late Future<List<dynamic>> _future;
  // Map eventId -> application from the user's /applications endpoint, used
  // to overlay status badges on cards.
  Map<int, Map<String, dynamic>> _appsByEventId = {};
  /// The employee's base hourly rate, used to pre-fill the apply price.
  /// Loaded once from /v1/employee/profile alongside the events list.
  double? _baseHourlyRate;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async {
    final results = await Future.wait([
      EmployeeApi.browseEvents(tab: _segment),
      EmployeeApi.myApplications(),
      // Profile gives us base_hourly_rate for pre-filling apply prices.
      // Treat failure as soft — the rate just won't pre-fill.
      EmployeeApi.getProfile().catchError((_) => <String, dynamic>{}),
    ]);
    final events = results[0] as List<dynamic>;
    final apps = results[1] as List<dynamic>;
    final profile = results[2] as Map<String, dynamic>;
    _appsByEventId = {
      for (final a in apps) (a['event_id'] as int): Map<String, dynamic>.from(a),
    };
    final rateRaw = profile['profile']?['base_hourly_rate'];
    _baseHourlyRate = rateRaw == null ? null : double.tryParse(rateRaw.toString());
    return events;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _markNotInterested(int eventId) async {
    try {
      await EmployeeApi.markInterest(eventId, 'not_interested');
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _apply(Map<String, dynamic> event) async {
    final shiftHours = _totalShiftHours(event);
    final preFill = (_baseHourlyRate != null && shiftHours > 0)
        ? (_baseHourlyRate! * shiftHours).toStringAsFixed(0)
        : '';
    final amountCtrl = TextEditingController(text: preFill);
    final hint = (_baseHourlyRate != null && shiftHours > 0)
        ? '₪${_baseHourlyRate!.toStringAsFixed(0)} × ${shiftHours.toStringAsFixed(1)} שעות'
        : 'הצעת מחיר';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('הגשת מועמדות: ${event['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              preFill.isEmpty
                  ? 'כמה אתה מבקש לסך כל שעות המשמרת?'
                  : 'חושב לפי שכר הבסיס שהגדרת. אפשר לשנות.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'הצעת מחיר (₪)',
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ביטול')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('הגש מועמדות')),
        ],
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount < 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('סכום לא תקין')));
      return;
    }
    try {
      await EmployeeApi.apply(event['id'] as int, amount);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('המועמדות נשלחה')));
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Sum of all active shifts on the event in hours. Used to suggest a
  /// proposed amount = base_hourly_rate × hours when applying.
  double _totalShiftHours(Map<String, dynamic> event) {
    final shifts = (event['shifts'] as List?) ?? const [];
    double total = 0;
    for (final s in shifts) {
      final start = DateTime.tryParse(s['start_at'] as String? ?? '');
      final end = DateTime.tryParse(s['end_at'] as String? ?? '');
      if (start != null && end != null) {
        total += end.difference(start).inMinutes / 60.0;
      }
    }
    return total;
  }

  /// Two-stage cancellation: first call returns 409 + CANCELLATION_POLICY_LATE
  /// when within 48 h of the shift, prompting the policy popup. The second
  /// call passes force=true to confirm.
  Future<void> _cancelApplication(Map<String, dynamic> app) async {
    final id = app['id'] as int;
    try {
      await EmployeeApi.cancelApplication(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('המועמדות בוטלה')));
      _refresh();
    } on ApiException catch (e) {
      if (e.errorCode == 'CANCELLATION_POLICY_LATE') {
        if (!mounted) return;
        final force = await _showCancellationPolicyDialog(e.data);
        if (force == true) {
          try {
            await EmployeeApi.cancelApplication(id, force: true);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('המועמדות בוטלה')));
            _refresh();
          } on ApiException catch (e2) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e2.message)));
          }
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<bool?> _showCancellationPolicyDialog(Map<String, dynamic>? data) async {
    final hours = (data?['hours_until_shift'] as num?)?.toDouble() ?? 0;
    final threshold = (data?['policy_threshold_hours'] as num?)?.toInt() ?? 48;
    final picked = await showFindlyAlert(
      context,
      badge: FindlyAlertBadge.icon(Icons.warning_amber_rounded),
      title: 'מדיניות ביטול',
      message:
          'הביטול נעשה פחות מ-$threshold שעות לפני תחילת המשמרת '
          '(נותרו ${hours.toStringAsFixed(1)} שעות).\n'
          'ביטול מאוחר עלול לפגוע בדירוג שלך אצל המעסיק. להמשיך לבטל?',
      actions: const [
        FindlyAlertAction(
          label: 'בטל בכל זאת',
          backgroundColor: FindlyColors.warningRed,
        ),
        FindlyAlertAction(label: 'להישאר במשמרת', primary: false),
      ],
    );
    if (picked == 0) return true;
    if (picked == 1) return false;
    return null;
  }

  Future<void> _reportHours(Map<String, dynamic> app) async {
    // Prefill the pickers from the shift's scheduled times — workers usually
    // come in on time, so the most common case is "tap submit". Workers who
    // came late / left early adjust the times by a few minutes.
    final event = app['event'] as Map<String, dynamic>?;
    if (event == null) return;
    final scheduledStart = DateTime.parse(event['start_at'] as String).toLocal();
    final scheduledEnd = DateTime.parse(event['end_at'] as String).toLocal();

    final result = await showDialog<({DateTime startAt, DateTime endAt})>(
      context: context,
      builder: (_) => _ReportShiftTimesDialog(
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
      ),
    );
    if (result == null) return;

    try {
      await EmployeeApi.reportShiftTimes(
        app['id'] as int,
        startAt: result.startAt,
        endAt: result.endAt,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('הדיווח נשלח')));
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceGradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            _Header(),
            const SizedBox(height: 12),
            CalendarStrip(
              selectedDate: _selectedDate ?? DateUtils.dateOnly(DateTime.now()),
              onDateSelected: (d) => setState(() {
                final today = DateUtils.dateOnly(DateTime.now());
                final picked = DateUtils.dateOnly(d);
                // Tap the same date twice → clear the filter.
                if (_selectedDate != null && DateUtils.isSameDay(_selectedDate!, picked)) {
                  _selectedDate = null;
                } else if (DateUtils.isSameDay(picked, today) && _selectedDate == null) {
                  _selectedDate = picked;
                } else {
                  _selectedDate = picked;
                }
              }),
            ),
            const SizedBox(height: 12),
            _SegmentedTabs(
              value: _segment,
              onChanged: (v) {
                setState(() {
                  _segment = v;
                  _future = _load();
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<dynamic>>(
                  future: _future,
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return ErrorView(message: snap.error.toString(), onRetry: _refresh);
                    }
                    final allEvents = snap.data ?? [];
                    final events = _selectedDate == null
                        ? allEvents
                        : allEvents.where((e) {
                            final start = DateTime.parse(e['start_at'] as String);
                            return DateUtils.isSameDay(start, _selectedDate);
                          }).toList();
                    if (events.isEmpty) {
                      String message;
                      if (_selectedDate != null) {
                        message = 'אין אירועים בתאריך הזה';
                      } else if (_segment == 'offers') {
                        message = 'אין כרגע הצעות עבודה שמתאימות';
                      } else {
                        message = 'אין משמרות פעילות';
                      }
                      return ListView(children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            message,
                            style: const TextStyle(color: FindlyColors.textSecondary, fontSize: 16),
                          ),
                        ),
                      ]);
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: events.length,
                      itemBuilder: (_, i) {
                        final ev = Map<String, dynamic>.from(events[i]);
                        return _EventCard(
                          event: ev,
                          application: _appsByEventId[ev['id'] as int],
                          onApply: () => _apply(ev),
                          onDismiss: () => _markNotInterested(ev['id'] as int),
                          onReportHours: () {
                            final a = _appsByEventId[ev['id'] as int];
                            if (a != null) _reportHours(a);
                          },
                          onCancel: () {
                            final a = _appsByEventId[ev['id'] as int];
                            if (a != null) _cancelApplication(a);
                          },
                          segment: _segment,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE, d בMMMM', 'he');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _AvatarBubble(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  df.format(DateTime.now()),
                  style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textSecondary),
                ),
              ),
              Builder(
                builder: (ctx) => Stack(children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('עדכונים')),
                          body: const EmployeeNotificationsTab(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'מחכים לך כאן\nכמה אירועים שווים',
            style: GoogleFonts.heebo(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble();
  @override
  Widget build(BuildContext context) {
    final initial = (authStore.fullName ?? '?').characters.firstOrNull ?? '?';
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [FindlyColors.gradientMid, FindlyColors.gradientBottom],
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.heebo(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _SegmentedTabs({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _segment(label: 'הצעות עבודה', val: 'offers'),
            _segment(label: 'המשמרות שלי', val: 'shifts'),
          ],
        ),
      ),
    );
  }

  Widget _segment({required String label, required String val}) {
    final selected = value == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? FindlyColors.brandPurple.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Text(
            label,
            style: GoogleFonts.heebo(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? FindlyColors.brandPurple : FindlyColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final Map<String, dynamic>? application;
  final VoidCallback onApply;
  final VoidCallback onDismiss;
  final VoidCallback onReportHours;
  final VoidCallback onCancel;
  final String segment;
  const _EventCard({
    required this.event,
    required this.application,
    required this.onApply,
    required this.onDismiss,
    required this.onReportHours,
    required this.onCancel,
    required this.segment,
  });

  @override
  Widget build(BuildContext context) {
    final eventStart = DateTime.parse(event['start_at'] as String);
    final eventEnd = DateTime.parse(event['end_at'] as String);
    // Prefer shift times — events span the whole day by default; only the
    // shift carries the real working window the employer entered.
    final shifts = (event['shifts'] as List?) ?? const [];
    final firstShift =
        shifts.isNotEmpty ? Map<String, dynamic>.from(shifts.first) : null;
    final start = firstShift != null
        ? DateTime.parse(firstShift['start_at'] as String)
        : eventStart;
    final end = firstShift != null
        ? DateTime.parse(firstShift['end_at'] as String)
        : eventEnd;
    final dayName = DateFormat('EEEE', 'he').format(start);
    final timeRange = '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}';
    final emp = event['employer'] as Map<String, dynamic>?;
    final sub = event['industry_sub_category'] as Map<String, dynamic>?;
    final venue = (event['venue'] as String?) ?? '';
    final extraShifts = shifts.length > 1 ? shifts.length - 1 : 0;

    final statusInfo = _statusFor(application, segment, start);
    final canReportHours = application != null &&
        application!['status'] == 'approved' &&
        end.isBefore(DateTime.now()) &&
        application!['hours_status'] != 'approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (statusInfo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusInfo.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusInfo.label,
                    style: GoogleFonts.heebo(fontSize: 12, color: statusInfo.color, fontWeight: FontWeight.w600),
                  ),
                ),
              const Spacer(),
              _DateBadge(date: start, dayName: dayName),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text(
              timeRange,
              style: GoogleFonts.heebo(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (extraShifts > 0) ...[
              const SizedBox(width: 8),
              Text(
                '+$extraShifts משמרות',
                style: GoogleFonts.heebo(
                    fontSize: 12, color: FindlyColors.brandPurple, fontWeight: FontWeight.w600),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          Text(
            [if (venue.isNotEmpty) venue, if (emp?['business_name'] != null) emp!['business_name']]
                .join(' | '),
            style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary),
          ),
          if (sub?['name'] != null) ...[
            const SizedBox(height: 2),
            Text(sub!['name'] as String,
                style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textPrimary)),
          ],
          const SizedBox(height: 8),
          Text(
            'תשלום צפוי למשמרת: ₪${event['budget']}',
            style: GoogleFonts.heebo(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (segment == 'offers' && application == null)
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: onApply,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                  child: const Text('הגש מועמדות'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onDismiss,
                tooltip: 'לא רלוונטי',
              ),
            ])
          else if (canReportHours)
            FilledButton.icon(
              onPressed: onReportHours,
              icon: const Icon(Icons.schedule),
              label: const Text('דווח שעות'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            )
          else if (canCancel)
            OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('ביטול מועמדות'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            ),
        ],
      ),
    );
  }

  bool get canCancel {
    if (application == null) return false;
    final status = application!['status'];
    return status == 'pending' || status == 'approved';
  }

  _StatusInfo? _statusFor(Map<String, dynamic>? app, String segment, DateTime start) {
    if (app == null) {
      // No application yet — only "Job Offers" tab gets a "חדש" badge.
      if (segment == 'offers') {
        return _StatusInfo(label: 'חדש', color: FindlyColors.successGreen);
      }
      return null;
    }
    switch (app['status'] as String?) {
      case 'pending':
        return _StatusInfo(label: 'ממתין לאישור', color: FindlyColors.textSecondary);
      case 'approved':
        return _StatusInfo(label: 'אושר', color: FindlyColors.successGreen);
      case 'rejected':
      case 'cancelled_by_employer':
      case 'cancelled_by_employee':
        return _StatusInfo(label: 'בוטל', color: FindlyColors.warningRed);
    }
    return null;
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime date;
  final String dayName;
  const _DateBadge({required this.date, required this.dayName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FindlyColors.brandPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(dayName, style: GoogleFonts.heebo(fontSize: 11, color: FindlyColors.textSecondary)),
          Text(
            '${date.day}',
            style: GoogleFonts.heebo(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          Text(DateFormat('MMM', 'he').format(date),
              style: GoogleFonts.heebo(fontSize: 11, color: FindlyColors.textSecondary)),
        ],
      ),
    );
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  _StatusInfo({required this.label, required this.color});
}

/// Two-time-picker dialog. Used by both the employee (to report) and —
/// reused via copy of the same UX shape — by the employer (to edit before
/// approving). Each picker preserves the DATE of the original shift
/// timestamp it was seeded from, so end-on-the-next-day shifts (like a
/// late-night wedding) keep working without a date picker.
class _ReportShiftTimesDialog extends StatefulWidget {
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  const _ReportShiftTimesDialog({
    required this.scheduledStart,
    required this.scheduledEnd,
  });

  @override
  State<_ReportShiftTimesDialog> createState() => _ReportShiftTimesDialogState();
}

class _ReportShiftTimesDialogState extends State<_ReportShiftTimesDialog> {
  late DateTime _startAt = widget.scheduledStart;
  late DateTime _endAt = widget.scheduledEnd;
  String? _error;

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startAt : _endAt),
    );
    if (picked == null) return;
    setState(() {
      _error = null;
      if (isStart) {
        // Replace start's time on its existing date.
        _startAt = DateTime(
          _startAt.year, _startAt.month, _startAt.day,
          picked.hour, picked.minute,
        );
        // If end is now ≤ start, push end forward 24h until it isn't —
        // covers shifts that cross midnight (start 22:00 → end 02:00).
        while (!_endAt.isAfter(_startAt)) {
          _endAt = _endAt.add(const Duration(hours: 24));
        }
      } else {
        // End is anchored on start's DATE plus the chosen time. If that
        // would land on/before start, advance one day so the duration
        // stays positive (overnight shift).
        var candidate = DateTime(
          _startAt.year, _startAt.month, _startAt.day,
          picked.hour, picked.minute,
        );
        if (!candidate.isAfter(_startAt)) {
          candidate = candidate.add(const Duration(hours: 24));
        }
        _endAt = candidate;
      }
    });
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  double get _hours => _endAt.difference(_startAt).inMinutes / 60.0;

  void _submit() {
    if (!_endAt.isAfter(_startAt)) {
      setState(() => _error = 'שעת סיום חייבת להיות אחרי שעת התחלה');
      return;
    }
    if (_hours > 24) {
      setState(() => _error = 'משך השיפט לא יכול לעלות על 24 שעות');
      return;
    }
    Navigator.of(context).pop((startAt: _startAt, endAt: _endAt));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('דיווח שעות'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_arrow_rounded),
            title: const Text('שעת התחלה'),
            subtitle: Text(_fmt(_startAt)),
            trailing: const Icon(Icons.edit_rounded, size: 18),
            onTap: () => _pickTime(true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.stop_rounded),
            title: const Text('שעת סיום'),
            subtitle: Text(_fmt(_endAt)),
            trailing: const Icon(Icons.edit_rounded, size: 18),
            onTap: () => _pickTime(false),
          ),
          const SizedBox(height: 8),
          Text(
            'סה״כ: ${_hours.toStringAsFixed(2)} שעות',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
        FilledButton(onPressed: _submit, child: const Text('שלח')),
      ],
    );
  }
}
