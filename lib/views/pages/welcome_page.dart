import 'package:app/databases/style.dart';
import 'package:app/views/pages/starting_page.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset("lib/assets/lotties/animation.json", height: 400,),
              Text(
                "This is an app that I created to see what have I learned during my Intern's days.",
                style: KtextStyle.descriptionText,
                textAlign: TextAlign.justify,
                ),
                SizedBox(height: 100,),
                FilledButton(onPressed:() {
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return StartingPage();
                  }
                  )
                  );
                },style: FilledButton.styleFrom(
                  minimumSize: Size(double.infinity, 40.0),
                ),
                 child: Text("GET STARTED", style: TextStyle(letterSpacing: 5, fontWeight: FontWeight.bold),),
                 ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}