
import 'package:app/views/widget/hero_widget.dart';
import 'package:app/views/widget/list_tile_widget.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/databases/constants.dart';
import 'package:app/databases/notifiers.dart';



class HomePage extends StatelessWidget {
  
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Home Page"),
        actions: [
          IconButton(onPressed: ()async {
            isDarkModeNotifier.value = !isDarkModeNotifier.value ; 
            final SharedPreferences prefs = 
            await SharedPreferences.getInstance();
            await prefs.setBool(
              KConstants.themeModeKey,
              isDarkModeNotifier.value
              );
          },
          icon: ValueListenableBuilder(
          valueListenable: isDarkModeNotifier,
          builder: (context, isDarkMode, child) {
            return Icon(
              isDarkMode ? Icons.dark_mode
                         : Icons.light_mode,
            );
          } ,))
        ],
      ),
      body:Padding(
        padding: const EdgeInsets.symmetric(horizontal:10.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 10.0,),
              HeroWidget(title: "XERAPHIM"),
              SizedBox(height: 5.0,),
              ListTileWidget(),
            ],
            
          ),
        
        ),
      ),
    );
  }
}