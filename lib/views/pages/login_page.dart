import 'dart:convert';

import 'package:app/databases/constants.dart';
import 'package:app/functions/biometric_enabler.dart';
import 'package:app/functions/biometric_function.dart';
import 'package:app/views/pages/home_page.dart';
import 'package:app/views/pages/sign_up_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key,
  required this.title,
  
  });
  final String title;

  @override
  State<LoginPage> createState() => _LoginPageState();

}

class _LoginPageState extends State<LoginPage> {

  TextEditingController controllerUser = TextEditingController();
  TextEditingController controllerPW = TextEditingController();
  bool isPassword = false;
  bool _isLoading = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Enable/setup flow ("Enable biometric authentication?" dialog +
  // fingerprint setup) lives in biometric_function.dart; the on/off
  // toggle dialog lives in biometric_enabler.dart.
  late final BiometricFunctions _biometricFunctions = BiometricFunctions(
    onMessage: showMessage,
  );
  late final BiometricEnabler _biometricEnabler = BiometricEnabler(
    functions: _biometricFunctions,
  );
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _canCheckBiometrics = false ;
  bool _isBiometricAvailable = false; 

  /// True after the user enabled biometric login on this device;
  /// decides whether the button authenticates or offers to enable.
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricsAvailability();
  }
  Future<void> _checkBiometricsAvailability () async{
    try{
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();

      // Biometric login is enabled when the setup prompt completed
      // before and left the auth token behind.
      final String? authToken =
          await _secureStorage.read(key: BiometricFunctions.authTokenKey);

      if(!mounted)return;

      setState(() {
        _canCheckBiometrics = canCheck ;
        _isBiometricAvailable = isSupported;
        _isBiometricEnabled = authToken != null && authToken.isNotEmpty;
      });
    }catch(e){
      print('BIOMETRIC CHECK ERROR: $e');
    }
  }
  /// Handles the "Login with Biometrics" button:
  /// - Not enabled yet -> asks "Enable biometric authentication?"; on
  ///   Enable, runs the fingerprint setup so biometrics can be used.
  /// - Already enabled -> authenticates with biometrics and logs in.
  Future<void> _onBiometricButtonPressed() async {
    if (_isLoading) return;

    if (!_canCheckBiometrics || !_isBiometricAvailable) {
      showMessage("Biometric authentication is not available on this device");
      return;
    }

    if (!_isBiometricEnabled) {
      // First time: enable the biometric login using the credentials
      // saved by the last successful password login.
      final String? userIdStr = await _secureStorage.read(
        key: BiometricFunctions.userIdStorageKey,
      );
      final String? token = await _secureStorage.read(
        key: BiometricFunctions.tokenStorageKey,
      );

      final int? userId = int.tryParse(userIdStr ?? '');

      if (userId == null || token == null || token.isEmpty) {
        showMessage(
          "Login with your username and password once first, "
          "then enable biometric login.",
        );
        return;
      }

      await _biometricFunctions.enableBiometricFromLogin(
        context: context,
        userId: userId,
        token: token,
      );

      // Refresh the button state after the setup attempt.
      if (mounted) _checkBiometricsAvailability();
      return;
    }

    await _authenticateWithBiometrics();
  }

  Future<void> _authenticateWithBiometrics() async{
    if(_isLoading) return;

    if(!_canCheckBiometrics || !_isBiometricAvailable) {
      showMessage("Biometric authentication is not available on this device");
      return;
    }
    try{
      setState(() => _isLoading = true);

      final bool authenticated = await _localAuth.authenticate(
        localizedReason: "Please authenticate to log in",
        biometricOnly: true ,
        );
        if(authenticated){
          print("Biometric authentication success");

          final SharedPreferences prefs = 
          await SharedPreferences.getInstance();

          final String? savedUsername =  prefs.getString(KConstants.loggedInUsernameKey);

          if(savedUsername == null  || savedUsername.isEmpty){
            showMessage(" No saved account found. Please login with your username and password first");
            return;
          }
          KConstants.loggedInUsername = savedUsername ;

          if(!mounted)return;

          Navigator.pushAndRemoveUntil(context,
           MaterialPageRoute(builder:
            (context) => HomePage(),
            ),
            (route) => false,
            );
        }else{
          showMessage("Biometric authentication failed or cancelled");
        }
    }catch(e){
      print("BIOMETRIC ERROR: $e");
      showMessage("BIOMETRIC AUTHENTICATION ERROR: $e");
    }finally{
      if(mounted){
        setState(() => _isLoading = false,);
      }
    }
  }

  /// On/off switch for biometric authentication, opened from the toggle
  /// icon beside the "Login with Biometrics" button.
  /// The dialog + on/off logic live in biometric_enabler.dart; this only
  /// hands over the current state and applies the returned new state.
  Future<void> _showBiometricOnOffDialog() async {
    final bool? newState = await _biometricEnabler.toggleBiometric(
      context: context,
      isBiometricEnabled: _isBiometricEnabled,
      isDeviceCapable: _canCheckBiometrics && _isBiometricAvailable,
    );

    // null = dialog closed / cancelled; true|false = the new state.
    if (newState != null && mounted) {
      setState(() => _isBiometricEnabled = newState);
    }
  }
  
  

  @override
  void dispose() {
    controllerUser.dispose();
    controllerPW.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    double widthScreen = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child:LayoutBuilder(
              builder: (context,BoxConstraints constraints) {
              return FractionallySizedBox(
              widthFactor:widthScreen > 500 ? 0.5 : 1.0 ,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Lottie.asset(
                    'lib/assets/lotties/login.json',
                    height: 400.0,
                  ),
                  Text('Username:',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                  ),
                  SizedBox(height: 5.0),
                    TextField(
                    controller: controllerUser,
                    decoration: InputDecoration(
                      hintText: 'Username',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                  ),
                  onEditingComplete: () {
                    setState((){});
                  },
                  ),
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
                      hintText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => isPassword = !isPassword),
                         icon: Icon(
                          isPassword  ? Icons.visibility : Icons.visibility_off,
                         ),),
                  ),
                  ),

                 SizedBox(height: 20.0),

                 FilledButton(
                    onPressed: _isLoading ? null : () {
                      onLoginPressed();
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
                   if(_canCheckBiometrics && _isBiometricAvailable)
                   Padding(padding: const EdgeInsets.only(top: 10.0),
                   child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading 
                          ? null 
                          : _onBiometricButtonPressed,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                           ),
                           child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.fingerprint),
                              const SizedBox(width: 8,),
                              Expanded(child: Text(
                                _isBiometricEnabled 
                                ? "Login with biometrics"
                                : "Login with biometrics(Enable)",
                                overflow: TextOverflow.ellipsis,
                              ),),
                             const SizedBox(width: 8,),
                             GestureDetector(
                              onTap: _isLoading 
                              ? null
                              : _showBiometricOnOffDialog,
                              child: Icon(
                                _isBiometricEnabled
                                ? Icons.toggle_on
                                : Icons.toggle_off,
                                size: 34,
                                color: _isBiometricEnabled
                                ?Colors.teal
                                :Colors.grey,
                              ),
                             )
                            ],
                           ),
                        )
                      )
                    ],
                   ),
                   ),
                   Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account yet?",style: TextStyle(color: Colors.grey),),
                        TextButton(onPressed: () {
                          Navigator.push(context,
                           MaterialPageRoute(builder:
                            (context) => SignUpPage(title: 'SIGN UP'),),);
                        }, child: Text("SIGN UP HERE"),),
                      ],
                    ),
                   ),
                   SizedBox(height:50.0,),
                ],
              ),
            );
            },
            ) ,
          ),
        ),
      ),
    );
  }
  Future<void> onLoginPressed() async {
    if (_isLoading) return;
    if (controllerUser.text.trim().isEmpty || controllerPW.text.isEmpty) {
      showMessage('Please enter your username and password.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(KConstants.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': controllerUser.text.trim(),
          'password': controllerPW.text,
        }),
      ).timeout(const Duration(seconds: 10));
      print('STATUS CODE: ${response.statusCode}');
      print('RESPONSE BODY: ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        // Remember the logged in user for the profile page.
        KConstants.loggedInUsername = controllerUser.text.trim();
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          KConstants.loggedInUsernameKey,
          controllerUser.text.trim(),
        );

        // Remember the account for the biometric enable flow
        // ("Login with Biometrics" asks to enable on the next visit).
        final int? userId = int.tryParse(data['user_id']?.toString() ?? '');
        final String? token = data['token']?.toString();
        if (userId != null && token != null && token.isNotEmpty) {
          await _secureStorage.write(
            key: BiometricFunctions.userIdStorageKey,
            value: userId.toString(),
          );
          await _secureStorage.write(
            key: BiometricFunctions.tokenStorageKey,
            value: token,
          );
        }

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(
          builder: (context) {
          return HomePage();
            },
         ),
         (route) => false,
        );
      } else {
        showMessage(data['message']?.toString() ?? 'Login failed');
      }
    } catch (e) {
      print('LOGIN ERROR:$e');
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
}
