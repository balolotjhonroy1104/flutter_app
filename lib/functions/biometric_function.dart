import 'dart:convert';

import 'package:app/databases/constants.dart';
import 'package:app/functions/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

/// Handles the biometric-login flow, driven from the LoginPage
/// "Login with Biometrics" button:
/// - [enableBiometricFromLogin] asks "Enable biometric authentication?"
///   and, on Enable, runs the fingerprint setup.
/// - [disableBiometric] turns biometric login off again: fingerprint
///   confirmation, server update and removal of the local token.
/// - [setupBiometric] checks the device, authenticates the user and
///   enables biometric login for the account via enable_biometric.php.
class BiometricFunctions {
  BiometricFunctions({required this.onMessage});

  // Secure-storage keys:

  /// user_id of the last successful password login on this device.
  static const String userIdStorageKey = 'biometric_user_id';

  /// Auth token of the last successful password login on this device.
  static const String tokenStorageKey = 'biometric_token';

  /// Written once the fingerprint setup prompt succeeded on this device;
  /// its presence means biometric login is enabled and ready to use.
  static const String authTokenKey = 'auth_token';

  /// Shows a message on the calling page.
  final void Function(String message) onMessage;

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// "Enable biometric authentication?" dialog.
  /// Returns true when the user taps Enable.
  Future<bool> showEnableDialog(BuildContext context) async {
    if (!context.mounted) return false;

    final bool? enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enable biometric authentication?"),
          content: const Text(
            "Enable fingerprint biometric authentication?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Not now"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text("Enable"),
            ),
          ],
        );
      },
    );

    return enable == true;
  }

  /// Called from the LoginPage "Login with Biometrics" button while
  /// biometric login is not enabled yet: asks the user, and on Enable
  /// runs the fingerprint setup so biometrics can be used to log in.
  Future<void> enableBiometricFromLogin({
    required BuildContext context,
    required int userId,
    required String token,
  }) async {
    final bool enable = await showEnableDialog(context);

    if (!enable) {
      // "Not now" - stay on the login page.
      return;
    }

    await setupBiometric(userId: userId, token: token);
  }

  /// "Turn off biometric authentication?" dialog.
  /// Returns true when the user taps Turn Off.
  Future<bool> showDisableDialog(BuildContext context) async {
    if (!context.mounted) return false;

    final bool? disable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Turn off biometric authentication?"),
          content: const Text(
            "You will need your username and password to log in again.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Turn Off"),
            ),
          ],
        );
      },
    );

    return disable == true;
  }

  /// Turns biometric login OFF: asks for confirmation, verifies the
  /// user's identity with a fingerprint, updates the server and removes
  /// the local auth token. Returns true when biometrics were disabled.
  Future<bool> disableBiometric({
    required BuildContext context,
    required int userId,
    required String token,
  }) async {
    final bool confirm = await showDisableDialog(context);
    if (!confirm) return false;

    // Prove it is really the owner turning it off.
    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: "Confirm your identity to turn off biometric login.",
        biometricOnly: true,
      );
      if (!authenticated) {
        onMessage("Cancelled - biometric login is still on.");
        return false;
      }
    } catch (e) {
      onMessage("Could not verify your identity: $e");
      return false;
    }

    // Tell the server (best effort - the local toggle below is what
    // decides whether the button offers login or setup).
    try {
      await ApiClient.post(
        Uri.parse(KConstants.biometricUrl),
        headers: {
          'Content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'biometric_enabled': 0,
          'token': token,
        }),
      );
    } catch (e) {
      // Server unreachable; disable locally anyway.
    }

    // With the token gone, the button goes back to the enable state.
    await _secureStorage.delete(key: authTokenKey);

    onMessage("Biometric login turned off");
    return true;
  }

  /// Verifies the device supports biometrics, authenticates the user, then
  /// enables biometric login for [userId] through enable_biometric.php.
  Future<void> setupBiometric({
    required int userId,
    required String token,
  }) async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();

      if (!isSupported) {
        onMessage(
          "This device does not support biometric authentication.",
        );
        return;
      }

      final List<BiometricType> biometrics =
          await _auth.getAvailableBiometrics();

      if (biometrics.isEmpty) {
        onMessage(
          "No fingerprints or biometric is registered on this device.",
        );
        return;
      }

      final bool authenticated = await _auth.authenticate(
        localizedReason:
            "Authenticate to enable biometric login for your account.",
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (!authenticated) {
        onMessage("Biometric setup was cancelled");
        return;
      }

      // Save the authentication token securely so the biometric
      // login flow can read it back later.
      await _secureStorage.write(key: authTokenKey, value: token);

      // Tell PHP that biometric login is enabled
      // for this particular account. The token is also sent in the
      // body because some Apache setups strip the Authorization header.
      final response = await http.post(
        Uri.parse(KConstants.biometricUrl),
        headers: {
          'Content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'biometric_enabled': 1,
          'token': token,
        }),
      );

      if (response.statusCode != 200) {
        onMessage(
          'Failed to enable biometric login (HTTP ${response.statusCode})',
        );
        return;
      }

      final data = ApiClient.decodeJson(response);
      if (data['success'] == true) {
        onMessage("Biometric login enabled successfully");
      } else {
        onMessage(data['message'] ?? 'Failed to enable biometric login');
      }
    } catch (e) {
      onMessage("Biometric setup failed: $e");
    }
  }
}
