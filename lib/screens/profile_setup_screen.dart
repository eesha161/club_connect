import 'package:club_connect/screens/onboarding_screen.dart';
import 'package:club_connect/services/location_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _locationService = LocationService();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Selections
  String? _selectedState;
  String? _selectedEducationLevel;
  
  // Controllers for Autocomplete inputs
  final _cityController = TextEditingController();
  // final _schoolController = TextEditingController(); // REMOVED

  List<String> _states = [];
  final List<String> _educationLevels = LocationService.educationLevels;

  @override
  void initState() {
    super.initState();
    _states = _locationService.getStates();
    // Default to 'California' or similar if we wanted, but let user choose.
  }

  void _onStateChanged(String? newState) {
    if (newState == null) return;
    setState(() {
      _selectedState = newState;
      _cityController.clear(); // Clear city if state changes
    });
  }

  void _onLevelChanged(String? newLevel) {
    if (newLevel == null) return;
    setState(() {
      _selectedEducationLevel = newLevel;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedState == null || _selectedEducationLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select all dropdown fields.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await UserService().updateProfileData(user.uid, {
          'state': _selectedState,
          'city': _cityController.text.trim(),
          'educationLevel': _selectedEducationLevel,
          // 'schoolName': _schoolController.text.trim(), // REMOVED
          'profileSetupCompleted': true,
        });

        if (mounted) {
           Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Icon(Icons.school_rounded, size: 60, color: Theme.of(context).primaryColor),
                const SizedBox(height: 24),
                Text(
                  'Let\'s get you set up',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We use these details to find the best student organizations and events near you.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),

                // STATE DROPDOWN
                _buildLabel('State'),
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration('Select State', Icons.map),
                  value: _selectedState,
                  items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: _onStateChanged,
                ),
                
                const SizedBox(height: 24),

               // CITY AUTOCOMPLETE
                _buildLabel('City'),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (_selectedState == null) return const Iterable<String>.empty();
                    if (textEditingValue.text == '') {
                      // Return common cities for the state
                      return _locationService.getCities(_selectedState!);
                    }
                    return _locationService.getCities(_selectedState!)
                        .where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    _cityController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                     // Sync internal controller with this one if needed, but we can just use this ONE
                     // Actually, we need to extract the value. 
                     // Let's use a listener or just assign the controller passed here to our class var?
                     // No, fieldViewBuilder gives us a controller. We should use IT or sync.
                     // Easier: pass OUR controller to the specific implementation or copy text.
                     // The snippet below manually handles sync.
                     controller.addListener(() {
                       _cityController.text = controller.text;
                     });
                     
                     // Pre-fill if we have a value (e.g. revisiting page) - skipped for now
                     return TextFormField(
                       controller: controller,
                       focusNode: focusNode,
                       onEditingComplete: onEditingComplete,
                       decoration: _inputDecoration('Enter your city', Icons.location_city),
                       validator: (val) => val == null || val.isEmpty ? 'Please enter a city' : null,
                     );
                  },
                ),
                
                const SizedBox(height: 24),

                // EDUCATION LEVEL
                _buildLabel('Current Education'),
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration('Select Level', Icons.school_outlined),
                  value: _selectedEducationLevel,
                  items: _educationLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: _onLevelChanged,
                ),
                
                const SizedBox(height: 24),

                // BUTTON
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Get Started',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
          fontSize: 14,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey[400]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}
