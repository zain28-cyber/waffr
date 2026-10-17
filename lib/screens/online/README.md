# lib/screens/online

The online tab (page 3 of the shell pager): an exchange-rate card, nearby
place shortcuts, and a news preview. It is the only tab that needs the
network, and it is gated on sign-in.

`online_screen.dart` is one library split into part files. Only
`online_screen.dart` has imports; the others start with
`part of 'online_screen.dart'` and hold private widgets.

| File | Contents |
| --- | --- |
| `online_screen.dart` | `OnlineScreen` (library root): loads news, lays out the three cards, and covers them for guests. |
| `online_cards.dart` | `_SignInGate` (guest cover with a sign-in button) and `_NearbyPlacesCard` (category grid). |
| `online_exchange_rates.dart` | `_ExchangeRateCard`, its overlay currency menu, and the buy/sell figures. |
| `online_news.dart` | `_NewsPreviewCard`: vertical headline pager, page dots, loading/empty/error copy. |
| `sheets/` | `showNewsSheet`, the full news list. |

How it connects:

- `AppShell` builds `OnlineScreen` lazily as tab 3; it keeps itself alive.
- `ProfileIdentity` decides the gate. Guests see the cards blurred under
  `_SignInGate`, and nothing is fetched. The gate pushes `LoginScreen`
  (`allowGuest: false`, `popOnSuccess: true`) and lifts once sign-in lands.
- News comes from `OnlineFeedService.fetchArticles` on sign-in and on every
  app resume. A failed refresh keeps the articles already shown.
- Rates come from `OnlineFeedService.rates` / `rateFor`. They are
  placeholders for now, so the figures show `ExchangeRate.unavailable`.
- Nearby places use `nearbyPlaceCategories` and `openNearbyPlaceSearch`
  (Google Maps) from `data/models/nearby_place_category.dart`.
- The preview shows the newest 10 headlines. Tapping it opens the sheet with
  all of them, or retries after an error.
