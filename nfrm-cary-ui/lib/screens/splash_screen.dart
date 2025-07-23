import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        // Navigate to the AuthenticationWrapper to decide the next screen
        Navigator.pushReplacementNamed(context, '/auth_wrapper');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Using a Stack to layer the background image and the text content.
      body: Stack(
        fit: StackFit.expand, // Makes the Stack's children fill the Scaffold's body.
        children: <Widget>[
          // Background Image
          Image.asset(
            'assets/images/Welcome.jpeg',
            fit: BoxFit.cover, // Covers the entire screen. May crop image to fit.
                               // Alternatives: BoxFit.contain (shows whole image, may letterbox)
                               // or BoxFit.fill (stretches, may distort aspect ratio).
          ),
          // Centered Content (Text)
          // The Center widget and its children (Column, Text, SizedBox) have been removed.
        ],
      ),
    );
  }
}
