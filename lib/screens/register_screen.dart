import 'package:club_connect/models/user_profile.dart'; // Import UserProfile
import 'package:club_connect/widgets/loading_overlay.dart';
import 'package:club_connect/screens/onboarding_screen.dart'; // Import OnboardingScreen
import 'package:club_connect/screens/profile_setup_screen.dart'; // NEW
// This screen lets new users create an account.
import 'package:club_connect/auth_wrapper.dart';
import 'package:club_connect/services/auth_service.dart';
import 'package:club_connect/services/user_service.dart'; // Import UserService
import 'package:club_connect/services/inbox_service.dart'; // NEW
import 'package:club_connect/models/inbox_message.dart'; // NEW
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers to get text from the user
  final _nameController = TextEditingController(); // NEW: Name Controller
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();
  final _userService = UserService(); // NEW: User Service
  bool _isLoading = false;
  bool _obscurePassword = true; // NEW
  bool _obscureConfirmPassword = true; // NEW

  void _register() async {
    // 1. Validate inputs
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Create Auth User (Email/Password)
      User? user = await _authService.registerWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
      );

      if (user != null) {
        // 3. Create Firestore Profile
        final newProfile = UserProfile(
          uid: user.uid,
          email: user.email ?? '',
          displayName: _nameController.text.trim(),
          photoUrl: '', // No photo yet
          joinedClubIds: [], // Starts with 0 clubs
          role: 'member',
        );

        // Save it to Firestore
        try {
          await _userService.createOrUpdateProfile(newProfile).timeout(const Duration(seconds: 5));
        } catch (e) {
          // Proceed anyway so user isn't stuck
        }

        // Send Welcome Inbox Message
        try {
          final welcomeMsg = InboxMessage(
            id: '', // Service generates ID
            title: 'Welcome to ClubConnect!',
            body: 'Welcome to the Student Organization Hub!\n\nSome things to know for first time users:\n'
                  '• Explore clubs and events in the "Discover" tab.\n'
                  '• Join clubs to get updates and track your involvement.\n'
                  '• Check in to events to earn badges and track volunteer hours.\n'
                  '• Use the "Dashboard" to see your impact and history.',
            timestamp: DateTime.now(),
            type: 'system',
            relatedId: 'onboarding',
          );
          await InboxService().addMessage(user.uid, welcomeMsg);
        } catch (msgError) {
        }

        // Send welcome email (async, don't wait for it)
        if (mounted) {
          // 4. Navigate to Onboarding
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
            (route) => false,
          );
        }
      } else {
      }
    } on FirebaseAuthException catch (e) {
      // Handle Firebase specific errors (e.g., email already in use)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Registration failed')),
        );
      }
    } catch (e) {
      // Handle other errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    // Clean up controllers when the screen is destroyed
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Create Account')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                // Removed MainAxisAlignment.center to align to top
                children: [
                  // NEW: Name Field
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _register,
                      child: const Text('Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
         if (_isLoading)
          const LoadingOverlay(message: 'Creating Account...'),
      ],
    );
  }
}
