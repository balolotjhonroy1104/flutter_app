import 'dart:async';

import 'package:app/databases/style.dart';
import 'package:app/views/widget/attendance_record_tile.dart';
import 'package:app/views/widget/attendance_summary_widget.dart';
import 'package:flutter/material.dart';

/// The attendance history bottom sheet: a Day / Weekly / Monthly summary at
/// the top, and below it ONLY the time in/out cards that belong to the
/// selected period — pick Weekly and you see just that week's sessions.
class AttendanceHistorySheet extends StatefulWidget {
  const AttendanceHistorySheet({super.key, required this.records});

  /// All of the user's records from the server:
  /// `{ time_in: ..., time_out: ... }` (time_out null while open).
  final List<Map<String, dynamic>> records;

  @override
  State<AttendanceHistorySheet> createState() =>
      _AttendanceHistorySheetState();
}

class _AttendanceHistorySheetState extends State<AttendanceHistorySheet> {
  SummaryPeriod _period = SummaryPeriod.day;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Ticks every second: keeps an ongoing session's duration and its
    // contribution to the summary totals live.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  /// One session renders as separate cards: Time In always, Time Out once
  /// the session is closed.
  Widget _sessionCards(Map<String, dynamic> record) {
    return Column(
      children: [
        AttendanceRecordTile(
          record: record,
          isTimeIn: true,
          formatTime: _formatTime,
          formatDate: _formatDate,
          formatDuration: _formatDuration,
        ),
        if (record['time_out'] != null)
          AttendanceRecordTile(
            record: record,
            isTimeIn: false,
            formatTime: _formatTime,
            formatDate: _formatDate,
            formatDuration: _formatDuration,
          ),
      ],
    );
  }

  String _twoDigits(int number) => number.toString().padLeft(2, '0');

  String _formatTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return '--:--';
    final DateTime? parsed = DateTime.tryParse(dateTimeString);
    if (parsed == null) return dateTimeString;

    final int h = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final String ampm = parsed.hour < 12 ? 'AM' : 'PM';
    return '${_twoDigits(h)}:${_twoDigits(parsed.minute)} $ampm';
  }

  String _formatDate(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return '';
    final DateTime? parsed = DateTime.tryParse(dateTimeString);
    if (parsed == null) return dateTimeString;

    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  String _formatDuration(Map<String, dynamic> record) {
    final Duration duration =
        AttendanceSummary.sessionDuration(record, _now);
    if (duration.inSeconds <= 0) return '';

    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);
    return '${_twoDigits(hours)}h ${_twoDigits(minutes)}m ${_twoDigits(seconds)}s';
  }

  @override
  Widget build(BuildContext context) {
    // Only the records in the selected period are shown in the list.
    final List<Map<String, dynamic>> periodRecords =
        AttendanceSummary.filterRecords(widget.records, _period, _now);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Attendance History',
              style: KtextStyle.titleTealText,
            ),
          ),
          const Divider(height: 1.0),
          // Day / Weekly / Monthly switcher + stat cards.
          AttendanceSummary(
            records: widget.records,
            period: _period,
            now: _now,
            onPeriodChanged: (SummaryPeriod period) =>
                setState(() => _period = period),
          ),
          const Divider(height: 1.0),
          Expanded(
            child: periodRecords.isEmpty
                ? Center(
                    child: Text(
                      'No attendance records for this ${_period.name}.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: periodRecords.length,
                    itemBuilder: (context, index) =>
                        _sessionCards(periodRecords[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
