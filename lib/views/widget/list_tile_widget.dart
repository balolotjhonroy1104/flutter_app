import 'package:app/views/pages/profile_page.dart';
import 'package:app/views/pages/time_page.dart';
import 'package:app/views/pages/welcome_page.dart';
import 'package:flutter/material.dart';

class ListTileWidget extends StatelessWidget {
  const ListTileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 25),
        child: SizedBox(
          child: Column(
            children: [
              SizedBox(
              width: double.infinity,
              height: 60,
              child: ListTile(
                tileColor: Colors.teal[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                leading:const Icon(Icons.person , size: 25,),
                title:const Text("PROFILE",  style: TextStyle(fontSize:23,color: Colors.tealAccent),
                ),
                onTap:() {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const ProfilePage(),
                    ),);
                }
              ),
            ), 
            SizedBox(height: 15,),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ListTile(
                tileColor: Colors.teal[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                leading:const Icon(Icons.schedule,size: 25,),
                title: const Text("ATTENDANCE", style: TextStyle(fontSize: 23,  color: Colors.tealAccent),
                ),
                onTap: () {
                  Navigator.push(
                    context, MaterialPageRoute(
                      builder: (context) => TimePage(),));
                },
              ),
            ),
            SizedBox(height: 15,),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ListTile(
                tileColor: Colors.teal[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                leading:const Icon(Icons.logout_rounded,size: 25,),
                title: const Text("LOGOUT", style: TextStyle(fontSize: 23, color: Colors.tealAccent),
                ),
                onTap: () {
                  Navigator.pushReplacement(
                    context, MaterialPageRoute(
                      builder: (context) => WelcomePage(),));
                },
              ),
            ),
            ],
          ),
        ),
    );
  }
}