import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/employee_api.dart';
import '../../store/auth_store.dart';
import '../../theme.dart';
import '../../widgets/error_view.dart';
import '../../widgets/gradient_background.dart';
import 'profile_tab.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _bottomTab = 0;

  @override
  Widget build(BuildContext context) {
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
  late Future<List<dynamic>> _future;
  // Map eventId -> application from the user's /applications endpoint, used
  // to overlay status badges on cards.
  Map<int, Map<String, dynamic>> _appsByEventId = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async {
    final results = await Future.wait([
      EmployeeApi.browseEvents(tab: _segment),
      EmployeeApi.myApplications(),
    ]);
    final events = results[0];
    final apps = results[1];
    _appsByEventId = {
      for (final a in apps) (a['event_id'] as int): Map<String, dynamic>.from(a),
    };
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
    final amountCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('הגשת מועמדות: ${event['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('כמה אתה מבקש לסך כל שעות האירוע?', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'הצעת מחיר (₪)', border: OutlineInputBorder()),
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

  Future<void> _reportHours(Map<String, dynamic> app) async {
    final hoursCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('דיווח שעות'),
        content: TextField(
          controller: hoursCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'שעות', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ביטול')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('שלח')),
        ],
      ),
    );
    if (ok != true) return;
    final hours = double.tryParse(hoursCtrl.text.trim());
    if (hours == null || hours < 0 || hours > 24) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('הזן בין 0 ל-24')));
      return;
    }
    try {
      await EmployeeApi.reportHours(app['id'] as int, hours);
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
                    final events = snap.data ?? [];
                    if (events.isEmpty) {
                      return ListView(children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            _segment == 'offers'
                                ? 'אין כרגע הצעות עבודה שמתאימות'
                                : 'אין משמרות פעילות',
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
              Stack(children: [
                IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
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
  final String segment;
  const _EventCard({
    required this.event,
    required this.application,
    required this.onApply,
    required this.onDismiss,
    required this.onReportHours,
    required this.segment,
  });

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(event['start_at'] as String);
    final end = DateTime.parse(event['end_at'] as String);
    final dayName = DateFormat('EEEE', 'he').format(start);
    final timeRange = '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}';
    final emp = event['employer'] as Map<String, dynamic>?;
    final sub = event['industry_sub_category'] as Map<String, dynamic>?;
    final venue = (event['venue'] as String?) ?? '';

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
          Text(
            timeRange,
            style: GoogleFonts.heebo(fontSize: 16, fontWeight: FontWeight.w700),
          ),
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
            ),
        ],
      ),
    );
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
