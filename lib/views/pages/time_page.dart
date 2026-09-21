import 'dart:async';
import 'dart:convert';

import 'package:app/databases/constants.dart';
import 'package:app/databases/style.dart';
import 'package:app/views/widget/attendance_record_tile.dart';
import 'package:app/views/widget/punch_sheet_widget.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TimePage extends StatefulWidget {
  const TimePage({super.key});

  @override
  State<TimePage> createState() => _TimePageState();
}

class _TimePageState extends State<TimePage> {
  String username = '';

  bool _isLoading = true;
  bool isTimedIn = false;
  String? currentTimeIn;
  List<Map<String, dynamic>> records = [];

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // Google map state: pin where the user punched time in.
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _timeInLatLng;
  bool _locationEnabled = false;

  // Centers the map before any pin exists (Manila).
  static const LatLng _fallbackLocation = LatLng(14.5995, 120.9842);

  @override
  void initState() {
    super.initState();
    // Live clock, updates every second.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    loadAttendance();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> loadAttendance() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String savedUsername =
        prefs.getString(KConstants.loggedInUsernameKey) ??
            (KConstants.loggedInUsername ?? '');

    if (savedUsername.isEmpty) {
      // No session yet, nothing to load.
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(KConstants.attendanceUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'status', 'username': savedUsername}),
          )
          .timeout(const Duration(seconds: 15));

      print('Attendance Status code: ${response.statusCode}');
      print('Attendance Response body: ${response.body}');

      final data = _decodeJson(response.body);
      if (!mounted) return;
      if (data.isEmpty) {
        // The server answered with an HTML error page instead of JSON.
        setState(() => _isLoading = false);
        showMessage(
          'Server error: could not read the attendance table. '
          'Run the queries in api/setup.sql in phpMyAdmin, then try again.',
        );
        return;
      }

      setState(() {
        username = savedUsername;
        isTimedIn = data['is_timed_in'] == true;
        currentTimeIn = data['current_time_in']?.toString();
        records = (data['records'] as List<dynamic>? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _isLoading = false;
      });

      // Restore the time-in pin from the open session, if it has a location.
      final dynamic currentLat = data['current_time_in_lat'];
      final dynamic currentLng = data['current_time_in_lng'];
      if (isTimedIn && currentLat is num && currentLng is num) {
        _setTimeInPin(currentLat.toDouble(), currentLng.toDouble());
      }
    } catch (e) {
      print('ATTENDANCE ERROR: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      showMessage('Error: $e');
    }
  }

  /// Performs a time in/out punch and returns the parsed server response.
  /// Returns null only when the server could not be reached.
  /// UI feedback (snackbars, closing the sheet) is handled by the caller,
  /// which lets the punch sheet show the result while the map stays visible.
  Future<Map<String, dynamic>?> performPunch({required bool timeIn}) async {
    // Capture the current location so it can be pinned on the map.
    final Position? position = await _getCurrentLocation();

    try {
      final response = await http
          .post(
            Uri.parse(KConstants.attendanceUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': timeIn ? 'time_in' : 'time_out',
              'username': username,
              if (position != null) 'latitude': position.latitude,
              if (position != null) 'longitude': position.longitude,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('Punch Status code: ${response.statusCode}');
      print('Punch Response body: ${response.body}');

      final data = _decodeJson(response.body);
      if (data.isEmpty) {
        return <String, dynamic>{
          'success': false,
          'message': 'Server error: could not save the punch. '
              'Run the queries in api/setup.sql in phpMyAdmin, then try again.',
        };
      }

      if (data['success'] == true && timeIn && position != null) {
        // Pin the spot where the user punched time in.
        _setTimeInPin(position.latitude, position.longitude);
      }
      return data;
    } catch (e) {
      print('PUNCH ERROR: $e');
      return null;
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// Decodes the JSON body, returning an empty map when the server answered
  /// with something else (like an HTML error page), so the app can show a
  /// friendly message instead of a FormatException.
  Map<String, dynamic> _decodeJson(String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Not JSON — handled by the caller.
    }
    return {};
  }

  /// Requests location permission and returns the current position,
  /// or null when location is unavailable (the punch still goes through).
  Future<Position?> _getCurrentLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        showMessage('Location services are disabled. Punching without a pin.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        showMessage('Location permission denied. Punching without a pin.');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      print('LOCATION ERROR: $e');
      showMessage('Could not get your location. Punching without a pin.');
      return null;
    }
  }

  /// Shows a pin at the given time-in coordinates and centers the map on it.
  void _setTimeInPin(double latitude, double longitude) {
    final LatLng target = LatLng(latitude, longitude);
    setState(() {
      _timeInLatLng = target;
      _locationEnabled = true;
      _markers = {
        Marker(
          markerId: const MarkerId('time_in'),
          position: target,
          infoWindow: const InfoWindow(title: 'Timed in here'),
        ),
      };
    });
    _moveCamera(target);
  }

  void _moveCamera(LatLng target) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.0));
  }

  /// Opens the half-screen time in/out sheet over the map.
  Future<void> _openPunchSheet() async {
    final bool? punched = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PunchSheet(
        isTimedIn: isTimedIn,
        currentTimeIn: currentTimeIn,
        lastRecord: records.isNotEmpty ? records.first : null,
        onPunch: performPunch,
        onMessage: showMessage,
        formatDate: _formatDate,
        formatDuration: _formatDuration,
      ),
    );

    // Refresh status and history after a successful punch so the page
    // always matches the database.
    if (punched == true && mounted) {
      loadAttendance();
    }
  }

  String _formatTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return '--:--';
    final DateTime? parsed = DateTime.tryParse(dateTimeString);
    if (parsed == null) return dateTimeString;
    return '${_hour12(parsed.hour)}:${_twoDigits(parsed.minute)} ${_ampm(parsed.hour)}';
  }

  /// Converts a 24-hour value to 12-hour format (12 for 0 and 12).
  String _hour12(int hour) {
    final int h = hour % 12;
    return _twoDigits(h == 0 ? 12 : h);
  }

  String _ampm(int hour) => hour < 12 ? 'AM' : 'PM';

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

  String _formatDateRange(Map<String, dynamic> record) {
    final String inDate = _formatDate(record['time_in']?.toString());
    final String outDate = _formatDate(record['time_out']?.toString());
    if (outDate.isNotEmpty && outDate != inDate) {
      return '$inDate - $outDate';
    }
    return inDate;
  }

  String _formatDuration(Map<String, dynamic> record) {
    final DateTime? inTime =
        DateTime.tryParse(record['time_in']?.toString() ?? '');
    if (inTime == null) return '';
    final DateTime? outTime =
        DateTime.tryParse(record['time_out']?.toString() ?? '');
    return _formatDurationFrom(inTime, outTime);
  }

  /// Formats a session duration as `01h 23m 45s`, counting up to now for an
  /// open session. Used by both the history tiles and the StatusOverlay.
  String _formatDurationFrom(DateTime inTime, DateTime? outTime) {
    final DateTime end = outTime ?? _now;
    final Duration diff = end.difference(inTime);
    final int hours = diff.inHours;
    final int minutes = diff.inMinutes.remainder(60);
    final int seconds = diff.inSeconds.remainder(60);
    return '${_twoDigits(hours)}h ${_twoDigits(minutes)}m ${_twoDigits(seconds)}s';
  }

  String _twoDigits(int number) => number.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Attendance'),
        actions: [
          IconButton(
            tooltip: 'Attendance history',
            onPressed: _openHistorySheet,
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      // Full-screen map. The status card now lives in the floating button
      // below, so nothing overlays the map.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _timeInLatLng ?? _fallbackLocation,
                zoom: _timeInLatLng != null ? 16.0 : 11.0,
              ),
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                if (_timeInLatLng != null) {
                  _moveCamera(_timeInLatLng!);
                }
              },
              myLocationEnabled: _locationEnabled,
              myLocationButtonEnabled: _locationEnabled,
              zoomControlsEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: false,
            ),

      // Icon-only floating action button: tapping it opens the half-screen
      // sheet with the time in/out info and function.
      floatingActionButton:Padding(
        padding: const EdgeInsets.only(bottom:50),
        child: FloatingActionButton(
            onPressed: _openPunchSheet,
            tooltip: isTimedIn ? 'Time out' : 'Time in',
            backgroundColor: isTimedIn ? Colors.red : Colors.teal,
            foregroundColor: Colors.white,
            child: Icon(isTimedIn ? Icons.logout : Icons.login),
          ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
    
  }


  /// Opens the attendance history in a bottom sheet.
  void _openHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
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
              Expanded(
                child: records.isEmpty
                    ? const Center(
                        child: Text(
                          'No attendance records yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: records.length,
                        itemBuilder: (context, index) => AttendanceRecordTile(
                          record: records[index],
                          formatTime: _formatTime,
                          formatDateRange: _formatDateRange,
                          formatDuration: _formatDuration,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }


}
