import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:app/functions/biometric_function.dart';

/// On/off switch for biometric authentication.
///
/// Extracted from login_page.dart: the toggle icon beside the
/// "Login with Biometrics" button opens [toggleBiometric], which shows the
/// current state and turns biometric login ON (fingerprint setup) or
/// OFF (fingerprint confirmation + server update + local token cleared).
class BiometricEnabler {
  BiometricEnabler({required this.functions});

  /// Shared enable/setup/disable logic from biometric_function.dart
  /// (also provides the onMessage callback for snackbars).
  final BiometricFunctions functions;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Shows the on/off dialog and applies the user's choice.
  ///
  /// Returns:
  /// - true/false -> the new biometric-enabled state
  /// - null       -> dialog closed or toggle cancelled; nothing changed
  Future<bool?> toggleBiometric({
    required BuildContext context,
    required bool isBiometricEnabled,
    required bool isDeviceCapable,
  }) async {
    if (!isDeviceCapable) {
      functions.onMessage(
        "Biometric authentication is not available on this device",
      );
      return null;
    }

    final bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isBiometricEnabled
                ? "Biometric authentication is ON"
                : "Biometric authentication is OFF",
          ),
          content: Text(
            isBiometricEnabled
                ? "Turn it off to log in with your username "
                    "and password only."
                : "Turn it on to log in with your fingerprint.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Close"),
            ),
            FilledButton(
              style: isBiometricEnabled
                  ? FilledButton.styleFrom(backgroundColor: Colors.red)
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(isBiometricEnabled ? "Turn OFF" : "Turn ON"),
            ),
          ],
        );
      },
    );

    if (proceed != true || !context.mounted) return null;

    // Credentials saved by the last successful password login.
    final String? userIdStr = await _secureStorage.read(
      key: BiometricFunctions.userIdStorageKey,
    );
    final String? token = await _secureStorage.read(
      key: BiometricFunctions.tokenStorageKey,
    );
    final int? userId = int.tryParse(userIdStr ?? '');

    if (userId == null || token == null || token.isEmpty) {
      functions.onMessage(
        "Login with your username and password once first, "
        "then biometrics can be switched on or off.",
      );
      return null;
    }

    if (isBiometricEnabled) {
      // -------- TURN OFF --------
      // Fingerprint confirmation, server update, local token cleared.
      await functions.disableBiometric(
        context: context,
        userId: userId,
        token: token,
      );
    } else {
      // -------- TURN ON --------
      // The user already chose "Turn ON", so run the fingerprint
      // setup directly without asking again.
      await functions.setupBiometric(userId: userId, token: token);
    }

    if (!context.mounted) return null;

    // Report the actual new state so the button stays in sync.
    final String? authToken = await _secureStorage.read(
      key: BiometricFunctions.authTokenKey,
    );
    return authToken != null && authToken.isNotEmpty;
  }
}
