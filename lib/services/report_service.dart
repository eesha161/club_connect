import 'package:club_connect/models/inbox_message.dart';
import 'package:club_connect/services/attendance_service.dart';
import 'package:club_connect/services/inbox_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportService {
  final _userService = UserService();
  final _attendanceService = AttendanceService();
  final _inboxService = InboxService();

  Future<void> checkAndSendWeeklyReport(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastReportKey = 'last_report_date_$userId';
      final lastReportStr = prefs.getString(lastReportKey);

      DateTime? lastReportDate;
      if (lastReportStr != null) {
        lastReportDate = DateTime.tryParse(lastReportStr);
      }

      // Check if 7 days have passed (or if never sent)
      if (lastReportDate == null ||
          DateTime.now().difference(lastReportDate).inDays >= 7) {
        
        await _generateAndSendReport(userId);
        
        // Update stored date
        await prefs.setString(lastReportKey, DateTime.now().toIso8601String());
      }
    } catch (e) {
    }
  }

  Future<void> _generateAndSendReport(String userId) async {
    // Fetch stats
    final profile = await _userService.getProfile(userId);
    final attendance = await _attendanceService.getUserAttendance(userId).first;
    
    final clubCount = profile?.joinedClubIds.length ?? 0;
    final eventCount = attendance.length;
    final badgeCount = profile?.badges.length ?? 0;

    // Create report message
    final report = InboxMessage(
      id: '',
      title: 'Weekly Activity Summary',
      body: 'Here is your summary for the past week:\n\n'
            '• Active Clubs: $clubCount\n'
            '• Total Events Attended: $eventCount\n'
            '• Badges Earned: $badgeCount\n\n'
            'Check out new events to keep your streak alive!',
      timestamp: DateTime.now(),
      type: 'summary',
    );

    // Send to Inbox
    await _inboxService.addMessage(userId, report);
  }
}
