import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/employer_api.dart';
import '../../config.dart';
import '../../theme.dart';
import '../../widgets/error_view.dart';

/// Detailed view of a single applicant — pushed when the employer taps an
/// applicant card on the event details screen. Lazily fetches the worker's
/// full profile + rating history and exposes approve/reject actions inline.
class WorkerProfileScreen extends StatefulWidget {
  final int eventId;
  final int applicationId;
  final bool canDecide;
  const WorkerProfileScreen({
    super.key,
    required this.eventId,
    required this.applicationId,
    required this.canDecide,
  });

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  bool _deciding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await EmployerApi.getApplication(widget.eventId, widget.applicationId);
      setState(() {
        _data = d;
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

  Future<void> _decide(String status) async {
    if (_deciding) return;
    setState(() => _deciding = true);
    try {
      await EmployerApi.decideApplication(widget.eventId, widget.applicationId, status);
      if (!mounted) return;
      // Pop with `true` so the caller can refresh the applicants list.
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deciding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('פרופיל עובד')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('פרופיל עובד')),
        body: ErrorView(message: _error ?? 'נכשל לטעון פרופיל', onRetry: _load),
      );
    }

    final applicant = (_data!['applicant'] as Map?)?.cast<String, dynamic>() ?? {};
    final application = (_data!['application'] as Map?)?.cast<String, dynamic>() ?? {};
    final rating = (_data!['rating'] as Map?)?.cast<String, dynamic>() ?? {};
    final profile = (applicant['profile'] as Map?)?.cast<String, dynamic>();
    final subs = (applicant['industry_sub_categories'] as List?) ?? const [];
    final history = (rating['history'] as List?) ?? const [];

    final status = application['status'] as String? ?? 'pending';
    final isPending = status == 'pending';

    return Scaffold(
      backgroundColor: FindlyColors.appBackground,
      appBar: AppBar(
        title: const Text('פרופיל עובד'),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          _Header(
            name: applicant['full_name'] as String? ?? '',
            avatarUrl: profile?['avatar_url'] as String?,
            ratingAvg: (rating['avg'] as num?)?.toDouble(),
            ratingCount: (rating['count'] as int?) ?? 0,
          ),
          const SizedBox(height: 20),
          _SectionTitle('פרטים אישיים'),
          _Card(
            children: [
              if (profile?['date_of_birth'] != null)
                _DetailRow(
                  icon: Icons.cake_outlined,
                  label: 'שנת לידה',
                  value: _yearOf(profile!['date_of_birth'] as String),
                ),
              if (profile?['home_city'] != null)
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: 'מקום מגורים',
                  value: profile!['home_city'] as String,
                ),
              if (profile?['location_range_km'] != null)
                _DetailRow(
                  icon: Icons.travel_explore_outlined,
                  label: 'טווח מרחק',
                  value: 'עד ${profile!['location_range_km']} ק"מ',
                ),
              if (profile?['work_status'] != null)
                _DetailRow(
                  icon: Icons.work_outline,
                  label: 'סטטוס תעסוקה',
                  value: profile!['work_status'] == 'freelancer' ? 'עצמאי' : 'שכיר',
                ),
              if (profile?['base_hourly_rate'] != null)
                _DetailRow(
                  icon: Icons.attach_money_rounded,
                  label: 'שכר שעתי בסיסי',
                  value: '₪${profile!['base_hourly_rate']}',
                ),
              if (applicant['phone'] != null)
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'טלפון',
                  value: applicant['phone'] as String,
                ),
              if (applicant['email'] != null)
                _DetailRow(
                  icon: Icons.mail_outline,
                  label: 'אימייל',
                  value: applicant['email'] as String,
                ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle('תפקידים'),
          _Card(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: subs.isEmpty
                    ? Text(
                        'לא הוזנו התמחויות',
                        style: GoogleFonts.heebo(color: FindlyColors.textSecondary),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: subs
                            .map((s) => _Chip(label: (s as Map)['name'] as String? ?? ''))
                            .toList(),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (application['proposed_amount'] != null) ...[
            _SectionTitle('הצעת המועמד'),
            _Card(
              children: [
                _DetailRow(
                  icon: Icons.attach_money_rounded,
                  label: 'הצעת מחיר',
                  value: '₪${application['proposed_amount']}',
                ),
                if (application['note'] != null && (application['note'] as String).isNotEmpty)
                  _DetailRow(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'הערה',
                    value: application['note'] as String,
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          _SectionTitle('היסטוריית דירוגים'),
          _Card(
            children: [
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'אין דירוגים קודמים',
                    style: GoogleFonts.heebo(color: FindlyColors.textSecondary),
                  ),
                )
              else
                ...history.map((h) => _RatingHistoryRow(entry: Map<String, dynamic>.from(h as Map))),
            ],
          ),
          if (widget.canDecide && isPending) ...[
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _deciding ? null : () => _decide('rejected'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                    child: const Text('דחייה'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _deciding ? null : () => _decide('approved'),
                    style: FilledButton.styleFrom(
                      backgroundColor: FindlyColors.brandGreen,
                      minimumSize: const Size(0, 52),
                    ),
                    child: _deciding
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('אישור'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _yearOf(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : d.year.toString();
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double? ratingAvg;
  final int ratingCount;
  const _Header({
    required this.name,
    required this.avatarUrl,
    required this.ratingAvg,
    required this.ratingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipOval(
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? Image.network(
                    _absoluteUrl(avatarUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => _Initial(name: name),
                  )
                : _Initial(name: name),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name.isNotEmpty ? name : '—',
          style: GoogleFonts.heebo(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (ratingAvg != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (i) {
                final score = ratingAvg!;
                if (score >= i + 1) {
                  return const Icon(Icons.star_rounded, color: FindlyColors.brandGreen, size: 18);
                }
                if (score > i) {
                  return const Icon(Icons.star_half_rounded, color: FindlyColors.brandGreen, size: 18);
                }
                return Icon(Icons.star_outline_rounded,
                    color: FindlyColors.brandGreen.withValues(alpha: 0.4), size: 18);
              }),
              const SizedBox(width: 8),
              Text(
                '${ratingAvg!.toStringAsFixed(1)} ($ratingCount)',
                style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary),
              ),
            ],
          )
        else
          Text(
            'אין דירוג',
            style: GoogleFonts.heebo(fontSize: 13, color: FindlyColors.textSecondary),
          ),
      ],
    );
  }

  String _absoluteUrl(String path) {
    if (path.startsWith('http')) return path;
    return '$kApiBaseUrl$path';
  }
}

class _Initial extends StatelessWidget {
  final String name;
  const _Initial({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim().characters.first : '?';
    return Container(
      color: FindlyColors.brandPurple.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.heebo(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: FindlyColors.brandPurple,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: FindlyColors.brandGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.heebo(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: FindlyColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: GoogleFonts.heebo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: FindlyColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: GoogleFonts.heebo(fontSize: 14, color: FindlyColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: FindlyColors.brandGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.heebo(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _RatingHistoryRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _RatingHistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final score = (entry['rating'] as num?)?.toInt() ?? 0;
    final comment = entry['comment'] as String?;
    final ev = (entry['event'] as Map?)?.cast<String, dynamic>();
    final created = DateTime.tryParse(entry['created_at'] as String? ?? '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (i) {
                final on = i < score;
                return Icon(
                  on ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: on
                      ? FindlyColors.brandGreen
                      : FindlyColors.brandGreen.withValues(alpha: 0.4),
                  size: 16,
                );
              }),
              const Spacer(),
              if (created != null)
                Text(
                  DateFormat('d/M/yyyy', 'he').format(created),
                  style: GoogleFonts.heebo(fontSize: 11, color: FindlyColors.textSecondary),
                ),
            ],
          ),
          if (ev?['name'] != null) ...[
            const SizedBox(height: 4),
            Text(
              ev!['name'] as String,
              style: GoogleFonts.heebo(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              comment,
              style: GoogleFonts.heebo(fontSize: 12, color: FindlyColors.textSecondary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
