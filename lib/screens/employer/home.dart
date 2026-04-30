import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/employer_api.dart';
import '../../store/auth_store.dart';
import '../../widgets/error_view.dart';
import 'create_event.dart';
import 'event_details.dart';
import 'profile.dart';

class EmployerHomeScreen extends StatefulWidget {
  const EmployerHomeScreen({super.key});

  @override
  State<EmployerHomeScreen> createState() => _EmployerHomeScreenState();
}

class _EmployerHomeScreenState extends State<EmployerHomeScreen> {
  late Future<List<dynamic>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = EmployerApi.listEvents();
  }

  Future<void> _refresh() async {
    setState(() => _eventsFuture = EmployerApi.listEvents());
    await _eventsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('שלום ${authStore.fullName ?? ""}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployerProfileScreen()),
            ).then((_) => _refresh()),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authStore.clear();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _eventsFuture,
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ErrorView(message: snap.error.toString(), onRetry: _refresh);
            }
            final events = snap.data ?? [];
            if (events.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('אין אירועים עדיין',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('צור אירוע ראשון בלחיצה על הכפתור למטה',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (_, i) => _EventCard(
                event: Map<String, dynamic>.from(events[i]),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailsScreen(eventId: events[i]['id'] as int),
                  ),
                ).then((_) => _refresh()),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('יצירת אירוע חדש'),
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          );
          if (created == true) _refresh();
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;
  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy', 'he');
    final tf = DateFormat('HH:mm');
    final start = DateTime.tryParse(event['start_at'] as String? ?? '');
    final end = DateTime.tryParse(event['end_at'] as String? ?? '');
    final status = event['status'] as String? ?? '';
    final cancelled = status == 'cancelled';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(event['name'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        decoration: cancelled ? TextDecoration.lineThrough : null,
                      )),
                ),
                if (cancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('בוטל', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ]),
              if (start != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${df.format(start)} • ${tf.format(start)}${end != null ? ' - ${tf.format(end)}' : ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ],
              if (event['venue'] != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.place, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(event['venue'] as String, style: const TextStyle(color: Colors.grey, fontSize: 13))),
                ]),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Chip(
                  label: Text('${event['required_employees']} עובדים'),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('₪${event['budget']}'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
