import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class KConstants{
  static const String themeModeKey = 'themeModeKey';
  static const String loggedInUsernameKey = 'loggedInUsername';

  /// Username of the currently logged in user, set on login.
  /// Kept in memory for the session and persisted in SharedPreferences.
  static String? loggedInUsername;

 
  ///  C:\xampp\htdocs\api\login.php
  static const String apiFolderName = 'api';


  static String get apiBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.1.149';
    }
    return 'http://localhost';
  }

  static String get loginUrl => 'http://192.168.1.149/api/login.php';
  static String get registerUrl => 'http://192.168.1.149/api/register.php';
  static String get profileUrl => 'http://192.168.1.149/api/profile.php';
  static String get changePasswordUrl => 'http://192.168.1.149/api/change_password.php';
  static String get attendanceUrl => 'http://192.168.1.149/api/attendance.php';
  static const String biometricUrl =
    'http://192.168.1.149/api/enable_biometric.php';

  /// Base URL used to resolve relative picture paths (e.g. 'uploads/pic_x.jpg')
  /// returned by the API into full image URLs.
  static String get apiBaseUrlForUploads => 'http://192.168.1.149/api/';
}
