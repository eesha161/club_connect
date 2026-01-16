import 'package:club_connect/firebase_options.dart';
import 'package:club_connect/screens/login_screen.dart';
import 'package:club_connect/screens/onboarding_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// This is the main entry point of the app. It sets up the theme and routing.
import 'package:club_connect/auth_wrapper.dart';
import 'package:club_connect/screens/splash_screen.dart'; // Import SplashScreen
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:shared_preferences/shared_preferences.dart';
import 'package:club_connect/services/notification_service.dart'; // NEW

// Global Theme Notifier for easy access across the app
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await NotificationService().init(); // Initialize Local Notifications
    }
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
       runApp(MaterialApp(home: Scaffold(body: Center(child: Text('Initialization Error: $e')))));
       return;
    }
  }

  try {
    // Session Management & Theme Persistence
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Check Remember Me
    final rememberMe = prefs.getBool('remember_me') ?? false;
    if (!rememberMe) {
      await FirebaseAuth.instance.signOut();
    }

    // 2. Load Theme
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

    runApp(const ClubConnectApp());
  } catch (e, stack) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text('Startup Error: $e')))));
  }
}

class ClubConnectApp extends StatefulWidget {
  const ClubConnectApp({super.key});

  @override
  State<ClubConnectApp> createState() => _ClubConnectAppState();
}

class _ClubConnectAppState extends State<ClubConnectApp> {
  // Use a state variable to track if splash has been shown.
  // This persists across Theme changes.
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    // --- LIGHT THEME COLORS ---
    const green1 = Color(0xFF395934); // Darkest
    const green2 = Color(0xFF5C844B); 
    const green3 = Color(0xFF5C9254); 
    const green4 = Color(0xFF8AC472); 
    const green5 = Color(0xFFA7C6A2); 
    const green6 = Color(0xFFC6D8C3); 
    const surfaceGreen = Color(0xFFF1F8F0); // Very light

    // --- DARK THEME COLORS ---
    const darkBg = Color(0xFF101A10); 
    const darkSurface = Color(0xFF1A261A);
    const darkPrimary = Color(0xFF8AC472); 
    const darkSecondary = Color(0xFFA7C6A2); 
    const darkText = Color(0xFFE8F5E9); 

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'ClubConnect',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          
            // === LIGHT THEME ===
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: green1,
                primary: green1,
                secondary: green3,
                tertiary: green4,
                surface: Colors.white,
                outline: green6,
                error: Colors.redAccent,
              ),
              scaffoldBackgroundColor: surfaceGreen,
              textTheme: TextTheme(
                // Headers - Playfair Display (classy, professional)
                displayLarge: GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.bold, color: green1),
                displayMedium: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold, color: green1),
                displaySmall: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: green1),
                headlineLarge: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: green1),
                headlineMedium: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600, color: green1),
                headlineSmall: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w600, color: green2),
                titleLarge: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                titleMedium: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                titleSmall: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                // Body Text - Poppins (readable)
                bodyLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.black87, height: 1.5),
                bodyMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black87, height: 1.5),
                bodySmall: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.black54, height: 1.4),
                labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                labelMedium: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                labelSmall: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.black54),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: green1,
                foregroundColor: Colors.white,
                centerTitle: true,
                elevation: 0,
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: green5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: green5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: green1, width: 2),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: green1,
                  foregroundColor: Colors.white, // Text color
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: green1,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: green1),
                ),
              ),
              // dialogTheme: DialogTheme(
              //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              // ),
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: green1,
                contentTextStyle: const TextStyle(color: Colors.white),
              ),
            ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.dark(
              primary: darkPrimary,
              onPrimary: darkBg, 
              secondary: darkSecondary,
              surface: darkSurface,
              onSurface: darkText,
              outline: green4,
            ),
            scaffoldBackgroundColor: darkBg,
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
              bodyColor: darkText,
              displayColor: darkText,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: darkSurface,
              foregroundColor: darkPrimary,
              elevation: 0,
              centerTitle: true,
            ),
            cardTheme: const CardThemeData(
              color: darkSurface,
              elevation: 4,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: darkPrimary,
                foregroundColor: darkBg,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
               style: OutlinedButton.styleFrom(
                 foregroundColor: darkPrimary,
                 side: const BorderSide(color: darkPrimary),
               )
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF253325),
              labelStyle: const TextStyle(color: darkSecondary),
              hintStyle: TextStyle(color: darkSecondary.withValues(alpha: 0.5)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: green4)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: green5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: darkPrimary, width: 2)),
            ), 
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: darkSurface, selectedItemColor: darkPrimary, unselectedItemColor: Colors.grey),
          ),
          // home: const SplashScreen(),
          home: _showSplash 
            ? SplashScreen(onFinish: () => setState(() => _showSplash = false))
            : const AuthWrapper(),
        );
      },
    );
  }
}
