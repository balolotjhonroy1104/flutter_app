import 'package:app/views/pages/login_page.dart';
import 'package:app/views/pages/sign_up_page.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class StartingPage extends StatelessWidget {
  const StartingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset("lib/assets/lotties/hi.json",height: 400.0,),
              SizedBox(height: 150.0,),
              FilledButton(onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder:(context) {
                  return SignUpPage(
                    title: 'SIGN UP',
                  );
                },
                ),
                );
              },style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 40.0),
              ),
               child: Text(
                "SIGN UP",
                style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.bold,
                 ),
                ),
               ),
               const SizedBox(height: 5,),
               TextButton(onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) {
                   return LoginPage(
                    title: 'LOGIN',
                   );
                 },
                 ),
                 );
               }, style: FilledButton.styleFrom(
                minimumSize: Size(double.infinity, 40.0),
               ),
               child: Text(
                "LOGIN HERE", style: TextStyle(
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold
                  ),
                  ),
                  ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}