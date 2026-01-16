// This screen shows upcoming events. You can view them as a list or on a calendar.
import 'package:club_connect/models/event.dart';
import 'package:club_connect/widgets/common_app_bar.dart'; // NEW
import 'package:club_connect/models/club.dart'; // NEW
import 'package:club_connect/services/club_service.dart'; // NEW
import 'package:club_connect/screens/event_details_screen.dart'; // NEW
import 'package:club_connect/screens/profile_screen.dart'; // Import ProfileScreen
import 'package:club_connect/services/event_service.dart';
import 'package:club_connect/widgets/event_card_skeleton.dart';
import 'package:club_connect/widgets/fade_in_animation.dart';
import 'package:club_connect/widgets/loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:club_connect/models/user_profile.dart'; // NEW
import 'package:club_connect/services/user_service.dart'; // NEW
import 'package:club_connect/services/club_service.dart'; // NEW
import 'package:club_connect/screens/inbox_screen.dart'; // NEW
import 'package:club_connect/services/inbox_service.dart'; // NEW
import 'package:firebase_auth/firebase_auth.dart'; // NEW
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart'; // NEW
import 'package:club_connect/widgets/empty_state_widget.dart'; // NEW
import 'package:shared_preferences/shared_preferences.dart'; // NEW

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  // View State
  Set<int> _viewSelection = {0}; // 0: List, 1: Calendar

  // List View State
  final GlobalKey _searchKey = GlobalKey(); // Add Key
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // NEW: Filter State
  String? _selectedCity;
  String? _selectedState;
  String? _selectedClubId;
  String? _selectedEducationLevel;

  // Calendar View State
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Event>> _calendarEvents = {};

  // User State
  UserProfile? _userProfile;
  List<String> _managedClubIds = [];
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    // Pre-load events for calendar
    _loadCalendarEvents();
    _fetchUserData();
  }
// ...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'Events',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.list),
                  label: Text('List'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.calendar_month),
                  label: Text('Calendar'),
                ),
              ],
              selected: _viewSelection,
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _viewSelection = newSelection;
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _viewSelection.first,
        children: [
          _buildListView(),
          _buildCalendarView(),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return Column(
      children: [
        // Search Bar (existing)...
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            key: _searchKey, // Add Key
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search events by title or location...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        
        // Active Filters Chips
        if (_selectedCity != null || _selectedState != null || _selectedClubId != null)
           SingleChildScrollView(
             scrollDirection: Axis.horizontal,
             padding: const EdgeInsets.symmetric(horizontal: 16),
             child: Row(
               children: [
                 if (_selectedClubId != null)
                   Padding(
                     padding: const EdgeInsets.only(right: 8.0),
                     child: InputChip(
                       label: FutureBuilder<Club?>(
                         future: ClubService().getClubById(_selectedClubId!),
                         builder: (context, snap) => Text(snap.data?.name ?? 'Club Filter'),
                       ),
                       onDeleted: () => setState(() => _selectedClubId = null),
                     ),
                   ),
                 if (_selectedCity != null)
                   Padding(
                     padding: const EdgeInsets.only(right: 8.0),
                     child: InputChip(
                       label: Text('City: $_selectedCity'),
                       onDeleted: () => setState(() => _selectedCity = null),
                     ),
                   ),
                 if (_selectedState != null)
                   Padding(
                     padding: const EdgeInsets.only(right: 8.0),
                     child: InputChip(
                       label: Text('State: $_selectedState'),
                       onDeleted: () => setState(() => _selectedState = null),
                     ),
                   ),
                  TextButton(onPressed: () => setState(() {
                    _selectedCity = null; _selectedState = null; _selectedClubId = null;
                  }), child: const Text('Clear All'))
               ],
             ),
           ),

        // Event List
        Expanded(
          child: StreamBuilder<List<Event>>(
            stream: EventService().getAllEvents(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 4,
                  itemBuilder: (ctx, index) => const EventCardSkeleton(),
                );
              }
              if (snapshot.hasError) {
                return Center(
                    child: EmptyStateWidget(
                      title: 'Something went wrong',
                      message: 'Could not load events. Please try again.',
                      icon: Icons.error_outline,
                      onAction: () => setState((){}),
                      actionLabel: 'Retry',
                    ),
                  );
              }

              final allEvents = snapshot.data ?? [];
              
              // Filter events
              final events = allEvents.where((event) {
                // 1. Text Search
                bool matchesSearch = true;
                if (_searchQuery.isNotEmpty) {
                  matchesSearch = event.title.toLowerCase().contains(_searchQuery) ||
                                  event.location.toLowerCase().contains(_searchQuery) ||
                                  (event.city?.toLowerCase().contains(_searchQuery) ?? false) ||
                                  (event.state?.toLowerCase().contains(_searchQuery) ?? false);
                }
                
                // 2. Structured Filters
                bool matchesClub = _selectedClubId == null || event.clubId == _selectedClubId;
                bool matchesCity = _selectedCity == null || (event.city != null && event.city!.toLowerCase() == _selectedCity!.toLowerCase());
                bool matchesState = _selectedState == null || (event.state != null && event.state == _selectedState);
                // bool matchesEdu = ... (If we added Education filter)

                return matchesSearch && matchesClub && matchesCity && matchesState;
              }).toList();

              if (events.isEmpty) {
                return EmptyStateWidget(
                  title: _searchQuery.isEmpty ? 'No Upcoming Events' : 'No matches found',
                  message: _searchQuery.isEmpty 
                      ? 'Check back later for new activities!' 
                      : 'Try adjusting your search terms.',
                  icon: _searchQuery.isEmpty ? Icons.event_busy : Icons.search_off,
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 500));
                  setState(() {}); 
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return FadeInAnimation(
                      delay: Duration(milliseconds: index * 80),
                      child: _buildEventCard(event),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        TableCalendar<Event>(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _getEventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarStyle: CalendarStyle(
            markersMaxCount: 3,
            markerDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildCalendarEventList(),
        ),
      ],
    );
  }

  Widget _buildCalendarEventList() {
    final events = _getEventsForDay(_selectedDay!);

    if (events.isEmpty) {
      return Center(
        child: Text(
          'No events on ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(Event event) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('MMM').format(event.date).toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                DateFormat('d').format(event.date),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                event.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (event.isMandatory) 
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('MANDATORY', style: TextStyle(fontSize: 9, color: Colors.green[900], fontWeight: FontWeight.bold)),
              ),
            if (event.isLocked) 
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('LOCKED', style: TextStyle(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.bold)),
              ),
            // NEW: Attribution Tags
            if (_managedClubIds.contains(event.clubId))
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('YOUR CLUB', style: TextStyle(fontSize: 9, color: Colors.teal[900], fontWeight: FontWeight.bold)),
              )
            else if (_userProfile?.joinedClubIds.contains(event.clubId) ?? false)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('JOINED', style: TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Club Name
            FutureBuilder<Club?>(
              future: ClubService().getClubById(event.clubId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                     snapshot.data!.name.toUpperCase(),
                     style: TextStyle(
                       fontSize: 10, 
                       color: Theme.of(context).primaryColor, 
                       fontWeight: FontWeight.bold,
                       letterSpacing: 0.5
                     ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              event.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (event.signupLockDateTime != null && !event.isLocked)
             Padding(
               padding: const EdgeInsets.only(top: 4),
               child: Text(
                 'Signups lock ${DateFormat('MMM d, h:mm a').format(event.signupLockDateTime!)}',
                 style: TextStyle(fontSize: 11, color: Colors.orange[800], fontStyle: FontStyle.italic),
               ),
             ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EventDetailsScreen(event: event),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    // Temp State for Dialog
    String? tempClubId = _selectedClubId;
    String? tempState = _selectedState;
    final cityController = TextEditingController(text: _selectedCity ?? '');

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter Events'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Club Filter
                    StreamBuilder<List<Club>>(
                      stream: ClubService().getClubs(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const LinearProgressIndicator();
                        final clubs = snapshot.data!;
                        return DropdownButtonFormField<String>(
                          value: tempClubId,
                          decoration: const InputDecoration(labelText: 'Club', border: OutlineInputBorder()),
                          items: [
                             const DropdownMenuItem(value: null, child: Text('All Clubs')),
                             ...clubs.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (val) => setState(() => tempClubId = val),
                        );
                      }
                    ),
                    const SizedBox(height: 16),
                    // State Filter
                    DropdownButtonFormField<String>(
                      value: tempState,
                      decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All States')),
                        DropdownMenuItem(value: 'AL', child: Text('Alabama')),
                        DropdownMenuItem(value: 'AK', child: Text('Alaska')),
                        DropdownMenuItem(value: 'AZ', child: Text('Arizona')),
                        DropdownMenuItem(value: 'AR', child: Text('Arkansas')),
                        DropdownMenuItem(value: 'CA', child: Text('California')),
                        DropdownMenuItem(value: 'CO', child: Text('Colorado')),
                        DropdownMenuItem(value: 'CT', child: Text('Connecticut')),
                        DropdownMenuItem(value: 'DE', child: Text('Delaware')),
                        DropdownMenuItem(value: 'FL', child: Text('Florida')),
                        DropdownMenuItem(value: 'GA', child: Text('Georgia')),
                        DropdownMenuItem(value: 'HI', child: Text('Hawaii')),
                        DropdownMenuItem(value: 'ID', child: Text('Idaho')),
                        DropdownMenuItem(value: 'IL', child: Text('Illinois')),
                        DropdownMenuItem(value: 'IN', child: Text('Indiana')),
                        DropdownMenuItem(value: 'IA', child: Text('Iowa')),
                        DropdownMenuItem(value: 'KS', child: Text('Kansas')),
                        DropdownMenuItem(value: 'KY', child: Text('Kentucky')),
                        DropdownMenuItem(value: 'LA', child: Text('Louisiana')),
                        DropdownMenuItem(value: 'ME', child: Text('Maine')),
                        DropdownMenuItem(value: 'MD', child: Text('Maryland')),
                        DropdownMenuItem(value: 'MA', child: Text('Massachusetts')),
                        DropdownMenuItem(value: 'MI', child: Text('Michigan')),
                        DropdownMenuItem(value: 'MN', child: Text('Minnesota')),
                        DropdownMenuItem(value: 'MS', child: Text('Mississippi')),
                        DropdownMenuItem(value: 'MO', child: Text('Missouri')),
                        DropdownMenuItem(value: 'MT', child: Text('Montana')),
                        DropdownMenuItem(value: 'NE', child: Text('Nebraska')),
                        DropdownMenuItem(value: 'NV', child: Text('Nevada')),
                        DropdownMenuItem(value: 'NH', child: Text('New Hampshire')),
                        DropdownMenuItem(value: 'NJ', child: Text('New Jersey')),
                        DropdownMenuItem(value: 'NM', child: Text('New Mexico')),
                        DropdownMenuItem(value: 'NY', child: Text('New York')),
                        DropdownMenuItem(value: 'NC', child: Text('North Carolina')),
                        DropdownMenuItem(value: 'ND', child: Text('North Dakota')),
                        DropdownMenuItem(value: 'OH', child: Text('Ohio')),
                        DropdownMenuItem(value: 'OK', child: Text('Oklahoma')),
                        DropdownMenuItem(value: 'OR', child: Text('Oregon')),
                        DropdownMenuItem(value: 'PA', child: Text('Pennsylvania')),
                        DropdownMenuItem(value: 'RI', child: Text('Rhode Island')),
                        DropdownMenuItem(value: 'SC', child: Text('South Carolina')),
                        DropdownMenuItem(value: 'SD', child: Text('South Dakota')),
                        DropdownMenuItem(value: 'TN', child: Text('Tennessee')),
                        DropdownMenuItem(value: 'TX', child: Text('Texas')),
                        DropdownMenuItem(value: 'UT', child: Text('Utah')),
                        DropdownMenuItem(value: 'VT', child: Text('Vermont')),
                        DropdownMenuItem(value: 'VA', child: Text('Virginia')),
                        DropdownMenuItem(value: 'WA', child: Text('Washington')),
                        DropdownMenuItem(value: 'WV', child: Text('West Virginia')),
                        DropdownMenuItem(value: 'WI', child: Text('Wisconsin')),
                        DropdownMenuItem(value: 'WY', child: Text('Wyoming')),
                      ],
                      onChanged: (val) => setState(() => tempState = val),
                    ),
                    const SizedBox(height: 16),
                    // City Filter
                    TextField(
                      controller: cityController,
                      decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
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
                     // Apply Filters
                     this.setState(() {
                        _selectedClubId = tempClubId;
                        _selectedState = tempState;
                        _selectedCity = cityController.text.trim().isEmpty ? null : cityController.text.trim();
                     });
                     Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _loadCalendarEvents() {
    EventService().getAllEvents().listen((events) {
       final newEvents = <DateTime, List<Event>>{};
       for (var event in events) {
         final date = DateTime.utc(event.date.year, event.date.month, event.date.day);
         if (newEvents[date] == null) newEvents[date] = [];
         newEvents[date]!.add(event);
       }
       if (mounted) {
         setState(() {
           _calendarEvents = newEvents;
         });
       }
    });
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await UserService().getProfile(user.uid);
      final clubs = await ClubService().getClubsManagedByUser(user.uid);
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _managedClubIds = clubs.map((c) => c.id).toList();
          _isLoadingUser = false;
        });
      }
    } else {
        if(mounted) setState(() => _isLoadingUser = false);
    }
  }

  List<Event> _getEventsForDay(DateTime day) {
    return _calendarEvents[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }
}

