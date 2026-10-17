// Online tab: exchange rates, nearby place shortcuts, and a news preview.
// The cards live in the part files online_cards.dart,
// online_exchange_rates.dart and online_news.dart.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:waffr/widgets/motion/motion.dart';
import 'package:waffr/screens/shell/app_shell_scope.dart';
import 'package:waffr/data/models/exchange_rate.dart';
import 'package:waffr/data/models/nearby_place_category.dart';
import 'package:waffr/data/models/news_article.dart';
import 'package:waffr/data/services/online_feed_service.dart';
import 'package:waffr/data/services/profile_identity.dart';
import 'package:waffr/core/sync/sync_service.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/screens/offline/login/login_screen.dart';
import 'package:waffr/screens/online/sheets/news_sheet.dart';
import 'package:waffr/widgets/button/glass_button.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/core/theme/app_motion.dart';

part 'online_cards.dart';
part 'online_exchange_rates.dart';
part 'online_news.dart';

/// Hosts the three online cards and refreshes news when the app resumes.
/// Guests see the cards behind a sign-in overlay; nothing is fetched for them.
class OnlineScreen extends StatefulWidget {
  /// Creates a [OnlineScreen].
  const OnlineScreen({super.key});

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

/// loading / ready / empty / error for the news preview card.
enum _NewsLoadState { loading, ready, empty, error }

/// State of [OnlineScreen]. Listens to [ProfileIdentity] (to lift the guest
/// overlay and start the feed on sign-in) and to app resume (to refresh news).
class _OnlineScreenState extends State<OnlineScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  /// The swipe preview shows only the newest few; the sheet lists the rest.
  static const int _newsPreviewLimit = 10;

  /// Currency or metal code shown in the exchange-rate card.
  String _selectedAsset = 'USD';
  List<NewsArticle> _articles = const [];
  _NewsLoadState _newsState = _NewsLoadState.loading;

  /// Drops overlapping [_loadNews] calls.
  bool _newsRequestInFlight = false;
  final ProfileIdentity _identity = ProfileIdentity.instance;

  /// Sign-in state seen last time, to detect the guest-to-signed-in edge.
  bool _wasSignedIn = false;

  @override
  bool get wantKeepAlive => true;

  bool get _signedIn => _identity.isLoaded && _identity.isLoggedIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _identity.addListener(_onIdentityChanged);
    _identity.ensureLoaded();
    _wasSignedIn = _signedIn;
    if (_wasSignedIn) _loadNews();
  }

  @override
  void dispose() {
    _identity.removeListener(_onIdentityChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNews();
    }
  }

  /// Loads the feed the moment the user is known to be signed in.
  void _onIdentityChanged() {
    final signedIn = _signedIn;
    if (signedIn && !_wasSignedIn) _loadNews();
    _wasSignedIn = signedIn;
    if (mounted) setState(() {});
  }

  /// Same login route as Settings; the overlay lifts once sign-in succeeds.
  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          allowGuest: false,
          popOnSuccess: true,
          onCompleted: () async {
            await SyncService.instance.syncNow();
          },
        ),
      ),
    );
    await _identity.reload();
  }

  /// Fetches headlines; keeps prior articles on failure if we already had
  /// some.
  Future<void> _loadNews() async {
    if (!_signedIn) return;
    if (_newsRequestInFlight) return;
    _newsRequestInFlight = true;
    final showLoading = _articles.isEmpty;
    if (showLoading && mounted) {
      setState(() => _newsState = _NewsLoadState.loading);
    }

    try {
      final articles = await OnlineFeedService.instance.fetchArticles();
      if (!mounted) return;
      setState(() {
        _articles = articles;
        _newsState = articles.isEmpty
            ? _NewsLoadState.empty
            : _NewsLoadState.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _newsState = _articles.isEmpty
            ? _NewsLoadState.error
            : _NewsLoadState.ready;
      });
    } finally {
      _newsRequestInFlight = false;
    }
  }

  /// Retry on error; otherwise open the full news sheet.
  void _onNewsTap() {
    if (_newsState == _NewsLoadState.error) {
      _loadNews();
      return;
    }
    showNewsSheet(context, articles: _articles);
  }

  /// Opens Google Maps for the category; snacks if the URL launch fails.
  Future<void> _openPlace(NearbyPlaceCategory category) async {
    final opened = await openNearbyPlaceSearch(category);
    if (opened || !mounted) return;

    showAppSnackBar(context, 'تعذّر فتح خرائط Google');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final locked = _identity.isLoaded && !_identity.isLoggedIn;

    // The three cards, staggered in on first build.
    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, kFloatingNavClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: staggered([
          _ExchangeRateCard(
            rate: OnlineFeedService.rateFor(_selectedAsset),
            onSelected: (asset) => setState(() => _selectedAsset = asset),
          ),
          const SizedBox(height: kCardGap),
          _NearbyPlacesCard(onOpen: _openPlace),
          const SizedBox(height: kCardGap),
          _NewsPreviewCard(
            articles: _articles.length > _newsPreviewLimit
                ? _articles.sublist(0, _newsPreviewLimit)
                : _articles,
            state: _newsState,
            onTap: _newsState == _NewsLoadState.loading ? null : _onNewsTap,
          ),
        ]),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Guests see the cards blurred. The blur is applied to the cards
        // themselves in their own layer, instead of a full-screen backdrop
        // filter that had to be recomputed on every frame of a tab swipe.
        AbsorbPointer(
          absorbing: locked,
          child: ExcludeSemantics(
            excluding: locked,
            child: RepaintBoundary(
              child: ImageFiltered(
                enabled: locked,
                imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: content,
              ),
            ),
          ),
        ),
        // Sign-in prompt, faded in over the blurred cards for guests.
        IgnorePointer(
          ignoring: !locked,
          child: AnimatedOpacity(
            opacity: locked ? 1 : 0,
            duration: AppMotion.of(context, AppMotion.slow),
            curve: AppMotion.enter,
            child: _SignInGate(onLogin: _openLogin),
          ),
        ),
      ],
    );
  }
}
