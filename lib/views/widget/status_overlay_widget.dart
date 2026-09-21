import 'package:flutter/material.dart';

/// Clock + status card designed to float over the attendance map.
///
/// Presentation-only: the page supplies the current time (ticked every second)
/// and small formatter callbacks for 12-hour time, dates and session duration,
/// so formatting logic stays in one place (`time_page.dart`).
class StatusOverlay extends StatelessWidget {
  const StatusOverlay({
    super.key,
    required this.now,
    required this.isTimedIn,
    this.currentTimeIn,
    required this.formatTime,
    required this.formatDate,
    required this.formatDuration,
    this.onTap,
    this.hint,
  });

  /// The current time; the page ticks this every second.
  final DateTime now;

  final bool isTimedIn;

  /// The stored time-in datetime string of the open session, if any.
  final String? currentTimeIn;

  /// Formats a stored datetime as `hh:mm AM` for the "Timed in at ..." line.
  final String Function(String? dateTimeString) formatTime;

  /// Formats a datetime as `Sep 15, 2026` for the date line.
  final String Function(String? dateTimeString) formatDate;

  /// Formats a session duration as `01h 23m 45s`.
  final String Function(DateTime inTime, DateTime? outTime) formatDuration;

  /// When set, the whole card is tappable (used as the punch button) and
  /// shows a ripple effect.
  final VoidCallback? onTap;

  /// Small call-to-action line under the status, e.g. `Tap for TIME IN`.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final DateTime? inTime = DateTime.tryParse(currentTimeIn ?? '');

    return Card(
      elevation: 4.0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatDate(now.toIso8601String()),
              style: TextStyle(
                fontSize: 13.0,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isTimedIn ? Icons.check_circle : Icons.cancel,
                  size: 16.0,
                  color: isTimedIn ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 5.0),
                Flexible(
                  child: Text(
                    isTimedIn
                        ? 'Timed in at ${formatTime(currentTimeIn)}'
                        : 'Not timed in',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.0),
                  ),
                ),
              ],
            ),
            if (isTimedIn && inTime != null)
              Text(
                'Session duration: ${formatDuration(inTime, null)}',
                style: TextStyle(
                  fontSize: 12.0,
                  color: Colors.grey[600],
                ),
              ),
            if (hint != null) ...[
              const SizedBox(height: 6.0),
              Text(
                hint!,
                style: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
