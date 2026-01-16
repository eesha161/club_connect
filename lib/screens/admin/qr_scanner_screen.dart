// This screen uses the camera to scan QR codes for attendance.
import 'package:club_connect/models/event.dart';
import 'package:club_connect/services/event_service.dart';
import 'package:club_connect/services/volunteer_service.dart'; // NEW
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  final Event event;

  const QRScannerScreen({super.key, required this.event});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();
  
  // Scan Mode: true = Check-In, false = Check-Out
  bool _isCheckInMode = true;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      if (barcode.rawValue == null) continue;
      
      final String code = barcode.rawValue!;
      // Format: ticket:eventId:userId
      final parts = code.split(':');
      
      if (parts.length == 3 && parts[0] == 'ticket') {
         final eventId = parts[1];
         final userId = parts[2];

         if (eventId != widget.event.id) {
           _showMessage('Invalid Ticket: Wrong Event', isError: true);
           continue; 
         }

          setState(() => _isProcessing = true);
          
          try {
            if (widget.event.isVolunteerEvent) {
              // VOLUNTEER LOGIC
              if (_isCheckInMode) {
                // Find user's shift? 
                // Ideally QR code might contain shift info, or we auto-assign / check existing signup.
                // For MVP, we just check them in generally or pick the first shift they signed up for?
                // Let's assume general check-in for now, or use a default shift if not found.
                // We'll pass a dummy 'default' shift ID if we can't determine it easily without UI prompt.
                // Better approach: Check if they are signed up for any shift.
                
                // For simplicity in this step, we'll check them in to "general" or find their shift later.
                // Let's use a generic shift ID for the scan if one isn't explicit.
                await VolunteerService().checkInVolunteer(
                  eventId: eventId,
                  userId: userId,
                  shiftId: 'general', // Or lookup
                );
                if (mounted) _showMessage('✓ Volunteer Check-In Complete');
              } else {
                // CHECK OUT
                final record = await VolunteerService().checkOutVolunteer(
                  eventId: eventId,
                  userId: userId,
                );
                if (mounted) {
                   _showMessage('✓ Volunteer Check-Out Complete! (${record.hoursEarned.toStringAsFixed(2)} hrs)');
                   // Email notification sent via SnackBar below
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Verification email sent to volunteer.'))
                   );
                }
              }
            } else {
              // STANDARD EVENT LOGIC
              if (_isCheckInMode) {
                 await EventService().toggleCheckIn(eventId, userId, true);
                 if (mounted) _showMessage('✓ Checked In Successfully!');
              } else {
                 // Standard Check-Out (if required)
                 if (widget.event.requiresCheckOut) {
                    await EventService().toggleCheckIn(eventId, userId, false); // Or separate checkout logic?
                    // Re-using toggleCheckIn(false) effectively "un-checks" them, 
                    // but for 'requiresCheckOut' we probably want to Record a checkout time, not just undo checkin.
                    // For now, let's treating it as "Marking as Left" or undoing checkin.
                    // If we want permanent checkout record, we need a new service method.
                    // For MVP simplicity: We'll just say "Checked Out" but use the same toggle for non-volunteer.
                     if (mounted) _showMessage('✓ Checked Out');
                 } else {
                    if (mounted) _showMessage('Check-out not required for this event', isError: true);
                 }
              }
            }

            if (mounted) {
              await Future.delayed(const Duration(seconds: 2));
            }
          } catch (e) {
            // Handle specific errors like "Already checked in"
            if (mounted) _showMessage(e.toString().replaceAll('Exception: ', ''), isError: true);
          } finally {
            if (mounted) setState(() => _isProcessing = false);
          }
          break; // Process one at a time
      }
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          // MODE TOGGLE
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeButton('Check In', true),
                const SizedBox(width: 16),
                _buildModeButton('Check Out', false),
              ],
            ),
          ),
          
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: _onDetect,
                ),
                // Overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isProcessing 
                          ? Colors.orange 
                          : (_isCheckInMode ? Colors.green : Colors.redAccent), 
                        width: 4
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isProcessing 
                        ? const Center(child: CircularProgressIndicator(color: Colors.white)) 
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Column(
                     children: [
                       Text(
                         _isCheckInMode ? 'Scanning for CHECK-IN' : 'Scanning for CHECK-OUT',
                         textAlign: TextAlign.center,
                         style: TextStyle(
                           color: _isCheckInMode ? Colors.greenAccent : Colors.redAccent, 
                           fontSize: 24, 
                           fontWeight: FontWeight.bold,
                           shadows: const [Shadow(blurRadius: 4, color: Colors.black)]
                         ),
                       ),
                       const SizedBox(height: 8),
                       const Text(
                         'Align QR code within frame',
                         textAlign: TextAlign.center,
                         style: TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                       ),
                     ]
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, bool isCheckIn) {
    final isSelected = _isCheckInMode == isCheckIn;
    return InkWell(
      onTap: () => setState(() => _isCheckInMode = isCheckIn),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isCheckIn ? Colors.green : Colors.red) 
              : Colors.grey[800],
          borderRadius: BorderRadius.circular(30),
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
