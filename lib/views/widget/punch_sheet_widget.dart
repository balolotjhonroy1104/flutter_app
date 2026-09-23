import 'dart:async';

import 'package:flutter/material.dart';

/// Half-screen sheet shown over the map when the floating icon button is
/// tapped: shows the date, the time in/out times and the session duration,
/// plus the confirm button for the time in/out function.
class PunchSheet extends StatefulWidget {
  const PunchSheet({
    super.key,
    required this.isTimedIn,
    required this.currentTimeIn,
    required this.onPunch,
    required this.onMessage,
    required this.formatDate,
    required this.formatDuration,
  });

  final bool isTimedIn;
  /// The open session's time-in timestamp (set when isTimedIn is true).
  final String? currentTimeIn;

  /// Performs the punch and returns the server response (null = no connection).
  final Future<Map<String, dynamic>?> Function({required bool timeIn}) onPunch;

  /// Shows a snackbar on the page behind the sheet.
  final void Function(String message) onMessage;

  /// Formats a stored datetime as `Sep 16, 2026`.
  final String Function(String? dateTimeString) formatDate;

  /// Formats a record's duration as `01h 23m 45s` (live for open sessions).
  final String Function(Map<String, dynamic> record) formatDuration;

  @override
  State<PunchSheet> createState() => _PunchSheetState();
}

class _PunchSheetState extends State<PunchSheet> {
  bool _isPunching = false;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Ticks every second so the open session's duration stays live.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _onPunchPressed() async {
    if (_isPunching) return;

    final bool timeIn = !widget.isTimedIn;

    setState(() => _isPunching = true);

    final Map<String, dynamic>? data = await widget.onPunch(timeIn: timeIn);

    if (!mounted) return;
    setState(() => _isPunching = false);

    if (data == null) {
      widget.onMessage('Could not reach the server. Check your connection.');
      return;
    }

    if (data['success'] == true) {
      widget.onMessage(data['message']?.toString() ??
          (timeIn ? 'Timed in successfully.' : 'Timed out successfully.'));
      // Tell the page to refresh; closes the sheet.
      Navigator.pop(context, true);
    } else {
      // Server rejected the punch (e.g. already timed in): keep the sheet
      // open so the user can retry, with the reason in a snackbar.
      widget.onMessage(
          data['message']?.toString() ?? 'Failed to record attendance');
    }
  }

  /// Builds the info rows shown in the sheet.
  ///
  /// Time In sheet: only today's date — the user is about to punch in, so
  /// the time in/out and duration rows are hidden.
  /// Time Out sheet: the open session's date, time in, time out (Ongoing)
  /// and the running duration.
  List<Widget> _infoRows() {
    if (!widget.isTimedIn) {
      return [
        _infoRow(Icons.calendar_today, 'Date',
            widget.formatDate(_now.toIso8601String())),
      ];
    }

    // Time Out sheet: full details of the open session.
    final Map<String, dynamic> source =
        <String, dynamic>{'time_in': widget.currentTimeIn};

    if (source['time_in'] == null) {
      // Defensive: session flagged open but no timestamp came through.
      return [
        _infoRow(Icons.calendar_today, 'Date',
            widget.formatDate(_now.toIso8601String())),
        _infoRow(Icons.login, 'Time in', '--:--'),
        _infoRow(Icons.logout, 'Time out', '--:--'),
        _infoRow(Icons.timer, 'Duration', '--'),
      ];
    }

    final String duration = widget.formatDuration(source);

    // Date: show a range when the session spans midnight (timed in
    // yesterday, still ongoing today).
    final String inDate = widget.formatDate(source['time_in']?.toString());
    String dateValue = inDate;
    final String today = widget.formatDate(_now.toIso8601String());
    if (today.isNotEmpty && today != inDate) {
      dateValue = '$inDate - $today';
    }

    return [
      _infoRow(Icons.calendar_today, 'Date', dateValue),
      _infoRow(Icons.login, 'Time in',
          _formatSheetTime(source['time_in']?.toString())),
      _infoRow(Icons.logout, 'Time out', 'Ongoing'),
      _infoRow(Icons.timer, 'Duration', duration.isEmpty ? '--' : duration),
    ];
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18.0, color: Colors.teal),
          const SizedBox(width: 10.0),
          SizedBox(
            width: 80.0,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14.0, color: Colors.black),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _hour12(int hour) {
    final int h = hour % 12;
    return h == 0 ? '12' : h.toString().padLeft(2, '0');
  }

  String _ampm(int hour) => hour < 12 ? 'AM' : 'PM';

  String _twoDigits(int number) => number.toString().padLeft(2, '0');

  /// Formats a stored datetime string without needing the page's helpers.
  String _formatSheetTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return '--:--';
    final DateTime? parsed = DateTime.tryParse(dateTimeString);
    if (parsed == null) return dateTimeString;
    return '${_hour12(parsed.hour)}:${_twoDigits(parsed.minute)} ${_ampm(parsed.hour)}';
  }

  @override
  Widget build(BuildContext context) {
    // Exactly half the screen height, so the map stays visible above it.
    final double sheetHeight = MediaQuery.of(context).size.height * 0.5;

    return Container(
      height: sheetHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Drag handle.
          Container(
            height: 5.0,
            width: 45.0,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          const SizedBox(height: 16.0),
          Text(
            widget.isTimedIn ? 'Time Out' : 'Time In',
            style: const TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            widget.isTimedIn
                ? 'Tap below to record your time out.'
                : 'Tap below to record your time in.',
            style: TextStyle(
              fontSize: 14.0,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16.0),
          // Attendance info: date, time in/out and duration.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: Column(children: _infoRows()),
          ),
          const Spacer(),
          // Big confirm button.
          SizedBox(
            width: double.infinity,
            height: 56.0,
            child: FilledButton.icon(
              onPressed: _isPunching ? null : _onPunchPressed,
              style: FilledButton.styleFrom(
                backgroundColor:
                    widget.isTimedIn ? Colors.red : Colors.teal,
                foregroundColor: Colors.white,
              ),
              icon: _isPunching
                  ? const SizedBox(
                      height: 20.0,
                      width: 20.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: Colors.white,
                      ),
                    )
                  : Icon(widget.isTimedIn ? Icons.logout : Icons.login),
              label: Text(
                widget.isTimedIn ? 'TIME OUT' : 'TIME IN',
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
