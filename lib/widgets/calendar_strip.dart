import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

/// Horizontal calendar strip — a 14-day window centered on today.
/// Matches the Findly "ברוכים הבאים" home header strip.
class CalendarStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const CalendarStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = List.generate(14, (i) => today.add(Duration(days: i - 3)));
    final dowFmt = DateFormat('EEEE', 'he');

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true, // RTL: today should be at the right side
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final day = days[i];
          final selected = DateUtils.isSameDay(day, selectedDate);
          return _DayChip(
            day: day,
            label: dowFmt.format(day).substring(0, 3),
            selected: selected,
            onTap: () => onDateSelected(day),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        decoration: BoxDecoration(
          color: selected ? FindlyColors.textPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.18 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.heebo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : FindlyColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: GoogleFonts.heebo(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : FindlyColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
