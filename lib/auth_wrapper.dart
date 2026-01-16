import 'package:club_connect/models/user_profile.dart';

import 'package:club_connect/screens/home_screen.dart';
import 'package:club_connect/screens/login_screen.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:club_connect/services/report_service.dart'; // NEW
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added import for SharedPreferences

class AuthWrapper extends StatefulWidget { // Changed to StatefulWidget
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState(); // Added createState
}

class _AuthWrapperState extends State<AuthWrapper> { // Added State class
  bool _showOnboarding = false; // Added state variable

  @override
  void initState() {
    super.initState();
    _checkOnboarding(); // Call checkOnboarding on init
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    
    // --- DEBUG RESET ---
    // Uncomment these to force reset onboarding for testing
    // await prefs.setBool('onboarding_complete', false);
    // await prefs.setBool('tutorial_seen', false);
    // -------------------

    final complete = prefs.getBool('onboarding_complete') ?? false;

    if (mounted) {
      if (complete) {
        setState(() => _showOnboarding = false);
      } else {
        setState(() => _showOnboarding = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Auth State Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // 2. User is NOT Logged In
        if (!snapshot.hasData) {
          // Ensure we don't accidentally show splash here if logic elsewhere is wrong
          return const LoginScreen();
        }

        // 3. User IS Logged In -> Fetch Profile to check Role
        final User user = snapshot.data!;
        
        // Use StreamBuilder for real-time profile updates and better caching resilience
        return StreamBuilder<UserProfile?>(
          stream: UserService().getProfileStream(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
               return const Scaffold(
                 body: Center(child: CircularProgressIndicator()),
               );
            }
            
            if (profileSnapshot.hasError) {
               return Scaffold(body: Center(child: Text("Profile Error: ${profileSnapshot.error}")));
            }

            final userProfile = profileSnapshot.data;
            
            // If profile doesn't exist (rare edge case), default to Student Home
            if (userProfile == null) {
               return const HomeScreen(); 
            }

            // AUTO-REPORT CHECK REMOVED
            // WidgetsBinding.instance.addPostFrameCallback((_) {
            //    ReportService().checkAndSendWeeklyReport(user.uid);
            // });

            // 4. Unified Navigation
            return HomeScreen(launchProfile: false);
          },
        );
      },
    );
  }
}
