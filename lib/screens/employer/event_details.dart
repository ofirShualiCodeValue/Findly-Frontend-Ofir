import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/employer_api.dart';
import '../../theme.dart';
import '../../widgets/confirm_modal.dart';
import '../../widgets/error_view.dart';
import '../../widgets/gradient_background.dart';

class EventDetailsScreen extends StatefulWidget {
  final int eventId;
  const EventDetailsScreen({super.key, required this.eventId});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> with TickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _event;
  List<dynamic> _messages = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        EmployerApi.getEvent(widget.eventId),
        EmployerApi.notificationHistory(widget.eventId),
      ]);
      setState(() {
        _event = results[0] as Map<String, dynamic>;
        _messages = results[1] as List<dynamic>;
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

  Future<void> _cancelEvent() async {
    final ok = await showConfirmModal(
      context,
      icon: Icons.priority_high_rounded,
      title: 'לבטל את האירוע?',
      subtitle: 'הפעולה תסמן את האירוע כבוטל. כל ההצעות הקיימות יקפאו.',
      cancelLabel: 'להשאיר אירוע',
      confirmLabel: 'לבטל אירוע',
    );
    if (!ok) return;
    try {
      await EmployerApi.cancelEvent(widget.eventId);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _sendNotification() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SendMessageSheet(titleCtrl: titleCtrl, bodyCtrl: bodyCtrl),
    );
    if (ok != true) return;
    try {
      final r = await EmployerApi.sendNotification(
        widget.eventId,
        titleCtrl.text.trim(),
        bodyCtrl.text.trim().isEmpty ? null : bodyCtrl.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [FindlyColors.gradientMid, FindlyColors.gradientBottom]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text('ההודעה נשלחה בהצלחה!',
                    style: GoogleFonts.heebo(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('נשלח ל-${r["recipient_count"]} עובדים מאושרים',
                    style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('סגור'),
                ),
              ],
            ),
          ),
        ),
      );
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('פרטי אירוע')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('פרטי אירוע')),
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }
    final e = _event!;
    final cancelled = e['status'] == 'cancelled';

    return Scaffold(
      body: SurfaceGradientBackground(
        topGradientHeight: 280,
        child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                pinned: false,
                automaticallyImplyLeading: false,
                title: Row(children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                  Expanded(
                    child: Text(
                      e['name'] as String? ?? '',
                      style: GoogleFonts.heebo(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (!cancelled)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (v) {
                        if (v == 'cancel') _cancelEvent();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'cancel', child: Text('בטל אירוע')),
                      ],
                    ),
                ]),
              ),
              SliverToBoxAdapter(child: _DetailsCard(event: e)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabs,
                    indicatorColor: FindlyColors.brandPurple,
                    labelColor: FindlyColors.textPrimary,
                    unselectedLabelColor: FindlyColors.textSecondary,
                    labelStyle: GoogleFonts.heebo(fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: const [
                      Tab(text: 'הודעות כלליות'),
                      Tab(text: 'משמרות'),
                      Tab(text: 'עובדים'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                _MessagesTab(messages: _messages),
                _ShiftsTab(event: e),
                _ApplicantsTab(
                  eventId: widget.eventId,
                  eventEndAt: DateTime.tryParse(e['end_at'] as String? ?? ''),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: cancelled
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('שליחת הודעה לעובדים'),
                  onPressed: _sendNotification,
                ),
              ),
            ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 8;
  @override
  double get maxExtent => tabBar.preferredSize.height + 8;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: FindlyColors.appBackground,
      padding: const EdgeInsets.only(top: 8),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_) => false;
}

class _DetailsCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _DetailsCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE | dd/MM/yyyy', 'he');
    final start = DateTime.tryParse(event['start_at'] as String? ?? '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('פרטי האירוע',
                    style: GoogleFonts.heebo(fontSize: 16, fontWeight: FontWeight.w700, color: FindlyColors.textPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [FindlyColors.gradientMid, FindlyColors.gradientBottom]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event_rounded, color: Colors.white, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (start != null) _InfoRow(label: 'תאריך', value: df.format(start)),
            if (event['venue'] != null) _InfoRow(label: 'מקום', value: event['venue'] as String),
            _InfoRow(label: 'משמרות', value: '${event['required_employees']}'),
            _InfoRow(label: 'תקציב', value: '₪${event['budget']}', valueColor: FindlyColors.brandGreen),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: GoogleFonts.heebo(color: FindlyColors.textSecondary, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.heebo(
                  color: valueColor ?? FindlyColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                )),
          ),
        ],
      ),
    );
  }
}

class _ApplicantsTab extends StatefulWidget {
  final int eventId;
  final DateTime? eventEndAt;
  const _ApplicantsTab({required this.eventId, required this.eventEndAt});

  @override
  State<_ApplicantsTab> createState() => _ApplicantsTabState();
}

class _ApplicantsTabState extends State<_ApplicantsTab> {
  String _statusFilter = 'all'; // 'all' | one of EventApplicationStatus
  String _sortBy = 'created_at';
  double? _minRating;
  late Future<List<dynamic>> _appsFuture;
  Map<String, dynamic>? _capacity;

  @override
  void initState() {
    super.initState();
    _appsFuture = _loadApps();
    _loadCapacity();
  }

  Future<List<dynamic>> _loadApps() {
    return EmployerApi.listApplications(
      widget.eventId,
      status: _statusFilter == 'all' ? null : _statusFilter,
      minRating: _minRating,
      sortBy: _sortBy,
    );
  }

  Future<void> _loadCapacity() async {
    try {
      final c = await EmployerApi.getCapacity(widget.eventId);
      if (mounted) setState(() => _capacity = c);
    } catch (_) {
      // Capacity is decorative — silent failure is fine.
    }
  }

  Future<void> _refresh() async {
    setState(() => _appsFuture = _loadApps());
    await _loadCapacity();
    await _appsFuture;
  }

  Future<void> _decide(int appId, String status) async {
    try {
      await EmployerApi.decideApplication(widget.eventId, appId, status);
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _rate(Map<String, dynamic> app) async {
    final result = await showDialog<({int rating, String? comment})>(
      context: context,
      builder: (_) => _RateWorkerDialog(application: app),
    );
    if (result == null) return;
    try {
      await EmployerApi.rateWorker(
        widget.eventId,
        app['id'] as int,
        rating: result.rating,
        comment: result.comment,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('הדירוג נשמר')));
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  bool get _eventEnded =>
      widget.eventEndAt != null && widget.eventEndAt!.isBefore(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_capacity != null) _CapacityBanner(capacity: _capacity!),
        _FilterBar(
          statusFilter: _statusFilter,
          sortBy: _sortBy,
          minRating: _minRating,
          onStatusChanged: (v) => setState(() {
            _statusFilter = v;
            _appsFuture = _loadApps();
          }),
          onSortChanged: (v) => setState(() {
            _sortBy = v;
            _appsFuture = _loadApps();
          }),
          onMinRatingChanged: (v) => setState(() {
            _minRating = v;
            _appsFuture = _loadApps();
          }),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<dynamic>>(
              future: _appsFuture,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ErrorView(message: snap.error.toString(), onRetry: _refresh);
                }
                final apps = snap.data ?? [];
                if (apps.isEmpty) {
                  return ListView(children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text('אין מועמדים שעונים לסינון',
                          style: GoogleFonts.heebo(color: FindlyColors.textSecondary)),
                    ),
                  ]);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: apps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ApplicantCard(
                    application: Map<String, dynamic>.from(apps[i]),
                    canRate: _eventEnded,
                    onDecide: (status) => _decide(apps[i]['id'] as int, status),
                    onRate: () => _rate(Map<String, dynamic>.from(apps[i])),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CapacityBanner extends StatelessWidget {
  final Map<String, dynamic> capacity;
  const _CapacityBanner({required this.capacity});

  @override
  Widget build(BuildContext context) {
    final state = capacity['state'] as String? ?? 'under';
    final filled = capacity['total_filled'] as int? ?? 0;
    final required = capacity['total_required'] as int? ?? 0;
    final shifts = (capacity['shifts'] as List? ?? const []).length;
    final (color, label) = switch (state) {
      'met' => (FindlyColors.brandGreen, 'איוש מלא'),
      'over' => (FindlyColors.brandPurple, 'אויש מעל הנדרש'),
      _ => (FindlyColors.pendingBlue, 'בתהליך איוש'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.group_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'איוש: $filled / $required ${required == 0 ? '(אין משמרות מוגדרות)' : ''} • $shifts משמרות',
                style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textPrimary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: Text(label,
                  style: GoogleFonts.heebo(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String statusFilter;
  final String sortBy;
  final double? minRating;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<double?> onMinRatingChanged;
  const _FilterBar({
    required this.statusFilter,
    required this.sortBy,
    required this.minRating,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onMinRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(children: [
          _Pill(
            label: 'סטטוס: ${_statusLabel(statusFilter)}',
            onTap: () async {
              final picked = await _showOptions(context, 'סטטוס', {
                'all': 'הכל',
                'pending': 'ממתין',
                'approved': 'מאושרים',
                'rejected': 'נדחים',
              }, statusFilter);
              if (picked != null) onStatusChanged(picked);
            },
          ),
          const SizedBox(width: 8),
          _Pill(
            label: 'מיון: ${_sortLabel(sortBy)}',
            onTap: () async {
              final picked = await _showOptions(context, 'מיון לפי', {
                'created_at': 'תאריך הגשה',
                'price': 'מחיר',
                'rating': 'דירוג',
              }, sortBy);
              if (picked != null) onSortChanged(picked);
            },
          ),
          const SizedBox(width: 8),
          _Pill(
            label: minRating == null ? 'דירוג מינ׳: כולם' : 'דירוג מינ׳: ${minRating!.toStringAsFixed(0)}+',
            onTap: () async {
              final picked = await _showOptions<double?>(
                context,
                'דירוג מינימלי',
                {null: 'כולם', 1.0: '1+', 2.0: '2+', 3.0: '3+', 4.0: '4+', 5.0: '5'},
                minRating,
              );
              onMinRatingChanged(picked);
            },
          ),
        ]),
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
        'pending' => 'ממתין',
        'approved' => 'מאושרים',
        'rejected' => 'נדחים',
        _ => 'הכל',
      };
  String _sortLabel(String s) => switch (s) {
        'price' => 'מחיר',
        'rating' => 'דירוג',
        _ => 'תאריך',
      };

  Future<T?> _showOptions<T>(
    BuildContext context,
    String title,
    Map<T, String> options,
    T currentValue,
  ) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: GoogleFonts.heebo(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ...options.entries.map((e) => ListTile(
                  title: Text(e.value),
                  trailing: e.key == currentValue ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, e.key),
                )),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: FindlyColors.brandPurple.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: GoogleFonts.heebo(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, size: 16),
        ]),
      ),
    );
  }
}

class _RateWorkerDialog extends StatefulWidget {
  final Map<String, dynamic> application;
  const _RateWorkerDialog({required this.application});

  @override
  State<_RateWorkerDialog> createState() => _RateWorkerDialogState();
}

class _RateWorkerDialogState extends State<_RateWorkerDialog> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final name = (widget.application['applicant'] as Map<String, dynamic>?)?['full_name'] as String? ?? '';
    return AlertDialog(
      title: Text('דרג את $name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return IconButton(
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'הערה (לא חובה)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            (rating: _rating, comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim()),
          ),
          child: const Text('שמור דירוג'),
        ),
      ],
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  final Map<String, dynamic> application;
  final ValueChanged<String> onDecide;
  final VoidCallback onRate;
  /// True iff the event has ended — controls visibility of the "Rate" button.
  final bool canRate;
  const _ApplicantCard({
    required this.application,
    required this.onDecide,
    required this.onRate,
    required this.canRate,
  });

  @override
  Widget build(BuildContext context) {
    final status = application['status'] as String;
    final applicant = application['applicant'] as Map<String, dynamic>?;
    final (color, label) = switch (status) {
      'approved' => (FindlyColors.brandGreen, 'מאושר'),
      'rejected' => (FindlyColors.warningRed, 'נדחה'),
      'cancelled_by_employee' => (Colors.orange, 'בוטל ע״י העובד'),
      'cancelled_by_employer' => (FindlyColors.textSecondary, 'בוטל'),
      _ => (FindlyColors.pendingBlue, 'ממתין'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: FindlyColors.brandPurple.withValues(alpha: 0.15),
              child: Text(
                (applicant?['full_name'] as String?)?.characters.first ?? '?',
                style: GoogleFonts.heebo(color: FindlyColors.brandPurple, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(applicant?['full_name'] ?? 'משתמש',
                      style: GoogleFonts.heebo(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (applicant?['phone'] != null)
                    Text(applicant!['phone'] as String,
                        style: GoogleFonts.heebo(fontSize: 12, color: FindlyColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(label,
                  style: GoogleFonts.heebo(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          if (application['proposed_amount'] != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.attach_money_rounded, size: 16, color: FindlyColors.brandGreen),
              Text('הצעת מחיר: ₪${application['proposed_amount']}',
                  style: GoogleFonts.heebo(color: FindlyColors.brandGreen, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          ],
          _RatingRow(rating: application['worker_rating'] as Map<String, dynamic>?),
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => onDecide('approved'),
                  style: FilledButton.styleFrom(
                    backgroundColor: FindlyColors.brandGreen,
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('אישור'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onDecide('rejected'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: const Text('דחייה'),
                ),
              ),
            ]),
          ],
          if (status == 'approved' && canRate) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.star_rounded, size: 18),
              label: const Text('דרג את העובד'),
              onPressed: onRate,
              style: FilledButton.styleFrom(
                backgroundColor: FindlyColors.brandPurple,
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline row of stars + count, shown beneath the applicant header.
/// `rating` is the `worker_rating: { avg, count }` payload the server
/// adds to each application row.
class _RatingRow extends StatelessWidget {
  final Map<String, dynamic>? rating;
  const _RatingRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    final avg = rating?['avg'];
    final count = (rating?['count'] as int?) ?? 0;
    if (avg == null) return const SizedBox.shrink();
    final score = (avg as num).toDouble();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        ...List.generate(5, (i) {
          if (score >= i + 1) {
            return const Icon(Icons.star_rounded, color: Colors.amber, size: 16);
          }
          if (score > i) {
            return const Icon(Icons.star_half_rounded, color: Colors.amber, size: 16);
          }
          return const Icon(Icons.star_outline_rounded, color: Colors.amber, size: 16);
        }),
        const SizedBox(width: 4),
        Text('${score.toStringAsFixed(1)} (${count})',
            style: GoogleFonts.heebo(fontSize: 12, color: FindlyColors.textSecondary)),
      ]),
    );
  }
}

class _MessagesTab extends StatelessWidget {
  final List<dynamic> messages;
  const _MessagesTab({required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('עדיין לא נשלחו הודעות',
              style: GoogleFonts.heebo(color: FindlyColors.textSecondary)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final m = Map<String, dynamic>.from(messages[i]);
        final df = DateFormat('EEE dd/MM | HH:mm', 'he');
        final sent = DateTime.tryParse(m['sent_at'] as String? ?? '');
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (sent != null)
              Text(df.format(sent),
                  style: GoogleFonts.heebo(fontSize: 11, color: FindlyColors.brandGreen, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(m['title'] as String? ?? '',
                style: GoogleFonts.heebo(fontWeight: FontWeight.w700, fontSize: 14)),
            if (m['body'] != null) ...[
              const SizedBox(height: 4),
              Text(m['body'] as String,
                  style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary, height: 1.5)),
            ],
            const SizedBox(height: 6),
            Text('מס׳ ${m['recipient_count']}',
                style: GoogleFonts.heebo(fontSize: 11, color: FindlyColors.textSecondary)),
          ]),
        );
      },
    );
  }
}

class _ShiftsTab extends StatelessWidget {
  final Map<String, dynamic> event;
  const _ShiftsTab({required this.event});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.access_time_rounded, size: 48, color: FindlyColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text('נדרש: ${event['required_employees']} עובדים',
              style: GoogleFonts.heebo(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('פירוט המשמרות יתווסף בעדכון הבא',
              style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _SendMessageSheet extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  const _SendMessageSheet({required this.titleCtrl, required this.bodyCtrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E5EE), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [FindlyColors.gradientMid, FindlyColors.gradientBottom]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: FindlyColors.brandPurple.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 16),
            Text('שליחת הודעה לעובדים באירוע',
                textAlign: TextAlign.center,
                style: GoogleFonts.heebo(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'כותרת', hintText: 'תזכורת / שינוי במשמרת'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'תוכן ההודעה', hintText: 'פרטים מלאים...'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.send_rounded),
              label: const Text('שלח'),
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ביטול')),
          ],
        ),
      ),
    );
  }
}
