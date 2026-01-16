// This screen shows details for an event. It handles RSVPs and checking for conflicts.
import 'package:club_connect/models/event.dart';
import 'package:club_connect/models/club.dart';
import 'package:club_connect/screens/admin/event_attendees_screen.dart'; // NEW
import 'package:club_connect/screens/admin/create_event_screen.dart'; // NEW
import 'package:club_connect/screens/form_submission_screen.dart'; // NEW
import 'package:club_connect/services/club_service.dart';
import 'package:club_connect/widgets/comment_section.dart'; // NEW
import 'package:club_connect/services/notification_service.dart'; // NEW
import 'package:club_connect/screens/ticket_screen.dart';
import 'package:club_connect/services/event_service.dart';
import 'package:club_connect/services/feedback_service.dart'; // NEW
import 'package:club_connect/models/event_feedback.dart'; // NEW
import 'package:club_connect/services/user_service.dart'; // NEW
import 'package:club_connect/models/volunteer_shift.dart';
import 'package:club_connect/services/volunteer_service.dart';
import 'package:club_connect/services/volunteer_service.dart';
// import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // Removed to fix dependency error

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as calendar;

class EventDetailsScreen extends StatefulWidget {
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  Club? _eventClub;
  bool _isLoading = false;
  bool _hasRated = false; // NEW
  bool _isSaved = false; // NEW
  bool _isUpdatingSave = false; // NEW

  @override
  void initState() {
    super.initState();
    _fetchClub();
    _checkFeedbackStatus();
    _checkSavedStatus(); // NEW
  }

  // Check if user has saved this event
  Future<void> _checkSavedStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await UserService().getProfile(user.uid);
      if (profile != null && mounted) {
        setState(() {
          _isSaved = profile.savedEventIds.contains(widget.event.id);
        });
      }
    }
  }

  Future<void> _toggleSave() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isUpdatingSave) return;
    
    setState(() => _isUpdatingSave = true);
    
    try {
      await UserService().toggleSavedEvent(user.uid, widget.event.id, _isSaved);
      if (mounted) {
         setState(() => _isSaved = !_isSaved);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(_isSaved ? 'Event Saved' : 'Event Removed from Saved'), duration: const Duration(seconds: 1)),
         );
      }
    } catch (e) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
       if(mounted) setState(() => _isUpdatingSave = false);
    }
  }

  Future<void> _checkFeedbackStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final hasRated = await FeedbackService().hasUserProvidedFeedback(widget.event.id, user.uid);
      if (mounted) setState(() => _hasRated = hasRated);
    }
  }

  Future<void> _fetchClub() async {
    try {
      final club = await ClubService().getClubById(widget.event.clubId);
      if (mounted) {
        setState(() => _eventClub = club);
      }
    } catch (e) {
    }
  }

  Future<void> _handleJoinEvent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    // Check for questionnaire
    if (widget.event.registrationForm?.isEnabled == true && 
        widget.event.registrationForm!.questions.isNotEmpty) {
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FormSubmissionScreen(
            title: 'Event Registration',
            questions: widget.event.registrationForm!.questions,
            onSubmit: (answers) {
              Navigator.pop(context); // Close Screen
              _joinWithAnswers(user.uid, answers);
            },
          ),
        ),
      );
    } else {
      _joinWithAnswers(user.uid, null);
    }
  }



  Future<void> _joinWithAnswers(String uid, Map<String, String>? answers) async {
    setState(() => _isLoading = true);
    try {
      await EventService().rsvpToEvent(widget.event.id, uid, answers: answers);
      
      if (mounted) {
        _showJoinSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleJoinShift(VolunteerShift shift) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Check constraints
    if (shift.isFull) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift is full')));
       return;
    }
    if (shift.signedUpIds.contains(user.uid)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are already signed up for this shift')));
       return;
    }
    
    // CHECK FOR SUSPENSION (Strikes >= 3)
    setState(() => _isLoading = true); // Brief loading to check profile
    final profile = await UserService().getProfile(user.uid);
    setState(() => _isLoading = false);
    
    if (profile != null && profile.activeStrikes >= 3) {
       await showDialog(
         context: context, 
         builder: (ctx) => AlertDialog(
           title: const Text('Suspended from Volunteering', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
           content: const Text('You have accumulated 3 strikes this year. You are restricted from signing up for volunteer events for the remainder of the year.'),
           actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
         )
       );
       return;
    }
    
    // WARNING CONFIRMATION
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Shift Signup', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are signing up for "${shift.title}".'),
            const SizedBox(height: 16),
            const Text('⚠️ Important Policy:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 8),
            Text('If you miss this shift without cancelling before the lock deadline${widget.event.signupLockDateTime != null ? " (${DateFormat('MMM d, h:mm a').format(widget.event.signupLockDateTime!)})" : ""}, you will receive a STRIKE.'),
            const SizedBox(height: 8),
            const Text('3 strikes = Suspension from volunteering.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
       await VolunteerService().signUpForShift(
         eventId: widget.event.id,
         userId: user.uid,
         shiftId: shift.id,
       );
       
       if (mounted) {
         _showJoinSuccess(isShift: true);
       }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showJoinSuccess({bool isShift = false}) {
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isShift ? 'Signed up for shift!' : 'Joined successfully!')));
        
     // AUTO-REMINDER: Schedule local notification for 1 day before
     try {
       final reminderDate = widget.event.date.subtract(const Duration(days: 1));
       if (reminderDate.isAfter(DateTime.now())) {
          NotificationService().scheduleNotification(
            id: widget.event.id.hashCode,
            title: 'Upcoming Event: ${widget.event.title}',
            body: 'Tomorrow at ${DateFormat('h:mm a').format(widget.event.date)} at ${widget.event.location}',
            scheduledDate: reminderDate,
          );
          // Only show extra toast if not shift (reduce noise)
          if (!isShift) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder set for 1 day before.')));
       }
     } catch (e) {
     }
     
     if (!isShift) Navigator.pop(context); // Go back if general join, staying might be fine for shifts to see status
  }

  Future<void> _showRatingDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    double rating = 5.0;
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rate Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How was the event?'),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setState(() => rating = index + 1.0),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Comments (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
               Navigator.pop(ctx);
               setState(() => _isLoading = true);
               try {
                 final feedback = EventFeedback(
                   id: DateTime.now().millisecondsSinceEpoch.toString(),
                   eventId: widget.event.id,
                   userId: user.uid,
                   userName: user.displayName,
                   rating: rating,
                   comment: commentController.text.trim(),
                   timestamp: DateTime.now(),
                 );
                 
                 await FeedbackService().submitFeedback(feedback);
                 if (mounted) {
                   setState(() => _hasRated = true);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for your feedback!')));
                 }
               } catch (e) {
                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
               } finally {
                 if (mounted) setState(() => _isLoading = false);
               }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLeaveEvent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await EventService().removeUserFromEvent(widget.event.id, user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left event')));
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLeaveShift(VolunteerShift shift) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Check for lock
    if (widget.event.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot leave. Event is locked.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Shift?'),
        content: const Text('Are you sure you want to give up your spot?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
    
    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      await VolunteerService().leaveShift(
        eventId: widget.event.id,
        userId: user.uid,
        shiftId: shift.id,
      );
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left shift successfully')));
       }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    // We should listen to the event stream to get real-time updates on capacity
    return StreamBuilder<List<Event>>(
      stream: EventService().getAllEvents(),
      builder: (context, snapshot) {
        Event displayEvent = widget.event;
        
        if (snapshot.hasData) {
          final found = snapshot.data!.where((e) => e.id == widget.event.id);
          if (found.isNotEmpty) {
             displayEvent = found.first;
          }
        }

        final user = FirebaseAuth.instance.currentUser;
        final isAttending = user != null && displayEvent.attendeeIds.contains(user.uid);
        final isWaitlisted = user != null && displayEvent.waitlist.contains(user.uid);
        final isAdmin = user != null && _eventClub != null && _eventClub!.adminIds.contains(user.uid);
        
        // Capacity Logic
        final maxMatches = displayEvent.maxAttendees;
        final currentCount = displayEvent.attendeeIds.length;
        final isFull = maxMatches != null && currentCount >= maxMatches;
        
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200.0,
                pinned: true,
                actions: [
                  IconButton(
                    icon: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: _isSaved ? Colors.amber : Colors.white, // Colors for image bg
                    ),
                    onPressed: _toggleSave,
                    tooltip: _isSaved ? 'Remove from Saved' : 'Save Event',
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {
                         Navigator.of(context).push(
                           MaterialPageRoute(
                             builder: (_) => CreateEventScreen(eventToEdit: displayEvent),
                           ),
                         );
                      },
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    displayEvent.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                       _eventClub?.imageUrl != null 
                         ? Image.network(_eventClub!.imageUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey))
                         : Container(color: Theme.of(context).primaryColor),
                       Container(
                         decoration: BoxDecoration(
                           gradient: LinearGradient(
                             begin: Alignment.topCenter,
                             end: Alignment.bottomCenter,
                             colors: [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.7)],
                           ),
                         ),
                       ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       // --- RATINGS & REVIEWS ---
                       if (displayEvent.ratingCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      displayEvent.averageRating.toStringAsFixed(1),
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[900]),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${displayEvent.ratingCount} reviews',
                                style: TextStyle(color: Colors.grey[600], decoration: TextDecoration.underline),
                              ),
                              const Spacer(),
                              // Rate Button inline if applicable
                              if (isAttending && displayEvent.date.isBefore(DateTime.now()) && !_hasRated)
                                TextButton.icon(
                                  onPressed: _showRatingDialog,
                                  icon: const Icon(Icons.rate_review, size: 16),
                                  label: const Text('Rate'),
                                ),
                            ],
                          ),
                        ),

                      // --- HOSTED BY ROW ---
                      if (_eventClub != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: _eventClub!.imageUrl != null ? NetworkImage(_eventClub!.imageUrl!) : null,
                                child: _eventClub!.imageUrl == null ? Text(_eventClub!.name[0]) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Hosted by', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    Text(
                                      _eventClub!.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              // Optional: View Club Button
                            ],
                          ),
                        ),

                      // --- INFO CARDS ROW ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           // Date Box
                           Expanded(
                             child: Container(
                               padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                               decoration: BoxDecoration(
                                 color: Colors.white,
                                 borderRadius: BorderRadius.circular(16),
                                 boxShadow: [
                                   BoxShadow(
                                     color: Colors.blue.withValues(alpha: 0.1),
                                     blurRadius: 10,
                                     offset: const Offset(0, 4),
                                   ),
                                 ],
                               ),
                               child: Column(
                                 children: [
                                   Text(DateFormat('MMM').format(displayEvent.date).toUpperCase(), 
                                     style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0)
                                   ),
                                   Text(DateFormat('d').format(displayEvent.date), 
                                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28, height: 1.2)
                                   ),
                                   Text(DateFormat('yyyy').format(displayEvent.date), 
                                     style: TextStyle(color: Colors.grey[500], fontSize: 12)
                                   ),
                                   const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () {
                                          final calEvent = calendar.Event(
                                            title: displayEvent.title,
                                            description: displayEvent.description,
                                            location: displayEvent.location,
                                            startDate: displayEvent.date,
                                            endDate: displayEvent.date.add(const Duration(hours: 2)),
                                          );
                                          calendar.Add2Calendar.addEvent2Cal(calEvent);
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        foregroundColor: Colors.blue,
                                      ),
                                      child: const Text('Add to Cal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                 ],
                               ),
                             ),
                           ),
                           const SizedBox(width: 16),
                           // Time & Location Box
                           Expanded(
                             flex: 2,
                             child: Container(
                               padding: const EdgeInsets.all(16),
                               decoration: BoxDecoration(
                                 color: Colors.white,
                                 borderRadius: BorderRadius.circular(16),
                                 boxShadow: [
                                   BoxShadow(
                                     color: Colors.black.withValues(alpha: 0.05),
                                     blurRadius: 10,
                                     offset: const Offset(0, 4),
                                   ),
                                 ],
                               ),
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                                        child: Icon(Icons.access_time, size: 20, color: Colors.orange[800]),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Time', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                            Text(DateFormat('h:mm a').format(displayEvent.date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          ],
                                        ),
                                      ),
                                    ]),
                                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(8)),
                                        child: Icon(Icons.location_on, size: 20, color: Colors.purple[800]),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Location', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                            Text(displayEvent.location, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                          ],
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(height: 8),
                                    // Reminder Link
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: InkWell(
                                        onTap: () async {
                                             await NotificationService().scheduleNotification(
                                               id: displayEvent.id.hashCode,
                                               title: 'Upcoming: ${displayEvent.title}',
                                               body: 'In 30 mins at ${displayEvent.location}',
                                               scheduledDate: displayEvent.date.subtract(const Duration(minutes: 30)),
                                             );
                                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder set (30m prior)')));
                                        },
                                        child: Text('Set Reminder', style: TextStyle(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                 ],
                               ),
                             ),
                           ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Capacity & Waitlist
                      if (displayEvent.waitlist.isNotEmpty)
                        Container(
                           margin: const EdgeInsets.only(bottom: 16),
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                           child: Row(children: [
                             Icon(Icons.warning_amber, color: Colors.orange[900], size: 16),
                             const SizedBox(width: 8),
                             Text('${displayEvent.waitlist.length} people on waitlist', style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold)),
                           ]),
                        ),
                      if (maxMatches != null)
                        Row(
                           children: [
                             Text('Capacity: ', style: TextStyle(color: Colors.grey[600])),
                             Text('$currentCount / $maxMatches', style: const TextStyle(fontWeight: FontWeight.bold)),
                             const SizedBox(width: 8),
                             if (isFull) 
                               Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text('FULL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
                             else
                               Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)), child: const Text('OPEN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                           ],
                        ),

                      const SizedBox(height: 24),
                      Text('About', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(displayEvent.description, style: TextStyle(color: Colors.grey[800], height: 1.5)),
                      
                      const SizedBox(height: 32),
                      const Divider(),
                      CommentSection(entityId: displayEvent.id, isAdmin: isAdmin, enableInternalScrolling: false),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomSheet: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (isAdmin)
                     ElevatedButton.icon(
                      onPressed: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => EventAttendeesScreen(event: displayEvent)));
                      },
                      icon: const Icon(Icons.people),
                      label: const Text('Manage Attendees'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    )
                  else if (isAttending)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => TicketScreen(event: displayEvent)));
                          },
                          icon: const Icon(Icons.qr_code),
                          label: const Text('View Ticket'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _handleLeaveEvent,
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Leave Event'),
                        ),
                      ],
                    )
                  else if (isWaitlisted)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          alignment: Alignment.center,
                          color: Colors.orange[100],
                          child: Text(
                            'You are #${displayEvent.waitlist.indexOf(user!.uid) + 1} on the waitlist',
                            style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _handleLeaveEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Leave Waitlist'),
                        ),
                      ],
                    )
                  else if (isFull)
                    ElevatedButton(
                      onPressed: _handleJoinEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Join Waitlist'),
                    )
                  else
                    // VOLUNTEER OR REGULAR JOIN
                    displayEvent.isVolunteerEvent 
                    ? _buildVolunteerShiftList(displayEvent, user?.uid) 
                    : ElevatedButton(
                      onPressed: _handleJoinEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                      ),
                      child: const Text('Join Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVolunteerShiftList(Event event, String? userId) {
    // Parse shifts from Maps
    final shifts = event.volunteerShifts.map((m) => VolunteerShift.fromMap(m)).toList();
    
    // Sort by start time
    shifts.sort((a, b) => a.startTime.compareTo(b.startTime));

    if (shifts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No volunteer shifts available yet.', textAlign: TextAlign.center),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Available Volunteer Shifts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        ...shifts.map((shift) {
          final isSignedUp = userId != null && shift.signedUpIds.contains(userId);
          final isFull = shift.isFull;
          
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSignedUp ? BorderSide(color: Colors.green, width: 2) : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        shift.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (isSignedUp)
                        const Chip(
                          label: Text('Signed Up', style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.all(0),
                          visualDensity: VisualDensity.compact,
                        )
                      else if (isFull)
                         const Chip(
                          label: Text('Full', style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.grey,
                          padding: EdgeInsets.all(0),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${DateFormat('h:mm a').format(shift.startTime)} - ${DateFormat('h:mm a').format(shift.endTime)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${shift.durationHours.toStringAsFixed(1)} hrs)',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                   Row(
                    children: [
                      const Icon(Icons.people, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${shift.signedUpIds.length} / ${shift.maxVolunteers} volunteers',
                        style: TextStyle(color: isFull ? Colors.red : Colors.grey[800]),
                      ),
                    ],
                  ),
                   const SizedBox(height: 16),
                   SizedBox(
                     width: double.infinity,
                     child: isSignedUp 
                     ? OutlinedButton(
                         onPressed: event.isLocked
                             ? null // Disable if locked
                             : () => _handleLeaveShift(shift),
                         child: Text(event.isLocked ? 'Locked (Commitment Final)' : 'Leave Shift'),
                       )
                     : ElevatedButton(
                         onPressed: (userId == null) 
                             ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to volunteer')))
                             : (isFull || (event.isLocked && !isSignedUp)) // Can't join if locked
                                 ? null 
                                 : () => _handleJoinShift(shift),
                         child: Text(userId == null ? 'Login to Join' : (isFull ? 'Shift Full' : (event.isLocked ? 'Signups Closed' : 'Join Shift'))),
                       ),
                   )
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
