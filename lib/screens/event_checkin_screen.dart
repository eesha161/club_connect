import 'package:club_connect/models/event.dart';
import 'package:club_connect/services/attendance_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class EventCheckInScreen extends StatelessWidget {
  final Event event;

  const EventCheckInScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Check-In'),
      ),
      body: DefaultTabBarController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Show QR Code', icon: Icon(Icons.qr_code)),
                Tab(text: 'Scan QR Code', icon: Icon(Icons.qr_code_scanner)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildQRCodeTab(context),
                  _buildScannerTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeTab(BuildContext context) {
    // Generate QR code data: eventId
    final qrData = 'clubconnect://checkin/${event.id}';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            event.title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            'Show this QR code to check in',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 250.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () async {
              await _manualCheckIn(context);
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('Manual Check-In'),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTab(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            onDetect: (capture) async {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  final qrData = barcode.rawValue!;
                  if (qrData.startsWith('clubconnect://checkin/')) {
                    final eventId = qrData.split('/').last;
                    if (eventId == event.id) {
                      await _manualCheckIn(context);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  }
                }
              }
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: const Text(
            'Scan attendee QR codes to check them in',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Future<void> _manualCheckIn(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login first')),
          );
        }
        return;
      }

      // Check if already checked in
      final hasCheckedIn = await AttendanceService().hasCheckedIn(event.id, user.uid);
      if (hasCheckedIn) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Already checked in!')),
          );
        }
        return;
      }

      // Get user profile for name
      final profile = await UserService().getProfile(user.uid);

      // Check in
      await AttendanceService().checkIn(
        eventId: event.id,
        userId: user.uid,
        userName: profile?.displayName ?? 'Unknown',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Checked in successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
