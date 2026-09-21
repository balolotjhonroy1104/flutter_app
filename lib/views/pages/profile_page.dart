import 'dart:convert';

import 'package:app/databases/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Profile data, loaded from the API using the logged in username.
  String fullName = '';
  String email = '';
  String username = '';
  String password = '';
  String? profilePictureUrl;

  bool _isLoading = true;
  bool isPassword = false;
  bool _isUploadingPicture = false;
  XFile? _newProfilePicture;

  final TextEditingController controllerFullName = TextEditingController();
  final TextEditingController controllerEmail = TextEditingController();
  final TextEditingController controllerUsername = TextEditingController();
  final TextEditingController controllerPW = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    controllerFullName.dispose();
    controllerEmail.dispose();
    controllerUsername.dispose();
    controllerPW.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String savedUsername =
        prefs.getString(KConstants.loggedInUsernameKey) ??
            (KConstants.loggedInUsername ?? '');

    if (savedUsername.isEmpty) {
      // No session yet, fall back to placeholder info.
      if (!mounted) return;
      setState(() {
        username = '';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(KConstants.profileUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': savedUsername}),
          )
          .timeout(const Duration(seconds: 15));

      print('Profile Status code: ${response.statusCode}');
      print('Profile Response body: ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() {
          username = data['username']?.toString() ?? savedUsername;
          fullName = data['full_name']?.toString() ?? '';
          email = data['email']?.toString() ?? '';
          password = data['password']?.toString() ?? '';
          profilePictureUrl = data['profile_picture']?.toString();
          controllerFullName.text = fullName;
          controllerEmail.text = email;
          controllerUsername.text = username;
          controllerPW.text = password;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        showMessage(data['message']?.toString() ?? 'Failed to load profile.');
      }
    } catch (e) {
      print('PROFILE ERROR: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      showMessage('Error: $e');
    }
  }

  Future<void> _pickProfilePicture() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _newProfilePicture = picked);
      await _uploadProfilePicture();
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_newProfilePicture == null || _isLoading) return;

    setState(() => _isUploadingPicture = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(KConstants.profileUrl),
      )
        ..fields['username'] = username
        ..files.add(await http.MultipartFile.fromPath(
          'profile_picture',
          _newProfilePicture!.path,
        ));

      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      print('Profile picture Status code: ${response.statusCode}');
      print('Profile picture Response body: ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() {
          profilePictureUrl = data['profile_picture']?.toString();
          _newProfilePicture = null;
        });
        showMessage(data['message']?.toString() ?? 'Profile picture updated.');
      } else {
        showMessage(data['message']?.toString() ?? 'Upload failed');
      }
    } catch (e) {
      print('PROFILE PICTURE ERROR: $e');
      showMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPicture = false);
    }
  }

  Future<void> openChangePasswordSheet() async {
    final bool? changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) => ChangePasswordSheet(username: username),
    );
    if (changed == true && mounted) {
      // Refresh in case the backend returns updated data.
      loadProfile();
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    double widthScreen = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: FractionallySizedBox(
                    widthFactor: widthScreen > 500 ? 0.6 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60.0,
                                backgroundColor: Colors.teal,
                                backgroundImage: _profileImageProvider,
                              ),
                              Positioned(
                                bottom: 0.0,
                                right: 0.0,
                                child: CircleAvatar(
                                  radius: 20.0,
                                  backgroundColor: Colors.teal[600],
                                  child: _isUploadingPicture
                                      ? const SizedBox(
                                          height: 16.0,
                                          width: 16.0,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.0,
                                            color: Colors.white,
                                          ),
                                        )
                                      : IconButton(
                                          onPressed: _pickProfilePicture,
                                          icon: const Icon(
                                            Icons.camera_alt,
                                            size: 20.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        Center(
                          child: Text(
                            fullName.isEmpty ? 'No name set' : fullName,
                            style: const TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '@$username',
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        _buildInfoField(
                          label: 'Full Name:',
                          controller: controllerFullName,
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 10.0),
                        _buildInfoField(
                          label: 'Email:',
                          controller: controllerEmail,
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 10.0),
                        _buildInfoField(
                          label: 'Username:',
                          controller: controllerUsername,
                          icon: Icons.alternate_email,
                        ),
                        const SizedBox(height: 10.0),
                        _buildPasswordField(),
                        const SizedBox(height: 20.0),
                        FilledButton(
                          onPressed: username.isEmpty
                              ? null
                              : openChangePasswordSheet,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 40.0),
                          ),
                          child: const Text('CHANGE PASSWORD'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 5.0),
        TextField(
          readOnly: true,
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15.0), 
            ),
          ),
        ),
      ],
    );
  }

  /// Resolves the profile picture into an image provider: a network image
  /// when the API returned a picture path, otherwise a local placeholder.
  ImageProvider get _profileImageProvider {
    if (profilePictureUrl != null && profilePictureUrl!.isNotEmpty) {
      final String url = profilePictureUrl!.startsWith('http')
          ? profilePictureUrl!
          : '${KConstants.apiBaseUrlForUploads}$profilePictureUrl';
      // Cache-buster so a freshly uploaded picture replaces the old one.
      return NetworkImage(
        '$url?t=${DateTime.now().millisecondsSinceEpoch}',
      );
    }
    return const AssetImage('lib/assets/images/profile.jpg');
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password:',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 5.0),
        TextField(
          readOnly: true,
          obscureText: !isPassword,
          controller: controllerPW,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline),
            hintText: 'PASSWORD',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            suffixIcon: IconButton(
              onPressed: () => setState(() => isPassword = !isPassword),
              icon: Icon(
                isPassword ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key, required this.username});

  final String username;

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final TextEditingController controllerCurrentPW = TextEditingController();
  final TextEditingController controllerNewPW = TextEditingController();
  final TextEditingController controllerConfirmPW = TextEditingController();
  bool isCurrentPassword = false;
  bool isNewPassword = false;
  bool isConfirmPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    controllerCurrentPW.dispose();
    controllerNewPW.dispose();
    controllerConfirmPW.dispose();
    super.dispose();
  }

  Future<void> onChangePasswordPressed() async {
    if (_isLoading) return;

    final current = controllerCurrentPW.text;
    final newPassword = controllerNewPW.text;
    final confirm = controllerConfirmPW.text;

    if (current.isEmpty) {
      showMessage('Please enter your current password.');
      return;
    }
    if (newPassword.length < 6) {
      showMessage('New password must be at least 6 characters.');
      return;
    }
    if (newPassword != confirm) {
      showMessage('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse(KConstants.changePasswordUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': widget.username,
              'current_password': current,
              'new_password': newPassword,
              'confirm_password': confirm,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('Change password Status code: ${response.statusCode}');
      print('Change password Response body: ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (data['success'] == true) {
        Navigator.pop(context, true);
      } else {
        showMessage(data['message']?.toString() ?? 'Failed to change password');
      }
    } catch (e) {
      print('CHANGE PASSWORD ERROR: $e');
      showMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Change Password',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20.0),
            const Text(
              'Current Password:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 5.0),
            TextField(
              controller: controllerCurrentPW,
              obscureText: !isCurrentPassword,
              decoration: InputDecoration(
                hintText: 'Enter your current password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => isCurrentPassword = !isCurrentPassword),
                  icon: Icon(
                    isCurrentPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            const Text(
              'New Password:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 5.0),
            TextField(
              controller: controllerNewPW,
              obscureText: !isNewPassword,
              decoration: InputDecoration(
                hintText: 'At least 6 characters',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => isNewPassword = !isNewPassword),
                  icon: Icon(
                    isNewPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            const Text(
              'Confirm New Password:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 5.0),
            TextField(
              controller: controllerConfirmPW,
              obscureText: !isConfirmPassword,
              decoration: InputDecoration(
                hintText: 'Re-enter your new password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => isConfirmPassword = !isConfirmPassword),
                  icon: Icon(
                    isConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            FilledButton(
              onPressed: _isLoading ? null : onChangePasswordPressed,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40.0),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20.0,
                      width: 20.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    )
                  : const Text('SAVE NEW PASSWORD'),
            ),
            const SizedBox(height: 20.0),
          ],
        ),
      ),
    );
  }
}
