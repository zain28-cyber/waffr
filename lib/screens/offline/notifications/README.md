# Notifications

| File | Main entry point | What it is |
| --- | --- | --- |
| `notifications_screen.dart` | `NotificationsScreen` | The in-app alert history page. |

`NotificationsScreen` is pushed from the app shell's bell button. It shows:

- header actions to mark all alerts read and to clear the history (behind a
  confirm dialog; balance, savings, goals and the mute setting are kept);
- a mute toggle (`NotificationService.toggleMuted`); while muted, no new
  alerts are added to the history;
- a banner, shown only when the phone blocks Waffr's notifications, that
  asks for permission through `SystemNotifications`; if the phone no longer
  shows the prompt it explains how to enable it in the phone settings;
- the history bucketed by calendar day (`NotificationTimeGroup.from`),
  each tile swipeable to delete.

Data comes from `NotificationService` (`notifications`, `unreadCount`,
`markRead`, `remove`, `clearHistory`); the screen rebuilds from it. Tapping
an alert marks it read; obligation alerts also open
`showDueObligationsSheet` or `showObligationsSheet` from
`screens/offline/obligations`.

The permission is re-checked when the app resumes (the screen is a
`WidgetsBindingObserver`). Only the first screenful of groups animates in,
and only during the first 700 ms after opening.
