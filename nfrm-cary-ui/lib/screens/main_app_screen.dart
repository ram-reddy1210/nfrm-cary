import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../home_page.dart'; // Import HomePage

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  @override
  void initState() {
    super.initState();
    // Previous redirection logic has been removed.
    // MainAppScreen now acts as a persistent scaffold.
  }

  @override
  void dispose() {
    super.dispose();
    // Dispose of any controllers or listeners if they were added.
  }

  @override
  Widget build(BuildContext context) {
    // final userProvider = Provider.of<UserProvider>(context); // Available if needed for UI (e.g., AppBar title)
    // final authService = Provider.of<AuthService>(context, listen: false); // No longer needed here if AppBar is removed

    return Scaffold(
      body: const HomePage(), // HomePage is rendered as the main content
    );
  }
}
