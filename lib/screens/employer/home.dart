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
import '../auth/phone_entry.dart';
import '../employee/home.dart';
import 'create_event.dart';
import 'event_details.dart';
import 'notifications.dart';
import 'profile.dart';

/// 3-tab shell for the Employer App. Strict role guard at the top —
/// if a non-employer somehow lands here (stale session, bad routing),
/// they're bounced back to the right destination instead of seeing
/// employer-only UI.
class EmployerHomeScreen extends StatefulWidget {
  const EmployerHomeScreen({super.key});

  @override
  State<EmployerHomeScreen> createState() => _EmployerHomeScreenState();
}

class _EmployerHomeScreenState extends State<EmployerHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Defensive routing — guarantees no employee ever lands here.
    WidgetsBinding.instance.addPostFrameCallback((_) => _enforceRole());
  }

  void _enforceRole() {
    if (!mounted) return;
    final role = authStore.role;
    if (role == 'employer') return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => role == 'employee' ? const EmployeeHomeScreen() : const PhoneEntryScreen(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (authStore.role != 'employer') {
      // Render nothing while the post-frame redirect runs.
      return const SizedBox.shrink();
    }
    // Employer is a single-screen UX per the Figma — calendar + events
    // + the prominent "יצירת אירוע חדש" FAB. Profile and notifications
    // are reachable as full-screen routes from the header icons (top-left),
    // not from a bottom nav.
    return const _EventsTab();
  }
}

/// Calendar strip + per-day events list + the prominent "Create Event"
/// CTAs (FAB at the bottom + a contextual "add for {day}" inline button).
class _EventsTab extends StatefulWidget {
  const _EventsTab();

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
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

  Future<void> _openCreateEvent(DateTime forDate) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateEventScreen(initialDate: forDate)),
    );
    if (created == true) _refresh();
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
      backgroundColor: Colors.transparent,
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
                    final dayLabel = DateFormat('d בMMMM', 'he').format(_selectedDate);
                    if (filtered.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              EmptyState(
                                icon: Icons.calendar_today_rounded,
                                title: all.isEmpty ? 'אין אירועים עדיין' : 'אין אירועים בתאריך זה',
                                subtitle: all.isEmpty
                                    ? 'התחל בלחיצה על הכפתור למטה'
                                    : 'או בחר תאריך אחר',
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                icon: const Icon(Icons.add),
                                label: Text('הוסף אירוע ל-$dayLabel'),
                                onPressed: () => _openCreateEvent(_selectedDate),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      sliver: SliverList.separated(
                        itemCount: filtered.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          if (i == filtered.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.add),
                                label: Text('הוסף אירוע נוסף ל-$dayLabel'),
                                onPressed: () => _openCreateEvent(_selectedDate),
                              ),
                            );
                          }
                          return _EventCard(
                            event: Map<String, dynamic>.from(filtered[i]),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventDetailsScreen(eventId: filtered[i]['id'] as int),
                              ),
                            ).then((_) => _refresh()),
                          );
                        },
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
          width: 260,
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('יצירת אירוע חדש'),
            onPressed: () => _openCreateEvent(_selectedDate),
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
          // Top-left icons (profile + notifications). Each has a red dot
          // indicator badge per the Figma — non-functional dot for now,
          // wire up unread counts later.
          Builder(
            builder: (ctx) => _CircleIconButton(
              icon: Icons.person_rounded,
              showBadge: true,
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute(builder: (_) => const EmployerProfileScreen()),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Builder(
            builder: (ctx) => _CircleIconButton(
              icon: Icons.notifications_rounded,
              showBadge: true,
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('עדכונים')),
                    body: const EmployerNotificationsTab(),
                  ),
                ),
              ),
            ),
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
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final bool showBadge;
  final VoidCallback onPressed;
  const _CircleIconButton({
    required this.icon,
    required this.showBadge,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 1,
          shadowColor: Colors.black12,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: FindlyColors.textPrimary, size: 20),
            ),
          ),
        ),
        if (showBadge)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: FindlyColors.warningRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
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
