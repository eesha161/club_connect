import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
// This service handles sending alerts to the user's inbox.
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin _notificationsPlugin = fln.FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const androidSettings = fln.AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = fln.DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const settings = fln.InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        if (kDebugMode) {
        }
      },
    );

    // Request permission for Firebase Messaging (Remote)
    await _firebaseMessaging.requestPermission();
  }

  // --- Local Notifications (Reminders) ---

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) {
        return;
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'event_reminders', 
            'Event Reminders',
            channelDescription: 'Notifications for upcoming events',
            importance: fln.Importance.max,
            priority: fln.Priority.high,
          ),
          iOS: fln.DarwinNotificationDetails(),
        ),
        // uiLocalNotificationDateInterpretation: fln.UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  // --- FCM Topic Subscriptions (Club Announcements) ---

  Future<void> subscribeToClub(String clubId) async {
    try {
      await _firebaseMessaging.subscribeToTopic('club_$clubId');
    } catch (e) {
    }
  }

  Future<void> unsubscribeFromClub(String clubId) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic('club_$clubId');
    } catch (e) {
    }
  }
}
