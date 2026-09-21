
import 'package:app/functions/sign_up_function.dart';
import 'package:app/views/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

class SignUpPage extends StatefulWidget {

  const SignUpPage({super.key, required this.title});
  final String title;

  @override

  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {

  final TextEditingController controllerUsername = TextEditingController();
  final TextEditingController controllerFullName = TextEditingController();
  final TextEditingController controllerEmail = TextEditingController();
  final TextEditingController controllerProfilePicture = TextEditingController();
  final TextEditingController controllerPW = TextEditingController();
  final TextEditingController controllerConfirmPW = TextEditingController();
  bool isPassword = false;
  bool isConfirmPassword = false;
  bool _isLoading = false;
  XFile? _profilePicture;

  // Sign-up logic (validation + API calls) lives in sign_up_function.dart.
  late final SignUpFunctions _signUpFunctions = SignUpFunctions(
    controllerUsername: controllerUsername,
    controllerFullName: controllerFullName,
    controllerEmail: controllerEmail,
    controllerProfilePicture: controllerProfilePicture,
    controllerPW: controllerPW,
    controllerConfirmPW: controllerConfirmPW,
    onMessage: showMessage,
    onLoadingChanged: (bool loading) {
      if (mounted) setState(() => _isLoading = loading);
    },
    onSuccess: (int userId, String token) async {
      if (!mounted) return;

      setState(() {
        _profilePicture = null;
      });

      // Biometric setup is offered on the LoginPage instead
      // ("Login with Biometrics" button).
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPage(title: 'LOGIN'),
        ),
      );
    },
  );
  @override
  void dispose() {
    controllerUsername.dispose();
    controllerFullName.dispose();
    controllerEmail.dispose();
    controllerProfilePicture.dispose();
    controllerPW.dispose();
    controllerConfirmPW.dispose();
    super.dispose();
  }
  Future<void> _pickProfilePicture() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() {
        _profilePicture = picked;
        controllerProfilePicture.text = picked.name;
      });
      _signUpFunctions.profilePicture = picked;
    }
  }
  @override
  Widget build(BuildContext context) {
    double widthScreen = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: FractionallySizedBox(
              widthFactor: widthScreen > 400 ? 0.5 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Lottie.asset(
                    'lib/assets/lotties/login.json',
                    height: 300.0,
                  ),
                  Text('Full Name:',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 5.0),
                  TextField(
                    controller: controllerFullName,
                    decoration: InputDecoration(
                      hintText: 'FULL NAME',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text('Email:',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 5.0),
                  TextField(
                    controller: controllerEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'EMAIL',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text('Profile Picture:',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 5.0),
                  TextField(
                    readOnly: true,
                    onTap: _pickProfilePicture,
                    controller: controllerProfilePicture,
                    decoration: InputDecoration(
                      hintText: 'CHOOSE AN IMAGE FROM YOUR DEVICE',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      suffixIcon: IconButton(
                        onPressed: _pickProfilePicture,
                        icon: Icon(
                          _profilePicture == null
                              ? Icons.photo_library_outlined
                              : Icons.check_circle,
                          color: _profilePicture == null
                              ? null
                              : Colors.green,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text('Username:',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 5.0),
                  TextField(
                    controller: controllerUsername,
                    decoration: InputDecoration(
                      hintText: 'USERNAME',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text('Password:',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 5.0),
                  TextField(
                    controller: controllerPW,
                    obscureText: !isPassword,
                    decoration: InputDecoration(
                      hintText: 'At least 6 characters',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => 
                        isPassword = !isPassword), icon:Icon(
                          isPassword ? Icons.visibility : Icons.visibility_off,
                        ),),
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text('Confirm Password:',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 5.0),
                  TextField(
                    controller: controllerConfirmPW,
                    obscureText: !isConfirmPassword,
                    decoration: InputDecoration(
                      hintText: 'Re-enter your password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => 
                        isConfirmPassword = !isConfirmPassword), icon:Icon(
                          isConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        ),),
                    ),
                  ),
                  SizedBox(height: 20.0),
                  FilledButton(
                    onPressed: _isLoading ? null : () {
                      _signUpFunctions.onSignUpPressed();
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 40.0),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20.0,
                            width: 20.0,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          )
                        : Text(widget.title),
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Already have an account?",style: TextStyle(color: Colors.grey),),
                        TextButton(onPressed: () {
                          Navigator.pushReplacement(context,
                           MaterialPageRoute(builder: 
                           (context) => LoginPage(title: 'LOGIN'),
                           ),
                           );
                        }, child: Text("LOGIN HERE"))
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
  

}