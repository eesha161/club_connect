import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Simple service to trigger notifications via HTTP Cloud Function
/// This is a workaround for sending notifications without a full backend
class CloudFunctionService {
  // TODO: Replace with your actual Cloud Function URL after deployment
  static const String _functionUrl = 'YOUR_CLOUD_FUNCTION_URL_HERE';
  
  /// Send notification when announcement is posted
  Future<bool> sendAnnouncementNotification({
    required String clubId,
    required String title,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_functionUrl/sendAnnouncementNotification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'clubId': clubId,
          'title': title,
          'message': message,
        }),
      );
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Announcement notification sent');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Failed to send notification: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending notification: $e');
      }
      return false;
    }
  }
  
  /// Send notification when event is created
  Future<bool> sendEventNotification({
    required String clubId,
    required String eventTitle,
    required String eventDate,
    required String eventLocation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_functionUrl/sendEventNotification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'clubId': clubId,
          'eventTitle': eventTitle,
          'eventDate': eventDate,
          'eventLocation': eventLocation,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending event notification: $e');
      }
      return false;
    }
  }
}
