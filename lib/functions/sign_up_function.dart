import 'dart:convert';

import 'package:app/databases/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Handles sign-up validation and communication with register.php.
class SignUpFunctions {
  SignUpFunctions({
    required this.controllerUsername,
    required this.controllerFullName,
    required this.controllerEmail,
    required this.controllerProfilePicture,
    required this.controllerPW,
    required this.controllerConfirmPW,
    required this.onMessage,
    required this.onLoadingChanged,
    this.onSuccess,
  });

  final TextEditingController controllerUsername;
  final TextEditingController controllerFullName;
  final TextEditingController controllerEmail;
  final TextEditingController controllerProfilePicture;
  final TextEditingController controllerPW;
  final TextEditingController controllerConfirmPW;

  /// Shows a message on the SignUpPage.
  final void Function(String message) onMessage;

  /// Controls the loading state of the sign-up button.
  final void Function(bool isLoading) onLoadingChanged;

  /// Called after successful registration.
  ///
  /// Returns:
  /// - userId: ID of the newly created account
  /// - token: authentication token returned by PHP
  final Future<void> Function(int userId, String token)? onSuccess;

  /// Profile picture selected by the user.
  XFile? profilePicture;

  bool _isLoading = false;

  Future<void> onSignUpPressed() async {
    if (_isLoading) return;

    final username = controllerUsername.text.trim();
    final fullName = controllerFullName.text.trim();
    final email = controllerEmail.text.trim();
    final password = controllerPW.text;
    final confirm = controllerConfirmPW.text;

    // -----------------------------
    // VALIDATION
    // -----------------------------

    if (username.isEmpty) {
      onMessage('Please choose a username.');
      return;
    }

    if (fullName.isEmpty) {
      onMessage('Please enter your full name.');
      return;
    }

    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      onMessage('Please enter a valid email address.');
      return;
    }

    if (password.length < 6) {
      onMessage('Password must be at least 6 characters.');
      return;
    }

    if (password != confirm) {
      onMessage('Passwords do not match.');
      return;
    }

    _isLoading = true;
    onLoadingChanged(true);

    try {
      // -----------------------------
      // SEND REGISTRATION REQUEST
      // -----------------------------

      final response = profilePicture == null
          ? await _postJson(
              username,
              fullName,
              email,
              password,
              confirm,
            )
          : await _postMultipart(
              username,
              fullName,
              email,
              password,
              confirm,
            );

      debugPrint(
        'Sign up Status code: ${response.statusCode}',
      );

      debugPrint(
        'Sign up Response body: ${response.body}',
      );

      // -----------------------------
      // CHECK HTTP RESPONSE
      // -----------------------------

      if (response.statusCode != 200) {
        onMessage(
          'Server error: ${response.statusCode}',
        );
        return;
      }

      // -----------------------------
      // DECODE JSON
      // -----------------------------

      final data =
          jsonDecode(response.body) as Map<String, dynamic>;

      // -----------------------------
      // REGISTRATION SUCCESS
      // -----------------------------

      if (data['success'] == true) {
        final userId = int.tryParse(
          data['user_id'].toString(),
        );

        final token = data['token']?.toString();

        // Make sure PHP actually returned these.
        if (userId == null || token == null || token.isEmpty) {
          onMessage(
            'Account was created, but authentication information '
            'was not returned by the server.',
          );
          return;
        }

        onMessage(
          data['message']?.toString() ??
              'Account created successfully.',
        );

        // Clear the form.
        controllerUsername.clear();
        controllerFullName.clear();
        controllerEmail.clear();
        controllerProfilePicture.clear();
        controllerPW.clear();
        controllerConfirmPW.clear();

        profilePicture = null;

        // -----------------------------------
        // SEND USER ID + TOKEN TO SIGNUP PAGE
        // -----------------------------------

        await onSuccess?.call(
          userId,
          token,
        );
      } else {
        onMessage(
          data['message']?.toString() ??
              'Registration failed.',
        );
      }
    } catch (e) {
      debugPrint(
        'SIGN UP ERROR: $e',
      );

      onMessage(
        'Error: $e',
      );
    } finally {
      _isLoading = false;
      onLoadingChanged(false);
    }
  }

  // ============================================================
  // JSON REGISTRATION
  // ============================================================

  Future<http.Response> _postJson(
    String username,
    String fullName,
    String email,
    String password,
    String confirm,
  ) async {
    return http
        .post(
          Uri.parse(KConstants.registerUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'full_name': fullName,
            'email': email,
            'username': username,
            'password': password,
            'confirm_password': confirm,
          }),
        )
        .timeout(
          const Duration(seconds: 15),
        );
  }

  // ============================================================
  // MULTIPART REGISTRATION
  // ============================================================

  Future<http.Response> _postMultipart(
    String username,
    String fullName,
    String email,
    String password,
    String confirm,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(KConstants.registerUrl),
    )
      ..fields['full_name'] = fullName
      ..fields['email'] = email
      ..fields['username'] = username
      ..fields['password'] = password
      ..fields['confirm_password'] = confirm
      ..files.add(
        await http.MultipartFile.fromPath(
          'profile_picture',
          profilePicture!.path,
        ),
      );

    final streamed = await request
        .send()
        .timeout(
          const Duration(seconds: 30),
        );

    return http.Response.fromStream(streamed);
  }
}