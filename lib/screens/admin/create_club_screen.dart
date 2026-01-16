import 'dart:math';

// This screen is for admins to create a brand new club.
import 'package:club_connect/models/club.dart';
import 'package:club_connect/models/club_form.dart';
import 'package:club_connect/models/question.dart';
import 'package:club_connect/services/club_service.dart';
import 'package:club_connect/services/location_service.dart'; // NEW
import 'package:club_connect/services/user_service.dart';
import 'package:club_connect/widgets/club_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _joinCodeController = TextEditingController(); // Private Club Code
  final _customTagController = TextEditingController(); // Custom Tag Input
  
  // Location & School State (NEW)
  final _locationService = LocationService();
  String? _selectedState;
  String? _selectedCity;
  String? _selectedEducationLevel;
  // String? _selectedSchool; // REMOVED

  List<String> _states = [];
  List<String> _cities = [];
  // List<String> _schools = []; // REMOVED
  final List<String> _educationLevels = LocationService.educationLevels;

  // State
  String? _selectedImageUrl;
  List<String> _tags = [];
  bool _isPrivate = false;
  bool _isLoading = false;

  // Presets
  final List<String> _presetTags = [
    'Academic', 'Sports', 'Technology', 'Arts', 'Music', 
    'Social', 'Volunteering', 'Leadership', 'Gaming', 
    'Health', 'Debate', 'Cultural', 'Business', 
    'Environment', 'Religious'
  ];

  final List<String> _presetImages = [
    'assets/club_presets/academic.jpg', // Academic - Andrey Novik
    'assets/club_presets/social.jpg', // Social - Hannah Busing
    'assets/club_presets/tech.jpg', // Tech - Luca Bravo
    'assets/club_presets/art.jpg', // Art - Paul Blenkhorn
    'assets/club_presets/music.jpg', // Music - Wes Hicks
    'assets/club_presets/leadership.jpg', // Leadership - Charles Forerunner
    'assets/club_presets/nature.jpg', // Nature - Matthew Smith
    'assets/club_presets/business.jpg', // Business - Ivan Aleksic
  ];

  
  // Form Building State
  bool _enableJoinForm = false;
  List<Question> _joinQuestions = [];
  
  bool _enableLeaveForm = false;
  List<Question> _leaveQuestions = [];
  
  // Service
  final _clubService = ClubService();

  @override
  void initState() {
    super.initState();
    _states = _locationService.getStates();
    _loadUserProfile();
  }

  // Pre-fill location from User Profile
  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await UserService().getProfile(user.uid);
      if (profile != null && mounted) {
        setState(() {
          if (profile.state != null && _states.contains(profile.state)) {
            _selectedState = profile.state;
            _cities = _locationService.getCities(_selectedState!);
          }
          if (profile.city != null && _cities.contains(profile.city)) {
            _selectedCity = profile.city;
          }
          if (profile.educationLevel != null && _educationLevels.contains(profile.educationLevel)) {
            _selectedEducationLevel = profile.educationLevel;
          }
        });
      }
    }
  }

  // Location Handlers
  void _onStateChanged(String? newState) {
    if (newState == null) return;
    setState(() {
      _selectedState = newState;
      _selectedCity = null;
      _cities = _locationService.getCities(newState);
    });
  }

  void _onCityChanged(String? newCity) {
    if (newCity == null) return;
    setState(() {
      _selectedCity = newCity;
    });
  }

  void _onLevelChanged(String? newLevel) {
    if (newLevel == null) return;
    setState(() {
      _selectedEducationLevel = newLevel;
    });
  }


  // Generators
  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  void _addQuestion(bool isJoinForm) {
    showDialog(
      context: context,
      builder: (context) => _AddQuestionDialog(
        onAdd: (question) {
          setState(() {
            if (isJoinForm) {
              _joinQuestions.add(question);
            } else {
              _leaveQuestions.add(question);
            }
          });
        },
      ),
    );
  }

  void _removeQuestion(bool isJoinForm, int index) {
    setState(() {
      if (isJoinForm) {
        _joinQuestions.removeAt(index);
      } else {
        _leaveQuestions.removeAt(index);
      }
    });
  }

  void _createClub() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final name = _nameController.text.trim();
        // Check availability
        final isAvailable = await _clubService.checkNameAvailability(name);
        if (!isAvailable) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Club name already taken. Please choose another.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
            );
          }
          return;
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        final newClub = Club(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          imageUrl: _selectedImageUrl ?? _presetImages[0],
          memberCount: 0, // Start with 0, let joinClub increment it to 1
          tags: _tags, 
          isPrivate: _isPrivate,
          joinCode: _isPrivate ? _joinCodeController.text.trim() : null,
          joinForm: _enableJoinForm 
              ? ClubForm(isEnabled: true, questions: _joinQuestions)
              : null,
          leaveForm: _enableLeaveForm
              ? ClubForm(isEnabled: true, questions: _leaveQuestions)
              : null,
          adminIds: [user.uid], // Assign creator as admin
          // NEW Location Data
          city: _selectedCity,
          state: _selectedState,
          // schoolName: _selectedSchool, // REMOVED
          educationLevel: _selectedEducationLevel,
        );
        
        await _clubService.createClub(newClub)
             .timeout(const Duration(seconds: 5), onTimeout: () {
             });

        // Creator automatically joins the club
        try {
           await UserService().joinClub(user.uid, newClub.id);
        } catch (joinError) {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Club created, but auto-join failed: $joinError')),
             );
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Club Created Successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _joinCodeController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Club')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Basic Info'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Club Name', prefixIcon: Icon(Icons.group)),
                validator: (val) => val!.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description)),
                validator: (val) => val!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 16),

              // --- LOCATION & SCHOOL (NEW) ---
              _buildSectionHeader('Location & School'),
              // STATE
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                initialValue: _selectedState,
                items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: _onStateChanged,
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              // CITY
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                initialValue: _selectedCity,
                items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: _selectedState == null ? null : _onCityChanged,
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              // LEVEL
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Target Audience (Level)', border: OutlineInputBorder()),
                initialValue: _selectedEducationLevel,
                items: _educationLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: _onLevelChanged,
              ),
              const SizedBox(height: 24),


              // --- IMAGES ---
              _buildSectionHeader('Club Logo'),
              const Text('Select a cover image:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _presetImages.length,
                itemBuilder: (context, index) {
                  final url = _presetImages[index];
                  final isSelected = _selectedImageUrl == url;
                  
                  return GestureDetector(
                    onTap: () {
                       setState(() {
                         _selectedImageUrl = url;
                       });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 3) : Border.all(color: Colors.grey[300]!),
                        image: DecorationImage(
                          image: ClubImage.provider(url),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: isSelected 
                          ? Center(child: Icon(Icons.check_circle, color: Theme.of(context).primaryColor, size: 24))
                          : null,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              if (_selectedImageUrl == null)
                 const Text('Please select an image', style: TextStyle(color: Colors.red, fontSize: 12)),
                 
              const SizedBox(height: 24),

              // --- TAGS ---
              _buildSectionHeader('Tags'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetTags.map((tag) {
                  final isSelected = _tags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (_tags.length < 4) {
                            _tags.add(tag);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Max 4 tags allowed')),
                            );
                          }
                        } else {
                          _tags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text('${_tags.length}/4 selected', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                children: [
                   Expanded(
                     child: TextField(
                       controller: _customTagController,
                       decoration: const InputDecoration(labelText: 'Add Custom Tag (Max 1)', isDense: true, border: OutlineInputBorder()),
                     ),
                   ),
                   const SizedBox(width: 8),
                   IconButton(
                     onPressed: () {
                        final newTag = _customTagController.text.trim();
                        if (newTag.isEmpty) return;
                        if (_tags.contains(newTag)) return;
                        if (_tags.length >= 4) return;
                        
                        setState(() {
                          _tags.add(newTag);
                          _customTagController.clear();
                        });
                     },
                     icon: const Icon(Icons.add_circle, color: Colors.green),
                   ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Privacy Settings'),
              SwitchListTile(
                title: const Text('Private Club'),
                subtitle: const Text('Only users with a code can join.'),
                value: _isPrivate,
                onChanged: (val) {
                  setState(() {
                    _isPrivate = val;
                    if (val && _joinCodeController.text.isEmpty) {
                      _joinCodeController.text = _generateRandomCode();
                    }
                  });
                },
              ),
              if (_isPrivate)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16),
                  child: TextFormField(
                    controller: _joinCodeController,
                    decoration: InputDecoration(
                        labelText: 'Join Code',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                             _joinCodeController.text = _generateRandomCode();
                          },
                        )
                    ),
                    validator: (val) => _isPrivate && (val == null || val.isEmpty) ? 'Required' : null,
                  ),
                ),
                
              const SizedBox(height: 24),
              _buildSectionHeader('Onboarding (Join Questionnaire)'),
              SwitchListTile(
                title: const Text('Enable Join Questionnaire'),
                subtitle: const Text('Ask questions when members join.'),
                value: _enableJoinForm,
                onChanged: (val) => setState(() => _enableJoinForm = val),
              ),
              if (_enableJoinForm) _buildQuestionList(_joinQuestions, true),

              const SizedBox(height: 24),
              _buildSectionHeader('Offboarding (Leave Feedback)'),
              SwitchListTile(
                title: const Text('Enable Leave Feedback'),
                subtitle: const Text('Ask a standard feedback question when members leave.'),
                value: _enableLeaveForm,
                onChanged: (val) => setState(() {
                  _enableLeaveForm = val;
                  if (val) {
                    _leaveQuestions = [
                       Question(
                         id: 'generic_leave_q1', 
                         text: 'Why are you leaving the club?', 
                         type: 'text', 
                         options: []
                       )
                    ];
                  } else {
                    _leaveQuestions = [];
                  }
                }),
              ),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createClub,
                  icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check),
                  label: Text(_isLoading ? 'Creating...' : 'Create Club'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  Widget _buildQuestionList(List<Question> questions, bool isJoinForm) {
    return Column(
      children: [
        ...questions.asMap().entries.map((entry) {
            final index = entry.key;
            final q = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(q.text),
                subtitle: Text('Type: ${q.type}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeQuestion(isJoinForm, index),
                ),
              ),
            );
        }),
        OutlinedButton.icon(
          onPressed: () => _addQuestion(isJoinForm),
          icon: const Icon(Icons.add),
          label: const Text('Add Question'),
        ),
      ],
    );
  }
}

class _AddQuestionDialog extends StatefulWidget {
  final Function(Question) onAdd;
  const _AddQuestionDialog({required this.onAdd});

  @override
  State<_AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<_AddQuestionDialog> {
  final _textController = TextEditingController();
  String _type = 'text'; // 'text' or 'multiple_choice'
  final _optionsController = TextEditingController(); // Comma separated for simplicity

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Question'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(labelText: 'Question Text'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: const [
                DropdownMenuItem(value: 'text', child: Text('Free Response')),
                DropdownMenuItem(value: 'multiple_choice', child: Text('Multiple Choice')),
              ],
              onChanged: (val) => setState(() => _type = val!),
              decoration: const InputDecoration(labelText: 'Question Type'),
            ),
            if (_type == 'multiple_choice')
              TextField(
                controller: _optionsController,
                decoration: const InputDecoration(labelText: 'Options (comma separated)', hintText: 'Option A, Option B...'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_textController.text.isEmpty) return;
            
            final q = Question(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: _textController.text,
              type: _type,
              options: _type == 'multiple_choice' 
                  ? _optionsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
                  : [],
            );
            widget.onAdd(q);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
