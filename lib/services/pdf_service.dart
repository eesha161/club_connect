import 'package:club_connect/models/event.dart';
import 'package:club_connect/models/user_profile.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  Future<void> generateAttendancePdf({
    required Event event,
    required List<UserProfile> attendees,
    required List<String> checkedInIds,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(event.title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(DateFormat('MMM d, yyyy @ h:mm a').format(event.date)),
                    pw.Text(event.location),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Attendance List', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headers: <String>['Name', 'Email', 'Status'],
                data: attendees.map((user) {
                  final isCheckedIn = checkedInIds.contains(user.uid);
                  return [
                    user.displayName,
                    user.email,
                    isCheckedIn ? 'Checked In' : 'Pending',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Total: ${attendees.length} | Checked In: ${checkedInIds.length}'), 
            ],
          );
        },
      ),
    );

    // This opens the native print dialog which allows saving as PDF or printing
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'attendance_${event.title}.pdf',
    );
  }
}
