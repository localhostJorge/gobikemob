import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'create_account_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background with Gradient and Logo
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFD3D3D3)], // Matching your previous grey gradient
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  Image.asset(
                    'assets/images/logo.png',
                    width: 220,
                  ),
                ],
              ),
            ),
          ),
          
          // 2. The Floating Bottom Card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Makes the card only as tall as its contents
                children: [
                  const Text(
                    'Saving lives one ride at a time!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  
                  // Get Started Button -> Routes to Login
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A63C2), // Go Bike Blue
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15), // Rounded corners
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Sign Up Button -> Routes to Create Account
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateAccountScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      side: const BorderSide(color: Color(0xFF3A63C2), width: 1.5), // Blue border
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    // RichText allows us to make "New Here?" grey and "Sign Up" blue
                    child: RichText(
                      text: const TextSpan(
                        text: 'New Here ? ',
                        style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w500),
                        children: [
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(color: Color(0xFF3A63C2), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10), // Extra padding at the very bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}