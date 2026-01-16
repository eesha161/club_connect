import 'package:club_connect/models/club.dart';
// This screen lets club admins make a new event.
import 'package:club_connect/models/event.dart';
import 'package:club_connect/models/user_profile.dart';
import 'package:club_connect/widgets/form_builder.dart';
import 'package:club_connect/models/question.dart';
import 'package:club_connect/models/club_form.dart';
import 'package:club_connect/models/inbox_message.dart';
import 'package:club_connect/services/inbox_service.dart';
import 'package:club_connect/services/club_service.dart';
import 'package:club_connect/services/event_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:club_connect/models/volunteer_shift.dart';
import 'package:club_connect/services/location_service.dart'; // NEW
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';


class CreateEventScreen extends StatefulWidget {
  final Event? eventToEdit;
  final String? preSelectedClubId;

  const CreateEventScreen({super.key, this.eventToEdit, this.preSelectedClubId});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationService = LocationService(); // NEW

  late TextEditingController _titleController;
  late TextEditingController _locationController; // Specific location (Room etc)
  late TextEditingController _descriptionController;

  // Broad Location (City/State/Level)
  String? _selectedState;
  // String? _selectedCity; // We can use _cityController or just reuse _locationService.getCities
  final TextEditingController _cityController = TextEditingController(); // Using Autocomplete controller approach
  String? _selectedEducationLevel;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Club? _selectedClub;
  
  bool _isMandatory = false;
  late TextEditingController _lockDaysController;
  List<Question> _questions = []; 
  
  // Volunteer Event State
  bool _isVolunteerEvent = false;
  bool _requiresCheckOut = false;
  List<VolunteerShift> _shifts = [];
  DateTime? _lockDate;
  TimeOfDay? _lockTime; 
  
  bool _isLoading = false;

  // Recurrence Options
  String _recurrenceType = 'None';
  late TextEditingController _occurrencesController;
  final List<String> _recurrenceOptions = ['None', 'Daily', 'Weekly', 'BiWeekly', 'Monthly'];

  List<Club> _managedClubs = []; 

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data if editing
    _titleController = TextEditingController(text: widget.eventToEdit?.title ?? '');
    _locationController = TextEditingController(text: widget.eventToEdit?.location ?? '');
    _descriptionController = TextEditingController(text: widget.eventToEdit?.description ?? '');
    _lockDaysController = TextEditingController(text: widget.eventToEdit?.lockDaysBeforeEvent?.toString() ?? ''); 
    _occurrencesController = TextEditingController(text: '1'); 

    if (widget.eventToEdit != null) {
      _selectedDate = widget.eventToEdit!.date;
      _selectedTime = TimeOfDay.fromDateTime(widget.eventToEdit!.date);
      _isMandatory = widget.eventToEdit!.isMandatory;
      // Note: _selectedClub will be set after fetching clubs
      _questions = widget.eventToEdit!.registrationForm?.questions ?? [];
      
      // Load volunteer data
      _isVolunteerEvent = widget.eventToEdit!.isVolunteerEvent;
      _requiresCheckOut = widget.eventToEdit!.requiresCheckOut;
      _shifts = widget.eventToEdit!.volunteerShifts.map((m) => VolunteerShift.fromMap(m)).toList();
      
      // Load Location Data
      _selectedState = widget.eventToEdit!.state;
      _cityController.text = widget.eventToEdit!.city ?? '';
      _selectedEducationLevel = widget.eventToEdit!.educationLevel;
    } else {
      // Default to mandatory check-out if creating new volunteer event (user preference)
      _requiresCheckOut = true; 
    }
    
    if (widget.eventToEdit?.signupLockDateTime != null) {
       _lockDate = widget.eventToEdit!.signupLockDateTime;
       _lockTime = TimeOfDay.fromDateTime(widget.eventToEdit!.signupLockDateTime!);
    }

    _loadManagedClubs();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _lockDaysController.dispose();
    _occurrencesController.dispose();
    _cityController.dispose(); // NEW
    super.dispose();
  }

  Future<void> _loadManagedClubs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Fetch clubs where user is admin
      try {
        final clubs = await ClubService().getClubsByAdmin(user.uid);
        if (mounted) {
          setState(() {
             _managedClubs = clubs;

             
             // Handle Pre-selection or Edit Mode
             if (widget.eventToEdit != null) {
               try {
                 _selectedClub = clubs.firstWhere((c) => c.id == widget.eventToEdit!.clubId);
               } catch (e) {
               }
             } else if (widget.preSelectedClubId != null) {
               // Handle Quick Action from Manage Club Screen
               try {
                 _selectedClub = clubs.firstWhere((c) => c.id == widget.preSelectedClubId);
               } catch (e) {
               }
             } else if (clubs.isNotEmpty && _selectedClub == null) {
               // Default to first if only one? Or leave null. 
               // _selectedClub = clubs.first;
             }
          });
        }
      } catch (e) {
      }
    }
  }

  // ... (Pickers)

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null || _selectedClub == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Club, Date, and Time.')));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Common Data
      // Deprecated: lockDays. We now use signupLockDateTime exclusively.
      int? lockDays; 
      // if (_lockDaysController.text.isNotEmpty) {
      //   lockDays = int.tryParse(_lockDaysController.text);
      // }

      
      DateTime eventDateTime = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        _selectedTime!.hour, _selectedTime!.minute,
      );

      DateTime? signupLockDateTime;
      if (_lockDate != null && _lockTime != null) {
        signupLockDateTime = DateTime(
          _lockDate!.year, _lockDate!.month, _lockDate!.day,
          _lockTime!.hour, _lockTime!.minute,
        );
      }

      // EDIT MODE
      if (widget.eventToEdit != null) {
         final updatedEvent = Event(
            id: widget.eventToEdit!.id, // Keep ID
            clubId: _selectedClub!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            date: eventDateTime,
            location: _locationController.text.trim(),
            attendeeIds: widget.eventToEdit!.attendeeIds, // Keep attendees
            isMandatory: _isMandatory,
            lockDaysBeforeEvent: lockDays,
            signupQuestions: [], // Deprecated
            registrationForm: _questions.isNotEmpty 
                ? ClubForm(isEnabled: true, questions: _questions) 
                : null,
            checkedInIds: widget.eventToEdit!.checkedInIds, // Keep checkins
            maxAttendees: widget.eventToEdit!.maxAttendees,
            waitlist: widget.eventToEdit!.waitlist,
            isVolunteerEvent: _isVolunteerEvent,
            requiresCheckOut: _requiresCheckOut,
            volunteerShifts: _shifts.map((s) => s.toMap()).toList(),
            checkOutIds: widget.eventToEdit!.checkOutIds,
            signupLockDateTime: signupLockDateTime,
            // NEW Location Data
            city: _cityController.text.isNotEmpty ? _cityController.text : null,
            state: _selectedState,
            educationLevel: _selectedEducationLevel,
         );
         
         await EventService().updateEvent(updatedEvent);
         
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event updated!')));
           Navigator.pop(context);
         }
         return;
      }
      
      // CREATE MODE logic...
      // 1. Determine Occurrences
      int occurrences = 1;
      // ... (Existing recurrence logic)
      if (_recurrenceType != 'None') {
        occurrences = int.tryParse(_occurrencesController.text) ?? 1;
        if (occurrences < 1) occurrences = 1;
        if (occurrences > 52) occurrences = 52;
      }
      
      // ... (Auto-signup logic - same as before)
      List<String> initialAttendees = [];
      if (_isMandatory) {
        final members = await UserService().getMembersOfClub(_selectedClub!.id).first;
        initialAttendees = members.map((m) => m.uid).toList();
      }

      for (int i = 0; i < occurrences; i++) {
         // ... (Date calculation logic from before)
         DateTime currentEventDate = eventDateTime; // Simplified for chunk replacement
         if (i > 0) {
           // Recalculate based on loop (Need to restore full logic below)
            switch (_recurrenceType) {
             case 'Daily': currentEventDate = eventDateTime.add(Duration(days: i)); break;
             case 'Weekly': currentEventDate = eventDateTime.add(Duration(days: i * 7)); break;
             case 'BiWeekly': currentEventDate = eventDateTime.add(Duration(days: i * 14)); break;
             case 'Monthly': 
               currentEventDate = DateTime(eventDateTime.year, eventDateTime.month + i, eventDateTime.day, eventDateTime.hour, eventDateTime.minute);
               break;
           }
         }
         
           final newEvent = Event(
           id: DateTime.now().microsecondsSinceEpoch.toString() + '_$i',
           clubId: _selectedClub!.id,
           title: _titleController.text.trim(),
           description: _descriptionController.text.trim(),
           date: currentEventDate,
           location: _locationController.text.trim(),
           attendeeIds: initialAttendees,
           isMandatory: _isMandatory,
           lockDaysBeforeEvent: lockDays,
           signupQuestions: [], // Deprecated
           registrationForm: _questions.isNotEmpty 
                ? ClubForm(isEnabled: true, questions: _questions) 
                : null,
           checkedInIds: [],
           maxAttendees: null, // Note: Could allow setting this in UI if needed
           waitlist: [],
            isVolunteerEvent: _isVolunteerEvent,
            requiresCheckOut: _requiresCheckOut,
            volunteerShifts: _shifts.map((s) => s.toMap()).toList(),
            checkOutIds: [],
            signupLockDateTime: signupLockDateTime,
            // NEW Location Data
            city: _cityController.text.isNotEmpty ? _cityController.text : null,
            state: _selectedState,
            educationLevel: _selectedEducationLevel,
         );
         await EventService().createEvent(newEvent);

         // NOTIFICATION: Send Inbox Message to all Club Members about the new event
         // This can be resource intensive client-side for large clubs, but acceptable for MVP/Demo.
         try {
            // Re-fetch members to be sure (or use initialAttendees if mandatory)
            // If mandatory, we already have initialAttendees list of UIDs.
            // If NOT mandatory, we should still notify them that an event exists.
            
            // Optimization: Fetch only if not already fetched
            final members = await UserService().getMembersOfClub(_selectedClub!.id).first;
            
            for (var member in members) {
               // Don't notify the creator? (Assume creator is current user, but maybe yes for confirmation)
               
               final msg = InboxMessage(
                 id: '',
                 title: 'New Event: ${newEvent.title}',
                 body: '${_isMandatory ? "MANDATORY: " : ""}A new event is scheduled for ${DateFormat('MMM d').format(newEvent.date)} at ${newEvent.location}.',
                 timestamp: DateTime.now(),
                 type: _isMandatory ? 'system' : 'announcement', // Use system for mandatory to grab attention
                 relatedId: newEvent.id,
               );
               await InboxService().addMessage(member.uid, msg);
            }
         } catch (e) {
         }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Created $occurrences event(s) successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Pickers match existing)
  Future<void> _pickDate() async {
    // ...
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now, // Use selected if editing
      firstDate: DateTime(2020), // Allow past for editing
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

   Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _showAddShiftDialog() {
    _showShiftDialog(null);
  }

  void _showEditShiftDialog(int index) {
    _showShiftDialog(index);
  }

  void _showShiftDialog(int? editIndex) {
    final isEdit = editIndex != null;
    final existingShift = isEdit ? _shifts[editIndex] : null;

    final titleController = TextEditingController(text: existingShift?.title ?? '');
    final maxVolunteersController = TextEditingController(
      text: existingShift?.maxVolunteers.toString() ?? '10'
    );
    
    TimeOfDay startTime = existingShift != null 
        ? TimeOfDay.fromDateTime(existingShift.startTime)
        : TimeOfDay.now();
    TimeOfDay endTime = existingShift != null
        ? TimeOfDay.fromDateTime(existingShift.endTime)
        : TimeOfDay(hour: TimeOfDay.now().hour + 2, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Shift' : 'Add Volunteer Shift'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Shift Title',
                        hintText: 'e.g., Morning Setup',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: maxVolunteersController,
                      decoration: const InputDecoration(
                        labelText: 'Max Volunteers',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (picked != null) {
                                setDialogState(() => startTime = picked);
                              }
                            },
                            child: Text('Start: ${startTime.format(context)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (picked != null) {
                                setDialogState(() => endTime = picked);
                              }
                            },
                            child: Text('End: ${endTime.format(context)}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a shift title')),
                      );
                      return;
                    }

                    final eventDate = _selectedDate ?? DateTime.now();
                    final shift = VolunteerShift(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleController.text.trim(),
                      startTime: DateTime(
                        eventDate.year, eventDate.month, eventDate.day,
                        startTime.hour, startTime.minute,
                      ),
                      endTime: DateTime(
                        eventDate.year, eventDate.month, eventDate.day,
                        endTime.hour, endTime.minute,
                      ),
                      maxVolunteers: int.tryParse(maxVolunteersController.text) ?? 10,
                    );

                    setState(() {
                      if (isEdit) {
                        _shifts[editIndex] = shift;
                      } else {
                        _shifts.add(shift);
                      }
                    });

                    Navigator.pop(ctx);
                  },
                  child: Text(isEdit ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.eventToEdit == null ? 'Create New Event' : 'Edit Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CLUB SELECTOR
              if (widget.eventToEdit == null) ...[
                 const Text('Select Club', style: TextStyle(fontWeight: FontWeight.bold)),
                 StreamBuilder<List<Club>>(
                  stream: ClubService().getClubs(), 
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    final clubs = snapshot.data!;
                    return DropdownButtonFormField<Club>(
                      initialValue: _selectedClub,
                      items: clubs.map((club) => DropdownMenuItem(value: club, child: Text(club.name))).toList(),
                      onChanged: (val) {
                         setState(() {
                           _selectedClub = val;
                           // Auto-fill location from Club (Always overwrite since UI is hidden)
                           if (val != null) {
                              _selectedState = val.state;
                              _cityController.text = val.city ?? '';
                              _selectedEducationLevel = val.educationLevel;
                           }
                         });
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      hint: const Text('Choose a club...'),
                    );
                  },
                 ),
                 const SizedBox(height: 16),
              ] else ...[
                 // In Edit Mode, we show the club but maybe disable changing it to avoid complex logic
                 // Or we need to fetch the specific club name
                 FutureBuilder<Club?>(
                   future: ClubService().getClubById(widget.eventToEdit!.clubId),
                   builder: (context, snapshot) {
                      if (snapshot.hasData && _selectedClub == null) {
                         // Initialize _selectedClub once
                         WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                               setState(() {
                                 _selectedClub = snapshot.data;
                                 // Ensure legacy events get updated data if missing
                                 if (_selectedState == null) _selectedState = snapshot.data?.state;
                                 if (_cityController.text.isEmpty) _cityController.text = snapshot.data?.city ?? '';
                                 if (_selectedEducationLevel == null) _selectedEducationLevel = snapshot.data?.educationLevel;
                               });
                            }
                         });
                      }
                      return TextFormField(
                        initialValue: snapshot.data?.name ?? 'Loading...',
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Club', border: OutlineInputBorder(), filled: true, fillColor: Colors.black12),
                      );
                   }
                 ),
                 const SizedBox(height: 16),
              ],


              // 2. EVENT TITLE
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              // 3.5 RECURRENCE
              Row(
                children: [
                   Expanded(
                     child: DropdownButtonFormField<String>(
                       value: _recurrenceType,
                       items: _recurrenceOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                       onChanged: (val) => setState(() => _recurrenceType = val!),
                       decoration: const InputDecoration(
                         labelText: 'Repeat',
                         border: OutlineInputBorder(),
                         contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                       ),
                     ),
                   ),
                   if (_recurrenceType != 'None') ...[
                     const SizedBox(width: 16),
                     Expanded(
                       child: TextFormField(
                         controller: _occurrencesController,
                         decoration: const InputDecoration(
                            labelText: 'Occurrences',
                            border: OutlineInputBorder(),
                         ),
                         keyboardType: TextInputType.number,
                       ),
                     ),
                   ],
                ],
              ),
              const SizedBox(height: 16),

              // 3. DATE & TIME ROW
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_selectedDate == null
                          ? 'Pick Date'
                          : DateFormat('MMM d, yyyy').format(_selectedDate!)),
                      onPressed: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(_selectedTime == null
                          ? 'Pick Time'
                          : _selectedTime!.format(context)),
                      onPressed: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. LOCATION DETAILS
              const Text('Location Details', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              // Venue
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Venue / Room (e.g. Student Center)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Venue is required' : null,
              ),
              const SizedBox(height: 16),
              
              // HIDDEN: City/State/Education auto-filled from Club


              // 5. DESCRIPTION
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 16),

              // 6. EVENT SETTINGS
              const Text('Event Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              SwitchListTile(
                title: const Text('Mandatory Event'),
                subtitle: const Text('All club members will be auto-signed up'),
                value: _isMandatory,
                onChanged: (val) {
                  setState(() {
                    _isMandatory = val;
                    if (val) {
                      _lockDaysController.clear();
                      _lockDate = null;
                      _lockTime = null;
                    }
                  });
                },
                activeThumbColor: Theme.of(context).primaryColor,
              ),
              
              const SizedBox(height: 8),
              
              if (!_isMandatory) ...[
                const SizedBox(height: 16),
                const Text('Signup Deadline (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('Date/Time when signups close or dropping out is restricted.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                 Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_lockDate == null
                            ? 'Pick Date'
                            : DateFormat('MMM d, yyyy').format(_lockDate!)),
                        onPressed: () async {
                           final picked = await showDatePicker(
                            context: context,
                            initialDate: _lockDate ?? _selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: _selectedDate?.add(const Duration(days: 365)) ?? DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => _lockDate = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text(_lockTime == null
                            ? 'Pick Time'
                            : _lockTime!.format(context)),
                        onPressed: () async {
                           final picked = await showTimePicker(
                            context: context,
                            initialTime: _lockTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) setState(() => _lockTime = picked);
                        },
                      ),
                    ),
                  ],
                ),
                if (_lockDate != null)
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: TextButton(
                       onPressed: () => setState(() { _lockDate = null; _lockTime = null; }),
                       child: const Text('Remove Deadline', style: TextStyle(color: Colors.red)),
                     ),
                   ),
                const SizedBox(height: 16),
              ],
              
              if (!_isMandatory) ...[
                const Divider(),
                const SizedBox(height: 8),
                FormBuilder(
                   questions: _questions,
                   onChanged: (val) {
                      setState(() {
                         _questions = val;
                      });
                   },
                ),
              ],

              // VOLUNTEER EVENT SECTION
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              
              SwitchListTile(
                title: const Text('Volunteer Event'),
                subtitle: const Text('Enable shift management and hour tracking'),
                value: _isVolunteerEvent,
                onChanged: (val) {
                  setState(() {
                    _isVolunteerEvent = val;
                    if (val) {
                      _requiresCheckOut = true; // Auto-enable check-out for volunteer events
                    }
                  });
                },
                activeThumbColor: Theme.of(context).primaryColor,
              ),
              
              if (!_isVolunteerEvent) ...[ 
                SwitchListTile(
                  title: const Text('Require Check-Out'),
                  subtitle: const Text('Track when attendees leave the event'),
                  value: _requiresCheckOut,
                  onChanged: (val) => setState(() => _requiresCheckOut = val),
                  activeThumbColor: Theme.of(context).primaryColor,
                ),
              ],

              if (_isVolunteerEvent) ...[ 
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Volunteer Shifts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: () => _showAddShiftDialog(),
                    ),
                  ],
                ),
                const Text('Create shifts with specific times and requirements', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                
                if (_shifts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Center(
                      child: Text('No shifts added yet. Tap + to create a shift.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ..._shifts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final shift = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.schedule, color: Colors.blue),
                        title: Text(shift.title),
                        subtitle: Text(
                          '${DateFormat('h:mm a').format(shift.startTime)} - ${DateFormat('h:mm a').format(shift.endTime)} (${shift.durationHours.toStringAsFixed(1)}h)\n'
                          'Max: ${shift.maxVolunteers} volunteers',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() => _shifts.removeAt(index));
                          },
                        ),
                        onTap: () => _showEditShiftDialog(index),
                      ),
                    );
                  }),
              ],

              const SizedBox(height: 32),

              // 6. SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitEvent,
                  child: Text(widget.eventToEdit == null ? 'Create Event' : 'Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
