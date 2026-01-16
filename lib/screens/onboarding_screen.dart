import 'package:flutter/material.dart';
import 'package:club_connect/screens/home_screen.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _completeOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    
    // Reset Tutorial flag to ensure they see the coach marks after this
    await prefs.setBool('tutorial_seen', false); 
    
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Premium Design Elements
    final titleStyle = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.onSurface,
      letterSpacing: -0.5,
    );
    
    final bodyStyle = TextStyle(
      fontSize: 16,
      color: Colors.grey[700],
      height: 1.5,
    );

    PageDecoration pageDecoration = PageDecoration(
      titleTextStyle: titleStyle,
      bodyTextStyle: bodyStyle,
      imagePadding: const EdgeInsets.all(24),
      contentMargin: const EdgeInsets.symmetric(horizontal: 16),
      pageColor: Colors.transparent, // Background handled by parent
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
            stops: const [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          child: IntroductionScreen(
            globalBackgroundColor: Colors.transparent, // Allow gradient to show
            allowImplicitScrolling: true,
            // Custom Pages
            pages: [
              // Slide 1: Connect
              PageViewModel(
                title: "Connect & Collaborate",
                bodyWidget: _buildBodyText(
                  context, 
                  "Join a professional network of peers. Discover organizations that align with your academic and career goals."
                ), // Custom body for better readability
                image: _buildImage('assets/club_presets/social.jpg'), // Hannah Busing - Person in Red Sweater Holding Hands
                decoration: pageDecoration,
              ),
              // Slide 2: Events
              PageViewModel(
                title: "Stay Organized",
                bodyWidget: _buildBodyText(
                  context,
                  "Centralize your extracurricular schedule. manage RSVPs, track attendance, and access event details efficiently."
                ),
                image: _buildImage('assets/club_presets/academic.jpg'), // Andrey Novik - Person Writing on White Paper
                decoration: pageDecoration,
              ),
              // Slide 3: Lead
              PageViewModel(
                title: "Develop Leadership",
                bodyWidget: _buildBodyText(
                  context,
                  "Track your community impact. Earn recognition for your contributions and manage organization operations seamlessly."
                ),
                image: _buildImage('assets/club_presets/leadership.jpg'), // Charles Forerunner - People Standing inside City Building
                decoration: pageDecoration,
              ),
            ],
            
            // Logic
            onDone: () => _completeOnboarding(context),
            onSkip: () => _completeOnboarding(context),
            showSkipButton: true,
            
            // Controls UI
            skip: const Text("Skip", style: TextStyle(fontWeight: FontWeight.w600)),
            next: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward, color: Theme.of(context).primaryColor),
            ),
            done: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // Reduced vertical padding for 2 lines
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                "Get Started",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            
            // Dots UI
            dotsDecorator: DotsDecorator(
              size: const Size.square(10.0),
              activeSize: const Size(22.0, 10.0),
              activeColor: Theme.of(context).primaryColor,
              color: Colors.grey[400]!, // Darker inactive dots for visibility on gradient
              spacing: const EdgeInsets.symmetric(horizontal: 3.0),
              activeShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.0),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyText(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95), // Nearly opaque for readability
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1), // Stronger border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: Colors.black87, // High contrast text
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  Widget _buildImage(String path) {
    final isNetwork = path.startsWith('http');
    return Container(
      margin: const EdgeInsets.only(top: 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: isNetwork
            ? Image.network(
                path,
                fit: BoxFit.cover,
                height: 300,
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 300,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 300,
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                ),
              )
            : Image.asset(
                path,
                fit: BoxFit.cover,
                height: 300,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 300,
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                ),
              ),
      ),
    );
  }
}
