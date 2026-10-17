// Smoke tests for the shared feedback UI: dialog frame, inline messages,
// snack bars and the confirm / info dialogs, in every feedback kind.

import 'package:waffr/core/utils/app_feedback.dart';

import '../../helpers/widget_harness.dart';

void main() {
  for (final kind in AppFeedbackKind.values) {
    smokeTestWidget(
      AppDialogFrame,
      () => AppDialogFrame(
        title: 'title',
        message: 'message',
        kind: kind,
        actions: [
          AppDialogAction(label: 'cancel', onPressed: () {}),
          AppDialogAction(label: 'ok', primary: true, onPressed: () {}),
        ],
      ),
      name: 'AppDialogFrame (${kind.name})',
    );
    smokeTestWidget(
      AppInlineMessage,
      () => AppInlineMessage(message: 'message', kind: kind),
      name: 'AppInlineMessage (${kind.name})',
    );
    smokeTestScreen(
      'snack bar (${kind.name})',
      () => SheetLauncher(
        open: (context) => showAppSnackBar(context, 'message', kind: kind),
      ),
      interact: openSheet,
      withSampleData: false,
    );
  }
  smokeTestScreen(
    'confirm dialog',
    () => SheetLauncher(
      open: (context) => showAppConfirmDialog(
        context,
        title: 'title',
        message: 'message',
        confirmLabel: 'delete',
        destructive: true,
      ),
    ),
    interact: openSheet,
    withSampleData: false,
  );
  smokeTestScreen(
    'info dialog',
    () => SheetLauncher(
      open: (context) =>
          showAppInfoDialog(context, title: 'title', message: 'message'),
    ),
    interact: openSheet,
    withSampleData: false,
  );
  smokeTestScreen(
    'insufficient balance message',
    () => SheetLauncher(open: showInsufficientBalanceMessage),
    interact: openSheet,
    withSampleData: false,
  );
}
