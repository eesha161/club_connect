import 'package:cloud_firestore/cloud_firestore.dart';
// This screen shows a list of everyone who signed up for an event.
import 'package:club_connect/models/event.dart';
import 'package:club_connect/models/user_profile.dart';
import 'package:club_connect/services/event_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:club_connect/widgets/loading_overlay.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:club_connect/screens/admin/qr_scanner_screen.dart';
import 'package:club_connect/services/pdf_service.dart'; // NEW
import 'package:club_connect/services/volunteer_service.dart'; // NEW
import 'package:club_connect/models/volunteer_shift.dart';

class EventAttendeesScreen extends StatefulWidget {
  final Event event;

  const EventAttendeesScreen({super.key, required this.event});

  @override
  State<EventAttendeesScreen> createState() => _EventAttendeesScreenState();
}

class _EventAttendeesScreenState extends State<EventAttendeesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleCheckIn(String uid, bool currentStatus) async {
    try {
      // Toggle the status
      await EventService().toggleCheckIn(widget.event.id, uid, !currentStatus);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentStatus ? 'Checked in!' : 'Check-in removed'),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Attendance'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Confirmed'),
              Tab(text: 'Waitlist'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export CSV',
              onPressed: () => _exportAttendance(),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: () => _exportPdf(),
            ),
             IconButton(
              icon: const Icon(Icons.playlist_add_check),
              tooltip: 'Process No-Shows (Auto-Strike)',
              onPressed: () => _processNoShows(), // NEW
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          // Listen to the Event document to get real-time 'attendeeIds' and 'checkedInIds' updates
          stream: FirebaseFirestore.instance.collection('events').doc(widget.event.id).snapshots(),
          builder: (context, eventSnapshot) {
            if (!eventSnapshot.hasData) {
              return const LoadingOverlay();
            }
  
            // Parse updated event data
            Event currentEvent;
            try {
               currentEvent = Event.fromMap(eventSnapshot.data!.data() as Map<String, dynamic>, widget.event.id);
            } catch(e) {
               return Center(child: Text('Error loading event: $e'));
            }
  
            return StreamBuilder<List<UserProfile>>(
              stream: UserService().getMembersOfClub(currentEvent.clubId),
              builder: (context, membersSnapshot) {
                 if (membersSnapshot.hasError) return const Center(child: Text('Error loading profiles'));
                 if (!membersSnapshot.hasData) return const Center(child: CircularProgressIndicator());
  
                 // Load questionnaire responses
                 return FutureBuilder<Map<String, Map<String, dynamic>>>(
                   future: EventService().getQuestionnaireResponses(widget.event.id),
                   builder: (context, responsesSnapshot) {
                     
                     final allMembers = membersSnapshot.data ?? [];
                     final responses = responsesSnapshot.data ?? {};
                     
                     // Filter lists
                     final confirmedAttendees = allMembers.where((m) => currentEvent.attendeeIds.contains(m.uid)).toList();
                     final waitlistedAttendees = allMembers.where((m) => currentEvent.waitlist.contains(m.uid)).toList();
                     
                     // Helper to filter by search
                     List<UserProfile> filter(List<UserProfile> list) {
                       return list.where((m) {
                         if (_searchQuery.isEmpty) return true;
                         return m.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                m.email.toLowerCase().contains(_searchQuery.toLowerCase());
                       }).toList();
                     }

                     final filteredConfirmed = filter(confirmedAttendees);
                     final filteredWaitlist = filter(waitlistedAttendees);
                     
                     // Sort Confirmed: Checked-in first
                     filteredConfirmed.sort((a, b) {
                        final aChecked = currentEvent.checkedInIds.contains(a.uid);
                        final bChecked = currentEvent.checkedInIds.contains(b.uid);
                        if (aChecked && !bChecked) return -1;
                        if (!aChecked && bChecked) return 1;
                        return a.displayName.compareTo(b.displayName);
                     });
  
                     return Column(
                       children: [
                         // Stats Header
                         Container(
                           padding: const EdgeInsets.all(16),
                           color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceAround,
                             children: [
                               _buildStatItem('Attending', confirmedAttendees.length.toString()),
                               _buildStatItem('Waitlist', waitlistedAttendees.length.toString()),
                               _buildStatItem('Checked In', '${currentEvent.checkedInIds.length}'),
                             ],
                           ),
                         ),
                         
                         // Search
                         Padding(
                           padding: const EdgeInsets.all(16),
                           child: TextField(
                             controller: _searchController,
                             decoration: const InputDecoration(
                               labelText: 'Search',
                               prefixIcon: Icon(Icons.search),
                               border: OutlineInputBorder(),
                               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                             ),
                             onChanged: (val) => setState(() => _searchQuery = val),
                           ),
                         ),
                         
                         // Tab Views
                         Expanded(
                           child: TabBarView(
                             children: [
                               // Confirmed List
                               _buildUserList(context, filteredConfirmed, currentEvent, responses, isWaitlist: false),
                               // Waitlist List
                               _buildUserList(context, filteredWaitlist, currentEvent, responses, isWaitlist: true),
                             ],
                           ),
                         ),
                       ],
                     );
                   }
                 );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => QRScannerScreen(event: widget.event)),
            );
          },
          label: const Text('Scan Tickets'),
          icon: const Icon(Icons.qr_code_scanner),
        ),
      ),
    );
  }

  Widget _buildUserList(
      BuildContext context, 
      List<UserProfile> users, 
      Event currentEvent, 
      Map<String, Map<String, dynamic>> responses, 
      {required bool isWaitlist}) {
    
    if (users.isEmpty) return const Center(child: Text('No users found'));

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final member = users[index];
        final isCheckedIn = currentEvent.checkedInIds.contains(member.uid);
        final hasResponse = responses.containsKey(member.uid);
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isWaitlist ? Colors.orange[100] : (isCheckedIn ? Colors.green[100] : Colors.grey[200]),
            child: Text(
              isWaitlist ? '${index + 1}' : (member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?'),
              style: TextStyle(color: isWaitlist ? Colors.orange[900] : (isCheckedIn ? Colors.green[800] : Colors.black54)),
            ),
          ),
          title: Text(member.displayName, style: TextStyle(fontWeight: isCheckedIn ? FontWeight.bold : FontWeight.normal)),
          subtitle: Text(member.email),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasResponse)
                IconButton(
                  icon: const Icon(Icons.description, color: Colors.blue),
                  tooltip: 'View Questionnaire Response',
                  onPressed: () {
                     final userResponse = responses[member.uid];
                     if (userResponse != null) {
                       _showResponseDialog(member.displayName, userResponse['answers'] as Map<String, dynamic>);
                     }
                  },
                ),
              if (!isWaitlist) // Only confirmed users can check in
                Switch(
                  value: isCheckedIn,
                  activeThumbColor: Colors.green,
                  onChanged: (val) => _toggleCheckIn(member.uid, isCheckedIn),
                ),
              // Manual Award Hours Button
              if (!isWaitlist && currentEvent.isVolunteerEvent)
                 IconButton(
                   icon: const Icon(Icons.assignment_turned_in_outlined, color: Colors.orange),
                   tooltip: 'Manually Award Hours',
                   onPressed: () => _awardVolunteerHours(member, currentEvent),
                 ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Future<void> _exportAttendance() async {
    try {
      // 1. Fetch data
      final membersSnapshot = await UserService().getMembersOfClub(widget.event.clubId).first;
      final currentEventParams = await FirebaseFirestore.instance.collection('events').doc(widget.event.id).get();
      final currentEvent = Event.fromMap(currentEventParams.data() as Map<String, dynamic>, widget.event.id);
      
      final responsesMap = await EventService().getQuestionnaireResponses(widget.event.id);

      final attendees = membersSnapshot.where((m) => currentEvent.attendeeIds.contains(m.uid)).toList();

      // 2. Build CSV Content
      final buffer = StringBuffer();
      
      // Header
      buffer.write('Name,Email,Checked In,Questionnaire Responses\n');
      
      for (final member in attendees) {
        final isCheckedIn = currentEvent.checkedInIds.contains(member.uid);
        final status = isCheckedIn ? 'Yes' : 'No';
        
        // Format Responses
        String responseText = '';
        if (responsesMap.containsKey(member.uid)) {
          final answers = responsesMap[member.uid]!['answers'] as Map<String, dynamic>;
          // Simple flattening: "Q1: A1 | Q2: A2"
          responseText = answers.entries.map((e) => '${e.key}: ${e.value}').join(' | ');
        }
        
        // Escape CSV fields
        final name = '"${member.displayName.replaceAll('"', '""')}"';
        final email = '"${member.email.replaceAll('"', '""')}"';
        final resp = '"${responseText.replaceAll('"', '""')}"';
        
        buffer.write('$name,$email,$status,$resp\n');
      }

      // 3. Save to File
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/attendance_${widget.event.title.replaceAll(RegExp(r'[^\w\s]+'), '')}.csv';
      final file = File(path);
      await file.writeAsString(buffer.toString());

      // 4. Share
      await Share.shareXFiles([XFile(path)], text: 'Attendance Report for ${widget.event.title}');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _showResponseDialog(String memberName, Map<String, dynamic> answers) {
    // We need to resolve question IDs to question text if possible. 
    // Ideally the questionnaire structure is in widget.event.signupQuestionnaire if we want full text.
    // For now, we'll try to map if possible, or just show Q: Answer.
    

    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Responses from $memberName'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: answers.entries.map((entry) {
                final questionText = entry.key; // Key is now the question text itself
                final answer = entry.value;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(questionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(answer.toString(), style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportPdf() async {
    try {
      final membersSnapshot = await UserService().getMembersOfClub(widget.event.clubId).first;
      final currentEventParams = await FirebaseFirestore.instance.collection('events').doc(widget.event.id).get();
      final currentEvent = Event.fromMap(currentEventParams.data() as Map<String, dynamic>, widget.event.id);
      
      final attendees = membersSnapshot.where((m) => currentEvent.attendeeIds.contains(m.uid)).toList();
      
      await PdfService().generateAttendancePdf(
        event: currentEvent,
        attendees: attendees,
        checkedInIds: currentEvent.checkedInIds,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Export failed: $e')));
      }
    }
  }


  Future<void> _processNoShows() async {
     // 1. Confirm Dialog
     final confirm = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text('Process No-Shows'),
         content: const Text(
           'This will automatically check all confirmed attendees.\n\n'
           'Anyone who has NOT checked in will receive a Strike.\n\n'
           'Are you sure you want to proceed?'
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
           ElevatedButton(
             onPressed: () => Navigator.pop(ctx, true),
             child: const Text('Process & Give Strikes'),
           ),
         ],
       ),
     );
     
     if (confirm != true) return;

     try {
       // 2. Refresh Event Data
       final evDoc = await FirebaseFirestore.instance.collection('events').doc(widget.event.id).get();
       final currentEvent = Event.fromMap(evDoc.data()!, widget.event.id);
       
       // 3. Identify No-Shows
       final noShows = currentEvent.attendeeIds.where((uid) => !currentEvent.checkedInIds.contains(uid)).toList();
       
       if (noShows.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No absentees found! Everyone attended.')));
          return;
       }

       // 4. Batch Issue Strikes
       // Use Loading Overlay if available or simple snackbar progress
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Processing ${noShows.length} no-shows...')));
       
       int successCount = 0;
       for (final uid in noShows) {
          try {
            await VolunteerService().assignStrike(
              userId: uid,
              clubId: currentEvent.clubId,
              reason: 'Missed Event: ${currentEvent.title}',
            );
            successCount++;
          } catch (e) {
          }
       }
       
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Successfully issued strikes to $successCount users.')),
         );
       }
       
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
     }
  }
  Future<void> _awardVolunteerHours(UserProfile user, Event event) async {
    // 1. Find shifts user is signed up for
    final userShifts = <VolunteerShift>[];
    final allShifts = event.volunteerShifts.map((m) => VolunteerShift.fromMap(m)).toList();
    
    for (var shift in allShifts) {
      if (shift.signedUpIds.contains(user.uid)) {
        userShifts.add(shift);
      }
    }

    // 2. Handling Unscheduled Volunteers
    if (userShifts.isEmpty) {
      if (allShifts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No shifts defined for this event.')),
          );
        }
        return;
      }
      
      // Prompt admin to select a shift
      VolunteerShift? selectedShift;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select Shift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${user.displayName} is not signed up for any shifts.\nSelect a shift to award credit for:'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allShifts.length,
                  itemBuilder: (context, index) {
                    final shift = allShifts[index];
                    return ListTile(
                      title: Text(shift.title),
                      subtitle: Text('${shift.durationHours} hours'),
                      onTap: () {
                        selectedShift = shift;
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedShift != null) {
        userShifts.add(selectedShift!);
      } else {
        return; // Cancelled
      }
    }

    // 3. Confirm Dialog
    final totalHours = userShifts.fold(0.0, (sum, s) => sum + s.durationHours);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Award Volunteer Hours'),
        content: Text(
          'Award $totalHours hours to ${user.displayName}?\n\n'
          'This will mark them as attended for the following shifts:\n'
          '${userShifts.map((s) => "- ${s.title} (${s.durationHours}h)").join("\n")}'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Award Hours'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 4. Process
    int successCount = 0;
    for (final shift in userShifts) {
      try {
        await VolunteerService().manuallyAwardHours(
          eventId: event.id,
          userId: user.uid,
          shiftId: shift.id,
          startTime: shift.startTime,
          endTime: shift.endTime,
        );
        successCount++;
      } catch (e) {
        if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error awarding for ${shift.title}: $e')));
        }
      }
    }

    if (mounted && successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Successfully awarded hours for $successCount shifts.')),
      );
    }
  }
}
