import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/course_registration_model.dart';

class CourseRegistrationPdfService {
  Future<Uint8List> buildPdf({
    required String studentId,
    required String phoneNumber,
    required String fullName,
    required String facultyName,
    required String programName,
    required int level,
    required String academicYear,
    required String session,
    required String termLabel,
    required int term,
    required DateTime generatedAt,
    required String recipientLabel,
    required List<RegisteredCourse> courses,
  }) async {
    final document = pw.Document();
    final totalCreditHours =
        courses.fold<int>(0, (total, course) => total + course.creditHours);
    final timestamp =
        '${generatedAt.day.toString().padLeft(2, '0')}/${generatedAt.month.toString().padLeft(2, '0')}/${generatedAt.year} '
        '${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Container(
            color: PdfColor.fromInt(0xFF32145B),
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: pw.Text(
              'REGENT UNIVERSITY COLLEGE OF SCIENCE AND TECHNOLOGY',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            facultyName.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'COURSE REGISTRATION FORM',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15),
          ),
          pw.SizedBox(height: 18),
          _detailsTable([
            ['Student ID', studentId, 'Telephone number', phoneNumber],
            ['Student full name', fullName, '', ''],
            ['Programme', programName, 'Year of study', 'Level $level'],
            ['Academic year', academicYear, 'Session', session],
            ['Term', '$term${_ordinal(term)} $termLabel', 'Generated', timestamp],
            ['Routed to', recipientLabel, '', ''],
          ]),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: const ['#', 'Course code', 'Course title', 'Credit hours'],
            data: [
              ...courses.asMap().entries.map(
                    (entry) => [
                      '${entry.key + 1}',
                      entry.value.code,
                      entry.value.title,
                      '${entry.value.creditHours}',
                    ],
                  ),
              ['', '', 'TOTAL', '$totalCreditHours'],
            ],
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {0: pw.Alignment.center, 3: pw.Alignment.center},
            border: pw.TableBorder.all(color: PdfColors.grey600, width: .5),
          ),
          pw.SizedBox(height: 30),
          pw.Row(
            children: [
              pw.Expanded(child: _signatureLine('Student signature')),
              pw.SizedBox(width: 30),
              pw.Expanded(child: _signatureLine('HoD / Faculty officer')),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'This registration was generated in RegentConnect and submitted for review.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<void> download(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);

  Future<void> print(Uint8List bytes) =>
      Printing.layoutPdf(onLayout: (_) async => bytes);

  pw.Widget _detailsTable(List<List<String>> rows) => pw.TableHelper.fromTextArray(
        data: rows,
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellPadding: const pw.EdgeInsets.all(5),
        border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
        columnWidths: const {
          0: pw.FixedColumnWidth(78),
          1: pw.FlexColumnWidth(2),
          2: pw.FixedColumnWidth(78),
          3: pw.FlexColumnWidth(1.5),
        },
      );

  pw.Widget _signatureLine(String label) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(height: 24, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide()))),
          pw.SizedBox(height: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        ],
      );

  static String _ordinal(int value) => value == 1 ? 'st' : value == 2 ? 'nd' : value == 3 ? 'rd' : 'th';
}
