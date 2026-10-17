// Shares the selected expenses as a PDF or as plain text through the system
// share sheet. Event times stay the ones stored on each record.
//
// The text and PDF builders live in expense_history_format.dart and
// expense_history_pdf.dart; both are re-exported here so callers keep one
// import.

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/screens/offline/report/expense_history_format.dart';
import 'package:waffr/screens/offline/report/expense_history_pdf.dart';

export 'package:waffr/screens/offline/report/expense_history_format.dart';
export 'package:waffr/screens/offline/report/expense_history_pdf.dart';

/// Opens the share sheet with the plain-text export of [expenses].
Future<void> shareExpenseHistoryText(List<WaffrTransaction> expenses) {
  return SharePlus.instance.share(
    ShareParams(text: buildExpenseHistoryText(expenses)),
  );
}

/// Builds the PDF off the UI isolate, saves it to the temp folder, and
/// opens the share sheet. Errors are logged and rethrown for the caller's
/// snack bar.
Future<void> shareExpenseHistoryPdf(List<WaffrTransaction> expenses) async {
  try {
    final bytes = await buildExpenseHistoryPdfBytes(expenses);

    // Save to a fresh file and check it really landed before sharing.
    final folder = Directory(
      '${(await getTemporaryDirectory()).path}/shared_pdfs',
    );
    await folder.create(recursive: true);
    final file = File(
      '${folder.path}/waffr-expenses-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    final saved = await file.length();
    if (!await file.exists() || saved != bytes.length || saved <= 0) {
      throw StateError('PDF was not saved at ${file.path}');
    }
    developer.log(
      'PDF saved path=${file.path} bytes=$saved',
      name: 'waffr.pdf',
    );
    await _sharePdfFile(file);
  } catch (error, stack) {
    developer.log(
      'PDF share failed',
      name: 'waffr.pdf',
      error: error,
      stackTrace: stack,
    );
    rethrow;
  }
}

/// Android shares through a small native channel (it grants read access to
/// the file); everything else, and any channel failure, uses share_plus.
Future<void> _sharePdfFile(File file) async {
  if (Platform.isAndroid) {
    try {
      const channel = MethodChannel('waffr/share_pdf');
      await channel.invokeMethod<void>('share', {'path': file.path});
      return;
    } catch (error, stack) {
      developer.log(
        'Android PDF channel failed, falling back to share_plus',
        name: 'waffr.pdf',
        error: error,
        stackTrace: stack,
      );
    }
  }
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(
          file.path,
          mimeType: 'application/pdf',
          name: 'waffr-expenses.pdf',
        ),
      ],
      fileNameOverrides: const ['waffr-expenses.pdf'],
    ),
  );
}
