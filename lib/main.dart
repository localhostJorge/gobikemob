import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const GoBikeApp());
}

class GoBikeApp extends StatelessWidget {
  const GoBikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Go Bike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
    );
  }
}