# lib/screens/offline/placeholder

| File | Contents |
| --- | --- |
| `placeholder.dart` | `PlaceholderScreen(label:)`: a stub page that shows its label centered. It is kept alive (`AutomaticKeepAliveClientMixin`) so it behaves like a real tab in the shell pager. |

Use it to fill a tab or a pushed route while the real screen is not built.
Nothing in `lib/` uses it at the moment. Only its widget test
(`test/screens/offline/placeholder/placeholder_test.dart`) does.

It holds no state and reads no stores. If you drop it into `_tabAt` in
`shell/app_shell.dart`, the shell still wraps it in the same `TickerMode` and
`ExcludeSemantics` handling as every other tab.
