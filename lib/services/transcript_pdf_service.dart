import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/academic_result_model.dart';

class TranscriptPdfService {
  Future<Uint8List> buildTranscript({
    required String studentId,
    required String studentName,
    required String programName,
    required String facultyName,
    required List<AcademicResultModel> results,
    required DateTime generatedAt,
    required String scopeLabel,
  }) async {
    final document = pw.Document();
    final grouped = <int, Map<int, List<AcademicResultModel>>>{};
    for (final result in results) {
      grouped
          .putIfAbsent(result.level, () => <int, List<AcademicResultModel>>{})
          .putIfAbsent(result.semester, () => <AcademicResultModel>[])
          .add(result);
    }
    final cwa = _weightedAverage(results);
    final levels = grouped.keys.toList()..sort();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 28),
        header: (_) => _header(
          studentId: studentId,
          studentName: studentName,
          programName: programName,
          generatedAt: generatedAt,
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'RegentConnect provisional transcript • Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 10),
          pw.Text(
            facultyName.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 9),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF4F0F9),
              border: pw.Border.all(color: PdfColor.fromInt(0xFF32145B), width: .5),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(child: pw.Text('Transcript scope: $scopeLabel', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                pw.Text('CWA: ${cwa.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          if (results.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 60),
              child: pw.Center(child: pw.Text('No published results match this transcript selection.')),
            )
          else
            ...levels.map(
              (level) => _levelSection(level, grouped[level]!),
            ),
        ],
      ),
    );
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 28),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(studentId: studentId, studentName: studentName, programName: programName, generatedAt: generatedAt),
            pw.SizedBox(height: 22),
            pw.Center(child: pw.Text('CUMULATIVE WEIGHTED AVERAGE (CWA): ${cwa.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 42),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _gradingKey()),
                pw.SizedBox(width: 24),
                pw.Expanded(child: _degreeClassKey()),
              ],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey700),
            pw.SizedBox(height: 6),
            pw.Text('This computer-generated provisional transcript is intended for student reference. It remains subject to Academic Unit verification.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 6),
            pw.Text('Generated via RegentConnect on ${_dateTime(generatedAt)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      ),
    );
    return document.save();
  }

  Future<void> print(Uint8List bytes) => Printing.layoutPdf(onLayout: (_) async => bytes);

  Future<void> download(Uint8List bytes, String fileName) => Printing.sharePdf(bytes: bytes, filename: fileName);

  pw.Widget _header({required String studentId, required String studentName, required String programName, required DateTime generatedAt}) => pw.Column(
        children: [
          pw.Row(
            children: [
              pw.Expanded(child: pw.Text('REGENT UNIVERSITY COLLEGE OF SCIENCE AND TECHNOLOGY', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.Container(
                width: 45,
                height: 45,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, border: pw.Border.all(color: PdfColor.fromInt(0xFF32145B), width: 2)),
                child: pw.Text('RU', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF32145B))),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Text('INDEX NO.: $studentId', style: const pw.TextStyle(fontSize: 9)),
            pw.Spacer(),
            pw.Text(_dateTime(generatedAt), style: const pw.TextStyle(fontSize: 9)),
          ]),
          pw.Divider(color: PdfColors.black, thickness: 1.2),
          pw.Text('(PROVISIONAL TRANSCRIPT)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(studentName.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
          pw.SizedBox(height: 6),
          pw.Text('$studentName is enrolled in $programName and has completed the published examinations shown below.', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
          pw.Divider(color: PdfColors.black, thickness: 1.2),
        ],
      );

  pw.Widget _levelSection(
    int level,
    Map<int, List<AcademicResultModel>> terms,
  ) {
    final semesterNumbers = terms.keys.toList()..sort();
    return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 18),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('LEVEL $level EXAMINATION', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 7),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: semesterNumbers
                  .map(
                    (semester) => pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 8),
                        child: _termTable(semester, terms[semester]!),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
  }

  pw.Widget _termTable(int term, List<AcademicResultModel> results) {
    final swa = _weightedAverage(results);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('${_ordinal(term)} SEMESTER', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: const ['Course title', 'Mark', 'Gr.', 'Cr.'],
          data: results.map((result) => [
            '${result.courseCode}: ${result.courseName}',
            result.score.toStringAsFixed(0),
            result.grade,
            '${result.creditHours}',
          ]).toList(),
          headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          border: const pw.TableBorder(),
          columnWidths: const {0: pw.FlexColumnWidth(5), 1: pw.FixedColumnWidth(25), 2: pw.FixedColumnWidth(20), 3: pw.FixedColumnWidth(20)},
        ),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Semester Weighted Average: ${swa.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
      ],
    );
  }

  pw.Widget _gradingKey() => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('KEY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
        pw.SizedBox(height: 8),
        _keyRow('70% and Above', 'A'),
        _keyRow('60% - 69%', 'B'),
        _keyRow('50% - 59%', 'C'),
        _keyRow('40% - 49%', 'D'),
        _keyRow('Below 40%', 'Fail'),
      ]);

  pw.Widget _degreeClassKey() => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('CLASSES OF DEGREE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
        pw.SizedBox(height: 8),
        pw.Text('First Class', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 5),
        pw.Text('Second Class (Upper Division)', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 5),
        pw.Text('Second Class (Lower Division)', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 5),
        pw.Text('Third Class', style: const pw.TextStyle(fontSize: 9)),
      ]);

  pw.Widget _keyRow(String range, String grade) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5), child: pw.Row(children: [pw.Expanded(child: pw.Text(range, style: const pw.TextStyle(fontSize: 9))), pw.Text(grade, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))]));

  double _weightedAverage(List<AcademicResultModel> results) {
    if (results.isEmpty) return 0;
    var totalCredit = 0;
    var weightedScore = 0.0;
    for (final result in results) {
      totalCredit += result.creditHours;
      weightedScore += result.score * result.creditHours;
    }
    return totalCredit == 0 ? 0 : weightedScore / totalCredit;
  }

  String _ordinal(int number) => number == 1 ? 'FIRST' : number == 2 ? 'SECOND' : number == 3 ? 'THIRD' : '$number${number == 4 ? 'TH' : 'TH'}';
  String _dateTime(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
