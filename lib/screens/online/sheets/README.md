# lib/screens/online/sheets

Bottom sheets opened from the online tab.

| File | Contents |
| --- | --- |
| `news_sheet.dart` | `showNewsSheet(context, articles:)` opens an 85%-height glass sheet listing every article: title, optional body, then source, date and time. With no articles it shows an empty state. |

The sheet does not fetch anything. `OnlineScreen` passes in the articles it
already loaded, and the sheet only renders them. It uses the shared
`showGlassSheet` / `GlassSheetFixedBody` / `GlassSheetHeader` from
`widgets/containers/glass_sheet.dart`, and the date/time formatting from
`core/utils/money.dart`.
