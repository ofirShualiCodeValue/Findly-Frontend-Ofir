import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_background.dart';

class EmployeeNotificationsTab extends StatefulWidget {
  const EmployeeNotificationsTab({super.key});

  @override
  State<EmployeeNotificationsTab> createState() => _EmployeeNotificationsTabState();
}

class _EmployeeNotificationsTabState extends State<EmployeeNotificationsTab> {
  // TODO: wire to GET /v1/employee/notifications when that endpoint is added.
  // For now we render the empty state matching the mockup, with a sample
  // payload toggle to preview the filled state.
  final List<Map<String, dynamic>> _notifications = [];

  @override
  Widget build(BuildContext context) {
    if (_notifications.isEmpty) {
      return const SurfaceGradientBackground(
        child: SafeArea(
          child: EmptyState(
            icon: Icons.inbox_rounded,
            title: 'אין עדכונים חדשים',
          ),
        ),
      );
    }

    return SurfaceGradientBackground(
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: _notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _NotificationCard(item: _notifications[i]),
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
