

class KConstants {
  static const String themeModeKey = 'themeModeKey';
  static const String loggedInUsernameKey = 'loggedInUsername';

  /// Username of the currently logged in user.
  static String? loggedInUsername;

  /// Online PHP API folder.
  static const String apiFolderName = 'api';

  /// Base URL of the online PHP server.
  static const String apiBaseUrl = 'https://janry-app.infinityfreeapp.com';

  /// PHP API endpoints.
  static String get loginUrl =>
      '$apiBaseUrl/api/login.php';

  static String get registerUrl =>
      '$apiBaseUrl/api/register.php';

  static String get profileUrl =>
      '$apiBaseUrl/api/profile.php';

  static String get changePasswordUrl =>
      '$apiBaseUrl/api/change_password.php';

  static String get attendanceUrl =>
      '$apiBaseUrl/api/attendance.php';

  static String get biometricUrl =>
      '$apiBaseUrl/api/enable_biometric.php';

  /// Used for profile-picture URLs.
  ///
  /// Example returned by PHP:
  /// uploads/pic_123.jpg
  ///
  /// Becomes:
 /// https://yourapp.infinityfree.me/api/uploads/pic_123.jpg
  static String get apiBaseUrlForUploads =>
      '$apiBaseUrl/api/';
}