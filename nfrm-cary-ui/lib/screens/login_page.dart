import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    final authService = Provider.of<AuthService>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    final user = await authService.signInWithGoogle();
    
    if (user != null) {
      userProvider.setUser(user);
      // Navigation to MainAppScreen is handled by AuthenticationWrapper
    } else {
      // Handle sign-in failure (e.g., show a snackbar)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sign-In failed. Please try again.')),
        );
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Placeholder for your logo/image
              Image.asset(
                'assets/images/logo-mascot.png', // Add your logo to assets folder and pubspec.yaml
                height: 150,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 150),
              ),
              const SizedBox(height: 10), // Adjusted spacing
              const Text(
                'WELCOME TO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Image.asset(
                'assets/images/logo.png', // Assuming this is the path to your second logo
                height: 100, // You can adjust the height as needed
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 100),
              ),
              const SizedBox(height: 20), // Spacing after the logo.png
              const Text(
                'Unlock Ancient Wisdom with Modern AI – Experience Like Never Before.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cabin', // Make sure Cabin font is added to pubspec.yaml
                  fontWeight: FontWeight.w400, // Normal weight
                  fontSize: 16.0,
                  height: 1.2, // Line height as a multiplier of font size (120%)
                  letterSpacing: 2.0, // 10% of 20px = 2.0 logical pixels
                  color: Colors.black54, // Keeping the previous color, adjust if needed
                ),
              ),
              // const SizedBox(height: 30), // Original spacing - adjust as needed if you want to keep some space
              const SizedBox(height: 50),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: Image.asset('assets/images/google_logo.jpeg', height: 24.0), // Add a Google logo to assets
                      label: const Text('Sign in with Google'),
                      onPressed: _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Match scaffold background
                        foregroundColor: Theme.of(context).colorScheme.onSurface, // Ensure text is visible
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        textStyle: const TextStyle(fontSize: 16),
                        // The button will still have its default elevation (shadow),
                        // which helps distinguish it from the background.
                        // If you want a flatter look, you could add: elevation: 0,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
