import 'package:flutter/material.dart';

/// One attendance session card used in the history list.
///
/// Presentation-only: the page supplies the record map (time_in / time_out)
/// and formatter callbacks so the 12-hour / date / duration helpers stay in
/// one place (`time_page.dart`).
class AttendanceRecordTile extends StatelessWidget {
  const AttendanceRecordTile({
    super.key,
    required this.record,
    required this.formatTime,
    required this.formatDateRange,
    required this.formatDuration,
  });

  /// One row from the server's `records` list:
  /// `{ time_in: ..., time_out: ... }` (time_out is null while still open).
  final Map<String, dynamic> record;

  /// Formats a stored datetime as `hh:mm AM`.
  final String Function(String? dateTimeString) formatTime;

  /// Formats the record as a date or date range, e.g. `Sep 15, 2026` or
  /// `Sep 15, 2026 - Sep 16, 2026` for overnight sessions.
  final String Function(Map<String, dynamic> record) formatDateRange;

  /// Formats the session duration as `01h 23m 45s` (live for open sessions).
  final String Function(Map<String, dynamic> record) formatDuration;

  @override
  Widget build(BuildContext context) {
    final bool isClosed = record['time_out'] != null;

    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.only(bottom: 10.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: ListTile(
        leading: Icon(
          isClosed ? Icons.check_circle : Icons.timelapse,
          color: isClosed ? Colors.green : Colors.orange,
        ),
        title: Text(
          'In: ${formatTime(record['time_in']?.toString())}   Out: ${formatTime(record['time_out']?.toString())}',
          style: const TextStyle(fontSize: 15.0),
        ),
        subtitle: Text(
          formatDateRange(record),
          style: TextStyle(
            fontSize: 13.0,
            color: Colors.grey[600],
          ),
        ),
        trailing: Text(
          formatDuration(record),
          style: const TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
