import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JARVIS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color.fromRGBO(8, 2, 12, 1),
        colorScheme: const ColorScheme.dark(
          primary: Color.fromRGBO(255, 140, 30, 1),
          secondary: Color.fromRGBO(255, 200, 100, 1),
          surface: Color.fromRGBO(8, 2, 12, 1),
        ),
        textTheme: const TextTheme(
          bodySmall: TextStyle(
            fontFamily: 'Courier',
            color: Color.fromRGBO(255, 170, 50, 1),
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Courier',
            color: Color.fromRGBO(255, 170, 50, 1),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
