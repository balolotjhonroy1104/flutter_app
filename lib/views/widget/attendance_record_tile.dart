import 'package:flutter/material.dart';

/// One attendance event card used in the history list. Each session renders
/// as two separate cards: a Time In card (always) and a Time Out card (once
/// the session is closed). Set [isTimeIn] to pick which one this instance
/// shows.
///
/// Presentation-only: the page supplies the record map (time_in / time_out)
/// and formatter callbacks so the 12-hour / date / duration helpers stay in
/// one place (`time_page.dart`).
class AttendanceRecordTile extends StatelessWidget {
  const AttendanceRecordTile({
    super.key,
    required this.record,
    required this.isTimeIn,
    required this.formatTime,
    required this.formatDate,
    required this.formatDuration,
  });

  /// One row from the server's `records` list:
  /// `{ time_in: ..., time_out: ... }` (time_out is null while still open).
  final Map<String, dynamic> record;

  /// Whether this card shows the time-in event (false = time out).
  final bool isTimeIn;

  /// Formats a stored datetime as `hh:mm AM`.
  final String Function(String? dateTimeString) formatTime;

  /// Formats a stored datetime as `Sep 15, 2026`.
  final String Function(String? dateTimeString) formatDate;

  /// Formats the session duration as `01h 23m 45s` (live for open sessions).
  final String Function(Map<String, dynamic> record) formatDuration;

  @override
  Widget build(BuildContext context) {
    final bool isClosed = record['time_out'] != null;
    final String timestamp =
        (isTimeIn ? record['time_in'] : record['time_out'])?.toString() ?? '';

    final bool ongoing = isTimeIn && !isClosed;

    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.only(bottom: 10.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (isTimeIn ? Colors.teal : Colors.red).withOpacity(0.12),
          child: Icon(
            isTimeIn ? Icons.login : Icons.logout,
            color: isTimeIn ? Colors.teal : Colors.red,
            size: 20.0,
          ),
        ),
        title: Text(
          isTimeIn ? 'Time In' : 'Time Out',
          style: const TextStyle(
            fontSize: 15.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${formatDate(timestamp)}  •  ${formatTime(timestamp)}',
          style: TextStyle(
            fontSize: 13.0,
            color: Colors.grey[600],
          ),
        ),
        trailing: ongoing
            // Session still open: the Time In card says so.
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: const Text(
                  'Ongoing',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              )
            // Closed: the Time Out card carries the session duration.
            : (isTimeIn
                ? const Icon(Icons.check_circle, color: Colors.green)
                : Column(
                    // Label above the value so the user knows what the
                    // numbers are at a glance.
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Duration',
                        style: TextStyle(
                          fontSize: 11.0,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        formatDuration(record),
                        style: const TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )),
      ),
    );
  }
}
