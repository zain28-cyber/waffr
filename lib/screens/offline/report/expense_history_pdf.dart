// Lays out the expense-history PDF: header with the brand, one table per
// day, and the grand total. The layout and `document.save()` run in a
// background isolate; only the font and logo assets are read on the UI
// isolate, because the asset bundle lives there.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/screens/offline/report/expense_history_format.dart';

/// Everything the background isolate needs to draw the PDF.
class ExpenseHistoryPdfJob {
  /// Bundles the rows, the asset bytes and the footer time.
  const ExpenseHistoryPdfJob({
    required this.expenses,
    required this.regularFont,
    required this.boldFont,
    required this.brandFont,
    required this.logo,
    required this.generatedAt,
  });

  /// The chosen expenses, in any order.
  final List<WaffrTransaction> expenses;

  /// Tajawal Regular, used for body text.
  final Uint8List regularFont;

  /// Tajawal Bold, used for titles, amounts and totals.
  final Uint8List boldFont;

  /// Bebas Neue, used for the "WAFFR" wordmark.
  final Uint8List brandFont;

  /// The app logo PNG.
  final Uint8List logo;

  /// Shown in the footer ("أُنشئ في ...").
  final DateTime generatedAt;
}

/// The PDF bytes for [expenses]. Reads the assets here, then renders in a
/// background isolate (`compute`, which is `Isolate.run` on phones).
Future<Uint8List> buildExpenseHistoryPdfBytes(
  List<WaffrTransaction> expenses,
) async {
  // Raw bytes of a bundled asset.
  Future<Uint8List> asset(String path) async =>
      (await rootBundle.load(path)).buffer.asUint8List();

  final job = ExpenseHistoryPdfJob(
    expenses: List.of(expenses),
    regularFont: await asset('fonts/Tajawal-Regular.ttf'),
    boldFont: await asset('fonts/Tajawal-Bold.ttf'),
    brandFont: await asset('fonts/BebasNeue-Regular.ttf'),
    logo: await asset('assets/brand/waffr_logo.png'),
    generatedAt: DateTime.now(),
  );
  return compute(renderExpenseHistoryPdf, job, debugLabel: 'expense PDF');
}

/// Draws and saves the document. Pure function of [job]; it runs in a
/// background isolate. Category names come from [categoryFor], whose label
/// is the stored label (or "أخرى"), so the custom-category lookup that
/// only exists on the UI isolate is not needed here.
Future<Uint8List> renderExpenseHistoryPdf(ExpenseHistoryPdfJob job) async {
  // Fonts and logo are decoded inside the isolate from the job's bytes.
  final fonts = _PdfFonts(
    regular: pw.Font.ttf(ByteData.sublistView(job.regularFont)),
    bold: pw.Font.ttf(ByteData.sublistView(job.boldFont)),
    brand: pw.Font.ttf(ByteData.sublistView(job.brandFont)),
  );
  final logo = pw.MemoryImage(job.logo);
  final days = groupExpensesForShare(job.expenses);
  final document = pw.Document(title: 'سجل المصروفات', author: 'WAFFR');

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
      maxPages: 500,
      header: (context) => _pdfHeader(
        logo: logo,
        fonts: fonts,
        days: days,
        count: job.expenses.length,
      ),
      footer: (context) =>
          _pdfFooter(context, fonts: fonts, generatedAt: job.generatedAt),
      build: (context) => [
        for (final day in days) ...[
          _pdfDayCaption(day, fonts),
          pw.SizedBox(height: 6),
          _pdfDayTable(day, fonts),
          pw.SizedBox(height: 16),
        ],
        _pdfGrandTotal(job.expenses, fonts),
      ],
    ),
  );

  // A broken save must not reach the share sheet as an empty file.
  final bytes = await document.save();
  if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
    throw StateError('PDF bytes are empty or not a PDF');
  }
  return bytes;
}

/// The three faces the document uses.
class _PdfFonts {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font brand;

  const _PdfFonts({
    required this.regular,
    required this.bold,
    required this.brand,
  });
}

/// Brand green from the Waffr light theme; titles, totals and rules.
final PdfColor _brandGreen = PdfColor.fromInt(0xFF254A23);

/// Fill of odd (striped) table rows.
final PdfColor _rowTint = PdfColor.fromInt(0xFFF6F8F4);

/// Fill of table header rows, chips and the grand-total box.
final PdfColor _headerTint = PdfColor.fromInt(0xFFE9EFE6);

/// Table line colour.
final PdfColor _rule = PdfColor.fromInt(0xFFDCE3D8);

/// Secondary text colour.
final PdfColor _muted = PdfColor.fromInt(0xFF6F6F6F);

/// Column order is left to right on paper: amount, time, category. The
/// document reads right to left, so category is the first column the eye
/// meets.
const Map<int, pw.TableColumnWidth> _columnWidths = {
  0: pw.FlexColumnWidth(3),
  1: pw.FlexColumnWidth(1.6),
  2: pw.FlexColumnWidth(5),
};

/// Title, date range and count on the right; logo and wordmark on the left.
pw.Widget _pdfHeader({
  required pw.ImageProvider logo,
  required _PdfFonts fonts,
  required List<ExpenseShareDay> days,
  required int count,
}) {
  final range = days.isEmpty
      ? ''
      : days.length == 1
      ? formatDate(days.first.date)
      : 'من ${formatDate(days.last.date)} إلى ${formatDate(days.first.date)}';

  return pw.Column(
    children: [
      // Title block, then the logo and wordmark (kept LTR).
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'سجل المصروفات',
                  style: pw.TextStyle(font: fonts.bold, fontSize: 20),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  [
                    if (range.isNotEmpty) range,
                    '$count ${count == 1 ? 'مصروف' : 'مصروفات'}',
                  ].join('  ·  '),
                  style: pw.TextStyle(
                    font: fonts.regular,
                    fontSize: 10.5,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(logo, width: 34, height: 34),
                pw.SizedBox(width: 6),
                // The app draws the title as a slanted Bebas Neue.
                pw.Transform(
                  transform: Matrix4.skewX(0.21),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'WAFFR',
                    textDirection: pw.TextDirection.ltr,
                    style: pw.TextStyle(
                      font: fonts.brand,
                      fontSize: 30,
                      color: _brandGreen,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Container(height: 1.4, color: _brandGreen),
      pw.SizedBox(height: 14),
    ],
  );
}

/// When the file was made, and the page count.
pw.Widget _pdfFooter(
  pw.Context context, {
  required _PdfFonts fonts,
  required DateTime generatedAt,
}) {
  final style = pw.TextStyle(font: fonts.regular, fontSize: 9, color: _muted);
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            'أُنشئ في ${formatDate(generatedAt)} ${formatTime(generatedAt)}',
            style: style,
          ),
        ),
        pw.Text(
          'صفحة ${context.pageNumber} من ${context.pagesCount}',
          style: style,
        ),
      ],
    ),
  );
}

/// "اليوم" / "أمس" / a date, with the full date beside relative labels.
pw.Widget _pdfDayCaption(ExpenseShareDay day, _PdfFonts fonts) {
  final label = expenseShareDayLabel(day.date);
  final date = formatDate(day.date);
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Expanded(
        child: pw.Text(
          label,
          style: pw.TextStyle(
            font: fonts.bold,
            fontSize: 13,
            color: _brandGreen,
          ),
        ),
      ),
      // Relative labels get the full date beside them; dated labels already
      // carry it.
      if (!label.contains('${day.date.year}') || label == date)
        pw.Text(
          date,
          style: pw.TextStyle(font: fonts.regular, fontSize: 10, color: _muted),
        ),
    ],
  );
}

/// Header row (repeated on page breaks), striped expense rows, day total.
pw.Widget _pdfDayTable(ExpenseShareDay day, _PdfFonts fonts) {
  // Padded, aligned table cell.
  pw.Widget cell(
    pw.Widget child, {
    pw.Alignment alignment = pw.Alignment.centerRight,
  }) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: child,
    );
  }

  final headStyle = pw.TextStyle(
    font: fonts.bold,
    fontSize: 9.5,
    color: _muted,
  );
  final bodyStyle = pw.TextStyle(font: fonts.regular, fontSize: 10.5);
  final amountStyle = pw.TextStyle(font: fonts.bold, fontSize: 10.5);

  return pw.Table(
    columnWidths: _columnWidths,
    border: pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _rule, width: 0.6),
      bottom: pw.BorderSide(color: _rule, width: 0.6),
    ),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      // Header row, repeated when the table breaks across pages.
      pw.TableRow(
        repeat: true,
        decoration: pw.BoxDecoration(color: _headerTint),
        children: [
          cell(
            pw.Text('المبلغ', style: headStyle),
            alignment: pw.Alignment.centerLeft,
          ),
          cell(
            pw.Text('الوقت', style: headStyle),
            alignment: pw.Alignment.center,
          ),
          cell(pw.Text('التصنيف', style: headStyle)),
        ],
      ),
      // One striped row per expense.
      for (var i = 0; i < day.expenses.length; i++)
        pw.TableRow(
          decoration: i.isOdd ? pw.BoxDecoration(color: _rowTint) : null,
          children: [
            cell(
              pw.Text(expenseAmountText(day.expenses[i]), style: amountStyle),
              alignment: pw.Alignment.centerLeft,
            ),
            cell(
              pw.Text(
                formatTime(day.expenses[i].dateTime),
                textDirection: pw.TextDirection.ltr,
                style: bodyStyle,
              ),
              alignment: pw.Alignment.center,
            ),
            cell(_pdfCategoryCell(day.expenses[i], fonts)),
          ],
        ),
      // Day total row.
      pw.TableRow(
        children: [
          cell(
            pw.Text(
              expenseTotalsText(day.expenses),
              style: pw.TextStyle(
                font: fonts.bold,
                fontSize: 11,
                color: _brandGreen,
              ),
            ),
            alignment: pw.Alignment.centerLeft,
          ),
          cell(pw.SizedBox()),
          cell(
            pw.Text(
              'مجموع اليوم',
              style: pw.TextStyle(font: fonts.bold, fontSize: 10.5),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Category name, a "متكرر" chip for scheduled charges, and the note.
pw.Widget _pdfCategoryCell(WaffrTransaction expense, _PdfFonts fonts) {
  final note = expense.note?.trim() ?? '';
  final recurring = RecurringExpense.isRecurringSource(expense.sourceId);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            categoryFor(expense.category).label,
            style: pw.TextStyle(font: fonts.bold, fontSize: 10.5),
          ),
          if (recurring) ...[
            pw.SizedBox(width: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              decoration: pw.BoxDecoration(
                color: _headerTint,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'متكرر',
                style: pw.TextStyle(
                  font: fonts.bold,
                  fontSize: 8,
                  color: _brandGreen,
                ),
              ),
            ),
          ],
        ],
      ),
      if (note.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Text(
            note,
            style: pw.TextStyle(
              font: fonts.regular,
              fontSize: 9,
              color: _muted,
            ),
          ),
        ),
    ],
  );
}

/// The boxed total at the end of the document.
pw.Widget _pdfGrandTotal(List<WaffrTransaction> expenses, _PdfFonts fonts) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: pw.BoxDecoration(
      color: _headerTint,
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: _brandGreen, width: 0.8),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            'المجموع',
            style: pw.TextStyle(font: fonts.bold, fontSize: 13),
          ),
        ),
        pw.Text(
          expenseTotalsText(expenses),
          style: pw.TextStyle(
            font: fonts.bold,
            fontSize: 13,
            color: _brandGreen,
          ),
        ),
      ],
    ),
  );
}
