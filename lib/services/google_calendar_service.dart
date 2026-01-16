import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:club_connect/models/event.dart';

class GoogleCalendarService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [calendar.CalendarApi.calendarScope],
  );

  /// Add an event to the user's Google Calendar
  Future<bool> addEventToCalendar(Event event) async {
    try {
      // Sign in to Google
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return false;

      // Get authenticated client
      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient == null) return false;

      // Create Calendar API instance
      final calendarApi = calendar.CalendarApi(authClient);

      // Create calendar event
      final calendarEvent = calendar.Event()
        ..summary = event.title
        ..description = event.description
        ..location = event.location
        ..start = calendar.EventDateTime(
          dateTime: event.startTime,
          timeZone: 'America/Chicago', // Adjust based on user timezone
        )
        ..end = calendar.EventDateTime(
          dateTime: event.endTime,
          timeZone: 'America/Chicago',
        );

      // Insert event into primary calendar
      await calendarApi.events.insert(calendarEvent, 'primary');
      
      return true;
    } catch (e) {
      // Handle errors silently - user can still use app without calendar sync
      return false;
    }
  }

  /// Sign out from Google Calendar
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
