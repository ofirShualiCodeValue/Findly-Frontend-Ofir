import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/employee_api.dart';
import '../../store/auth_store.dart';
import '../../widgets/error_view.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('שלום ${authStore.fullName ?? ""}'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => authStore.clear()),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          _BrowseEventsTab(),
          _MyApplicationsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'אירועים'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'ההצעות שלי'),
        ],
      ),
    );
  }
}

class _BrowseEventsTab extends StatefulWidget {
  const _BrowseEventsTab();

  @override
  State<_BrowseEventsTab> createState() => _BrowseEventsTabState();
}

class _BrowseEventsTabState extends State<_BrowseEventsTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = EmployeeApi.browseEvents();
  }

  Future<void> _refresh() async {
    setState(() => _future = EmployeeApi.browseEvents());
    await _future;
  }

  Future<void> _apply(Map<String, dynamic> event) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
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
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'הערה (לא חובה)', border: OutlineInputBorder()),
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
      await EmployeeApi.apply(event['id'] as int, amount, note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('המועמדות נשלחה בהצלחה')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _refresh);
          final events = snap.data ?? [];
          if (events.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Icon(Icons.event_busy, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Center(child: Text('אין אירועים פתוחים כרגע', style: TextStyle(fontSize: 16, color: Colors.grey))),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (_, i) {
              final ev = Map<String, dynamic>.from(events[i]);
              return _eventCard(ev);
            },
          );
        },
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> ev) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final emp = ev['employer'] as Map<String, dynamic>?;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ev['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (emp?['business_name'] != null)
              Text(emp!['business_name'] as String, style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
            const SizedBox(height: 8),
            Text('${df.format(DateTime.parse(ev['start_at']))} - ${df.format(DateTime.parse(ev['end_at']))}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            if (ev['venue'] != null)
              Text(ev['venue'] as String, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Chip(label: Text('₪${ev['budget']} תקציב'), backgroundColor: Colors.green.withValues(alpha: 0.1)),
              const SizedBox(width: 8),
              Chip(label: Text('${ev['required_employees']} עובדים')),
            ]),
            if (ev['description'] != null) ...[
              const SizedBox(height: 8),
              Text(ev['description'] as String, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('הגש מועמדות'),
              onPressed: () => _apply(ev),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyApplicationsTab extends StatefulWidget {
  const _MyApplicationsTab();

  @override
  State<_MyApplicationsTab> createState() => _MyApplicationsTabState();
}

class _MyApplicationsTabState extends State<_MyApplicationsTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = EmployeeApi.myApplications();
  }

  Future<void> _refresh() async {
    setState(() => _future = EmployeeApi.myApplications());
    await _future;
  }

  Future<void> _cancel(int id) async {
    try {
      await EmployeeApi.cancelApplication(id);
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _refresh);
          final apps = snap.data ?? [];
          if (apps.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Icon(Icons.assignment_late, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Center(child: Text('עוד לא הגשת מועמדות לאירועים', style: TextStyle(color: Colors.grey))),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            itemBuilder: (_, i) => _appCard(Map<String, dynamic>.from(apps[i])),
          );
        },
      ),
    );
  }

  Widget _appCard(Map<String, dynamic> a) {
    final status = a['status'] as String;
    Color color;
    String label;
    switch (status) {
      case 'approved': color = Colors.green; label = 'אושרת!'; break;
      case 'rejected': color = Colors.red; label = 'נדחית'; break;
      case 'cancelled_by_employee': color = Colors.orange; label = 'בוטל ע"י העובד'; break;
      case 'cancelled_by_employer': color = Colors.grey; label = 'בוטל ע"י המעסיק'; break;
      default: color = Colors.blue; label = 'ממתין לתשובה'; break;
    }
    final ev = a['event'] as Map<String, dynamic>?;
    final df = DateFormat('dd/MM/yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(ev?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(label, style: TextStyle(color: color, fontSize: 12)),
              ),
            ]),
            if (ev?['start_at'] != null)
              Text(df.format(DateTime.parse(ev!['start_at'] as String)),
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            if (a['proposed_amount'] != null) ...[
              const SizedBox(height: 4),
              Text('הצעת המחיר שלך: ₪${a['proposed_amount']}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
            ],
            if (status == 'pending' || status == 'approved') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.cancel, size: 18),
                label: const Text('בטל מועמדות'),
                onPressed: () => _cancel(a['id'] as int),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
