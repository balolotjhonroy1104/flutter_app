import 'package:flutter/material.dart';

/// Which period the summary aggregates over.
enum SummaryPeriod { day, week, month }

/// Attendance summary shown at the top of the history sheet: pick Day,
/// Weekly or Monthly and it aggregates the records in that period into
/// session count, total worked time and average time per session.
///
/// Controlled widget: the parent owns the selected [period] (so it can
/// filter the record list below the summary to match) and receives changes
/// through [onPeriodChanged]. [now] is passed in so an ongoing session's
/// contribution to the totals stays live when the parent ticks.
///
/// Presentation-only: the page supplies the record maps
/// (`{ time_in: ..., time_out: ... }`) as received from the server.
class AttendanceSummary extends StatelessWidget {
  const AttendanceSummary({
    super.key,
    required this.records,
    required this.period,
    required this.onPeriodChanged,
    required this.now,
  });

  final List<Map<String, dynamic>> records;
  final SummaryPeriod period;
  final void Function(SummaryPeriod period) onPeriodChanged;
  final DateTime now;

  // ---- Period math (shared with the history sheet's list filter) ----

  /// Monday 00:00 of the week containing [now].
  static DateTime weekStartOf(DateTime now) =>
      DateTime(now.year, now.month, now.day - (now.weekday - 1));

  /// Whether a session's time-in falls inside the period.
  static bool isInPeriod(DateTime inTime, SummaryPeriod period, DateTime now) {
    switch (period) {
      case SummaryPeriod.day:
        return inTime.year == now.year &&
            inTime.month == now.month &&
            inTime.day == now.day;
      case SummaryPeriod.week:
        // Week starts on Monday.
        final DateTime weekStart = weekStartOf(now);
        final DateTime weekEnd = weekStart.add(const Duration(days: 7));
        return !inTime.isBefore(weekStart) && inTime.isBefore(weekEnd);
      case SummaryPeriod.month:
        return inTime.year == now.year && inTime.month == now.month;
    }
  }

  /// Records whose time-in falls in [period] — the same rule the summary
  /// uses, exposed so the sheet can filter the card list to match.
  static List<Map<String, dynamic>> filterRecords(
    List<Map<String, dynamic>> records,
    SummaryPeriod period,
    DateTime now,
  ) {
    return records.where((record) {
      final DateTime? inTime =
          DateTime.tryParse(record['time_in']?.toString() ?? '');
      if (inTime == null) return false;
      return isInPeriod(inTime, period, now);
    }).toList();
  }

  /// Human label for the period being viewed, e.g. `Sep 23, 2026`,
  /// `Sep 22 - Sep 28, 2026` or `September 2026`.
  static String periodLabel(SummaryPeriod period, DateTime now) {
    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const List<String> fullMonths = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    String d(DateTime date) => '${months[date.month - 1]} ${date.day}, ${date.year}';

    switch (period) {
      case SummaryPeriod.day:
        return d(now);
      case SummaryPeriod.week:
        final DateTime start = weekStartOf(now);
        final DateTime end = start.add(const Duration(days: 6));
        return start.month == end.month
            ? '${months[start.month - 1]} ${start.day} - ${end.day}, ${end.year}'
            : '${d(start)} - ${d(end)}';
      case SummaryPeriod.month:
        return '${fullMonths[now.month - 1]} ${now.year}';
    }
  }

  // ---- Aggregation ----

  /// The session's worked time: out - in when closed, now - in while open.
  static Duration sessionDuration(Map<String, dynamic> record, DateTime now) {
    final DateTime? inTime =
        DateTime.tryParse(record['time_in']?.toString() ?? '');
    if (inTime == null) return Duration.zero;

    final DateTime? outTime =
        DateTime.tryParse(record['time_out']?.toString() ?? '');
    return (outTime ?? now).difference(inTime);
  }

  String _formatTotal(Duration duration) {
    if (duration.inSeconds <= 0) return '--';
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> periodRecords =
        filterRecords(records, period, now);

    Duration total = Duration.zero;
    for (final Map<String, dynamic> record in periodRecords) {
      total += sessionDuration(record, now);
    }

    final int sessionCount = periodRecords.length;
    final Duration average = sessionCount == 0
        ? Duration.zero
        : Duration(seconds: total.inSeconds ~/ sessionCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period switcher.
          Row(
            children: [
              Expanded(
                child: _periodChip(
                  label: 'Day',
                  selected: period == SummaryPeriod.day,
                  onTap: () => onPeriodChanged(SummaryPeriod.day),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: _periodChip(
                  label: 'Weekly',
                  selected: period == SummaryPeriod.week,
                  onTap: () => onPeriodChanged(SummaryPeriod.week),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: _periodChip(
                  label: 'Monthly',
                  selected: period == SummaryPeriod.month,
                  onTap: () => onPeriodChanged(SummaryPeriod.month),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          // Which day / week / month is being viewed.
          Center(
            child: Text(
              periodLabel(period, now),
              style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 8.0),
          // Stat cards for the selected period.
          Row(
            children: [
              _statCard('Sessions', sessionCount.toString()),
              const SizedBox(width: 8.0),
              _statCard('Total Time', _formatTotal(total)),
              const SizedBox(width: 8.0),
              _statCard('Average', _formatTotal(average)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: selected ? Colors.teal : Colors.teal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20.0),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : Colors.teal,
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Column(
          children: [
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
