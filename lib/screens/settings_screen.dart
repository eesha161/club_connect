// This screen lets you change your app preferences or log out.
import 'package:club_connect/auth_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:club_connect/models/user_profile.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:club_connect/main.dart'; // Import for themeNotifier


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _notificationsEnabled = true; // Placeholder for now, would link to permission check
  bool _rememberMe = false;
  UserProfile? _userProfile; // NEW

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Fetch Profile
    final user = FirebaseAuth.instance.currentUser;
    UserProfile? profile;
    if (user != null) {
      profile = await UserService().getProfile(user.uid);
    }

    if (mounted) {
      setState(() {
        _isDarkMode = themeNotifier.value == ThemeMode.dark;
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _rememberMe = prefs.getBool('remember_me') ?? false;
        _userProfile = profile;
      });
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = value;
      themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    });
    await prefs.setBool('is_dark_mode', value);
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _notificationsEnabled = value);
    await prefs.setBool('notifications_enabled', value);
    // In real app: Call PermissionHandler or NotificationService to actually enable/disable system perms
  }

  Future<void> _toggleRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _rememberMe = value);
    await prefs.setBool('remember_me', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // VOLUNTEER STANDING SECTION
            if (_userProfile != null) ...[
              _buildSectionHeader('Volunteer Status'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _userProfile!.activeStrikes >= 3 ? Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _userProfile!.activeStrikes >= 3 ? Colors.red : Colors.green),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                            Icon(
                              _userProfile!.activeStrikes >= 3 ? Icons.block : Icons.volunteer_activism, 
                              color: _userProfile!.activeStrikes >= 3 ? Colors.red : Colors.green
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Volunteer Standing',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _userProfile!.activeStrikes >= 3 ? Colors.red[900] : Colors.green[900],
                                    ),
                                  ),
                                  Text(
                                    _userProfile!.activeStrikes >= 3 ? "SUSPENDED (3+ Strikes)" : "GOOD (${_userProfile!.activeStrikes} / 3 Strikes)",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _userProfile!.activeStrikes >= 3 ? Colors.red[700] : Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // VISUAL INDICATORS (1 2 3)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(3, (index) {
                          final strikeNumber = index + 1;
                          final isStrike = _userProfile!.activeStrikes >= strikeNumber;
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isStrike ? Colors.red : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isStrike ? Colors.red[900]! : Colors.grey[400]!),
                              ),
                              child: Center(
                                child: Text(
                                  '$strikeNumber',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isStrike ? Colors.white : Colors.grey[500],
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
            ],

            _buildSectionHeader('Appearance'),
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Enable darker aesthetic'),
              value: _isDarkMode,
              onChanged: _toggleDarkMode,
              secondary: const Icon(Icons.dark_mode),
            ),
            const Divider(),

            _buildSectionHeader('Notifications'),
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive updates from joined clubs'),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              secondary: const Icon(Icons.notifications),
            ),
             const Divider(),

            _buildSectionHeader('Account'),
            SwitchListTile(
              title: const Text('Remember Me'),
              subtitle: const Text('Keep me logged in on this device'),
              value: _rememberMe,
              onChanged: _toggleRememberMe,
              secondary: const Icon(Icons.lock_clock),
            ),
             const Divider(),
            
            _buildSectionHeader('About'),
             ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Version'),
              subtitle: const Text('1.0.0 (Alpha)'),
            ),

            // --- DEVELOPER OPTIONS (Hidden/Bottom) ---
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }



  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
