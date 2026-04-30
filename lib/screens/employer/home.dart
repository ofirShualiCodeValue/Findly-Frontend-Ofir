import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/employer_api.dart';
import '../../store/auth_store.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/calendar_strip.dart';
import '../../widgets/gradient_background.dart';
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
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _eventsFuture = EmployerApi.listEvents();
  }

  Future<void> _refresh() async {
    setState(() => _eventsFuture = EmployerApi.listEvents());
    await _eventsFuture;
  }

  List<dynamic> _filterByDate(List<dynamic> events) {
    return events.where((e) {
      final start = DateTime.tryParse(e['start_at'] as String? ?? '');
      if (start == null) return false;
      return DateUtils.isSameDay(start, _selectedDate);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SurfaceGradientBackground(
        topGradientHeight: 360,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(name: authStore.fullName ?? '')),
                SliverToBoxAdapter(child: _MonthLabel(date: _selectedDate)),
                SliverToBoxAdapter(
                  child: CalendarStrip(
                    selectedDate: _selectedDate,
                    onDateSelected: (d) => setState(() => _selectedDate = d),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                FutureBuilder<List<dynamic>>(
                  future: _eventsFuture,
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: ErrorView(message: snap.error.toString(), onRetry: _refresh),
                      );
                    }
                    final all = snap.data ?? [];
                    final filtered = _filterByDate(all);
                    if (filtered.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.calendar_today_rounded,
                          title: all.isEmpty ? 'אין אירועים עדיין' : 'אין אירועים בתאריך זה',
                          subtitle: all.isEmpty
                              ? 'צור אירוע ראשון בלחיצה על הכפתור למטה'
                              : 'בחר תאריך אחר או צור אירוע חדש',
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _EventCard(
                          event: Map<String, dynamic>.from(filtered[i]),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventDetailsScreen(eventId: filtered[i]['id'] as int),
                            ),
                          ).then((_) => _refresh()),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: 240,
          child: FilledButton.icon(
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
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  const _Header({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployerProfileScreen()),
            ),
            icon: _circleIcon(Icons.person_outline),
          ),
          IconButton(
            onPressed: () {},
            icon: _circleIcon(Icons.notifications_outlined),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ברוכים הבאים!',
                style: GoogleFonts.heebo(fontSize: 24, fontWeight: FontWeight.w800, color: FindlyColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                name.isEmpty ? '' : 'יום ${DateFormat('EEEE, d בMMMM', 'he').format(DateTime.now())}',
                style: GoogleFonts.heebo(fontSize: 12, color: FindlyColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Icon(icon, color: FindlyColors.textPrimary, size: 20),
    );
  }
}

class _MonthLabel extends StatelessWidget {
  final DateTime date;
  const _MonthLabel({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Text(
            DateFormat('MMMM yyyy', 'he').format(date),
            style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            'היום',
            style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.brandPurple, fontWeight: FontWeight.w600),
          ),
        ],
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
    final tf = DateFormat('HH:mm');
    final start = DateTime.tryParse(event['start_at'] as String? ?? '');
    final end = DateTime.tryParse(event['end_at'] as String? ?? '');
    final status = event['status'] as String? ?? '';
    final cancelled = status == 'cancelled';
    final timeRange = (start != null && end != null) ? '${tf.format(start)} - ${tf.format(end)}' : '';
    final venue = event['venue'] as String? ?? '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              if (!cancelled)
                Positioned(
                  right: 0,
                  top: 12,
                  bottom: 12,
                  child: Container(width: 4, decoration: BoxDecoration(
                    color: FindlyColors.brandGreen,
                    borderRadius: BorderRadius.circular(4),
                  )),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (timeRange.isNotEmpty || venue.isNotEmpty)
                            Row(children: [
                              if (timeRange.isNotEmpty) ...[
                                Text(timeRange, style: GoogleFonts.heebo(fontSize: 13, fontWeight: FontWeight.w600, color: FindlyColors.textPrimary)),
                              ],
                              if (venue.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('|', style: TextStyle(color: FindlyColors.textSecondary)),
                                ),
                                Expanded(
                                  child: Text(venue,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary)),
                                ),
                              ],
                            ]),
                          const SizedBox(height: 6),
                          Text(
                            event['name'] as String? ?? '',
                            style: GoogleFonts.heebo(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: cancelled ? FindlyColors.textSecondary : FindlyColors.textPrimary,
                              decoration: cancelled ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Text('${event['required_employees'] ?? '—'} משמרות',
                                style: GoogleFonts.heebo(fontSize: 12, color: FindlyColors.textSecondary)),
                            const SizedBox(width: 12),
                            Text('תקציב: ₪${event['budget']}',
                                style: GoogleFonts.heebo(fontSize: 12, color: FindlyColors.brandGreen, fontWeight: FontWeight.w600)),
                          ]),
                        ],
                      ),
                    ),
                    if (cancelled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: FindlyColors.warningRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('בוטל', style: GoogleFonts.heebo(color: FindlyColors.warningRed, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
