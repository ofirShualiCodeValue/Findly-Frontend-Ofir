import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/employer_api.dart';
import '../../widgets/error_view.dart';

class EventDetailsScreen extends StatefulWidget {
  final int eventId;
  const EventDetailsScreen({super.key, required this.eventId});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  Map<String, dynamic>? _event;
  List<dynamic> _applications = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        EmployerApi.getEvent(widget.eventId),
        EmployerApi.listApplications(widget.eventId),
      ]);
      setState(() {
        _event = results[0] as Map<String, dynamic>;
        _applications = results[1] as List<dynamic>;
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

  Future<void> _decide(int appId, String status) async {
    try {
      await EmployerApi.decideApplication(widget.eventId, appId, status);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _cancelEvent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('לבטל את האירוע?'),
        content: const Text('הפעולה משאירה את האירוע במערכת אבל מסמנת אותו כבוטל.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('לא')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('בטל אירוע'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await EmployerApi.cancelEvent(widget.eventId);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _sendNotification() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('שליחת הודעה לעובדים'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'כותרת', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'תוכן (לא חובה)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ביטול')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('שליחה')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await EmployerApi.sendNotification(
        widget.eventId,
        titleCtrl.text.trim(),
        bodyCtrl.text.trim().isEmpty ? null : bodyCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('נשלח ל-${r["recipient_count"]} עובדים מאושרים')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
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
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final cancelled = e['status'] == 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: Text(e['name'] as String? ?? ''),
        actions: [
          IconButton(icon: const Icon(Icons.send), tooltip: 'שלח הודעה לעובדים', onPressed: cancelled ? null : _sendNotification),
          if (!cancelled)
            IconButton(icon: const Icon(Icons.cancel), tooltip: 'בטל אירוע', onPressed: _cancelEvent),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cancelled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('אירוע בוטל', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      ),
                    _row(Icons.event, 'תאריך', '${df.format(DateTime.parse(e['start_at']))} - ${df.format(DateTime.parse(e['end_at']))}'),
                    if (e['venue'] != null) _row(Icons.place, 'מקום', e['venue'] as String),
                    _row(Icons.attach_money, 'תקציב', '₪${e['budget']}'),
                    _row(Icons.group, 'דרושים', '${e['required_employees']} עובדים'),
                    if (e['description'] != null) ...[
                      const Divider(),
                      Text(e['description'] as String, style: const TextStyle(color: Colors.black87)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('הצעות עבודה (${_applications.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_applications.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('אין הצעות עדיין', style: TextStyle(color: Colors.grey))),
              ),
            ..._applications.map((a) => _applicationTile(Map<String, dynamic>.from(a))),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Expanded(child: Text(value)),
      ]),
    );
  }

  Widget _applicationTile(Map<String, dynamic> a) {
    final status = a['status'] as String;
    final applicant = a['applicant'] as Map<String, dynamic>?;
    Color color;
    String label;
    switch (status) {
      case 'approved': color = Colors.green; label = 'מאושר'; break;
      case 'rejected': color = Colors.red; label = 'נדחה'; break;
      case 'cancelled_by_employee': color = Colors.orange; label = 'בוטל ע"י העובד'; break;
      case 'cancelled_by_employer': color = Colors.grey; label = 'בוטל'; break;
      default: color = Colors.blue; label = 'ממתין'; break;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(applicant?['full_name'] ?? 'משתמש',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(label, style: TextStyle(color: color, fontSize: 12)),
              ),
            ]),
            if (applicant?['phone'] != null)
              Text(applicant!['phone'] as String, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            if (a['proposed_amount'] != null) ...[
              const SizedBox(height: 4),
              Text('הצעת מחיר: ₪${a['proposed_amount']}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
            ],
            if (a['note'] != null) ...[
              const SizedBox(height: 4),
              Text(a['note'] as String, style: const TextStyle(color: Colors.black54, fontSize: 13)),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 8),
              Row(children: [
                FilledButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('אישור'),
                  onPressed: () => _decide(a['id'] as int, 'approved'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('דחייה'),
                  onPressed: () => _decide(a['id'] as int, 'rejected'),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
