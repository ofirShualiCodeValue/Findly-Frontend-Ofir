import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/employee_api.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/gradient_background.dart';

class EmployeeNotificationsTab extends StatefulWidget {
  const EmployeeNotificationsTab({super.key});

  @override
  State<EmployeeNotificationsTab> createState() => _EmployeeNotificationsTabState();
}

class _EmployeeNotificationsTabState extends State<EmployeeNotificationsTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = EmployeeApi.listNotifications();
  }

  Future<void> _refresh() async {
    setState(() => _future = EmployeeApi.listNotifications());
    await _future;
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read_at'] != null) return;
    try {
      await EmployeeApi.markNotificationRead(item['id'] as int);
      _refresh();
    } on ApiException catch (_) {
      // Non-fatal — the row stays as unread on screen until next refresh.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceGradientBackground(
      child: SafeArea(
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
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return ListView(children: const [
                  SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.inbox_rounded,
                    title: 'אין עדכונים חדשים',
                  ),
                ]);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final item = Map<String, dynamic>.from(items[i]);
                  return InkWell(
                    onTap: () => _markRead(item),
                    borderRadius: BorderRadius.circular(20),
                    child: _NotificationCard(item: item),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = item['type'] as String? ?? 'general';
    final readAt = item['read_at'] as String?;
    final isUnread = readAt == null;
    final created = DateTime.tryParse(item['created_at'] as String? ?? '');
    final timeAgo = created != null ? _formatTimeAgo(created) : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NotificationIcon(type: type, unread: isUnread),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] as String? ?? '',
                        style: GoogleFonts.heebo(
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 15,
                          color: FindlyColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(timeAgo, style: GoogleFonts.heebo(fontSize: 11, color: FindlyColors.textSecondary)),
                  ],
                ),
                if (item['body'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item['body'] as String,
                    style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'לפני ${diff.inMinutes} דק׳';
    if (diff.inHours < 24) return 'לפני ${diff.inHours} שעות';
    if (diff.inDays < 7) return 'לפני ${diff.inDays} ימים';
    return DateFormat('dd/MM').format(dt);
  }
}

class _NotificationIcon extends StatelessWidget {
  final String type;
  final bool unread;
  const _NotificationIcon({required this.type, required this.unread});

  @override
  Widget build(BuildContext context) {
    final mapping = {
      'shift_reminder': (Icons.notifications_active_rounded, FindlyColors.gradientMid),
      'event_message': (Icons.chat_bubble_rounded, FindlyColors.brandPurple),
      'application_approved': (Icons.check_circle_rounded, FindlyColors.brandGreen),
      'application_rejected': (Icons.cancel_rounded, FindlyColors.warningRed),
      'shift_ended': (Icons.access_time_rounded, FindlyColors.gradientBottom),
      'event_cancelled': (Icons.delete_rounded, FindlyColors.brandPurple),
    };
    final (icon, color) = mapping[type] ?? (Icons.info_rounded, FindlyColors.brandPurple);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.85), color],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }
}
