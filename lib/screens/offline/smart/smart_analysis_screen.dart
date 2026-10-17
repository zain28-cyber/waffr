// Smart analysis screen (library root): "thinks" for a moment, then writes
// its findings out as if typing them, over a soft moving glow. Cards expand
// to show the numbers behind each finding and offer the matching action.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:waffr/core/insights/smart/insight_engine.dart';
import 'package:waffr/core/insights/smart/smart_facts_loader.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/core/theme/app_color.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/screens/offline/home/sheets/add_expense_sheet.dart';
import 'package:waffr/screens/offline/home/sheets/add_income_sheet.dart';
import 'package:waffr/screens/offline/obligations/obligations_sheet.dart';
import 'package:waffr/screens/offline/report/reportscreen.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/screens/offline/savings/sheets/create_goal_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/manual_save_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/shopping_list_sheet.dart';
import 'package:waffr/widgets/brand/waffr_page_header.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/widgets/motion/motion.dart';
import 'package:waffr/widgets/smart/smart_glow.dart';

part 'smart_analysis_cards.dart';
part 'smart_analysis_thinking.dart';

/// Hero tag shared by the smart analysis button for [scope] and the spark on
/// this screen's headline.
String smartSparkHeroTag(InsightScope scope) => 'smart-spark-${scope.name}';

/// Opens the analysis with a fade and gentle zoom from the button.
Future<void> openSmartAnalysis(BuildContext context, InsightScope scope) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: AppMotion.of(context, AppMotion.emphasized),
      reverseTransitionDuration: AppMotion.of(context, AppMotion.medium),
      pageBuilder: (_, _, _) => SmartAnalysisScreen(scope: scope),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.enter,
          reverseCurve: AppMotion.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Screen phase: thinking (loading), writing (typing out), done.
enum _Phase { thinking, writing, done }

/// Full-screen local analysis of the user's finances for one [InsightScope],
/// built by [InsightEngine] from [SmartFactsLoader] facts. Opened with
/// [openSmartAnalysis].
class SmartAnalysisScreen extends StatefulWidget {
  /// Scope the screen opens on; the user can switch scope with the chips.
  final InsightScope scope;

  /// Creates a [SmartAnalysisScreen].
  const SmartAnalysisScreen({super.key, required this.scope});

  @override
  State<SmartAnalysisScreen> createState() => _SmartAnalysisScreenState();
}

/// State of [SmartAnalysisScreen]. Owns the typing [Ticker], the thinking
/// line timer and the pause timer between thinking and writing.
class _SmartAnalysisScreenState extends State<SmartAnalysisScreen>
    with SingleTickerProviderStateMixin {
  // Rotating status lines shown while thinking.
  static const List<String> _thinkingLines = [
    'أراجع مصاريفك…',
    'أقارن مع الفترات السابقة…',
    'أبحث عن الأنماط…',
    'أحسب التوقعات…',
    'أجهّز الاقتراحات…',
  ];

  // Scope currently analysed.
  late InsightScope _scope = widget.scope;
  // Seeds each report so a rerun can word findings differently.
  final math.Random _seeds = math.Random();
  _Phase _phase = _Phase.thinking;
  SmartReport? _report;
  int _thinkingLine = 0;

  /// Characters written so far across the headline, summary and card
  /// bodies, read as one stream.
  int _revealed = 0;
  // Length of the whole stream.
  int _total = 0;

  /// Writing speed follows elapsed time, not frames, so a slow device
  /// writes in the same ~3 seconds with bigger steps.
  late final Ticker _typing = createTicker(_onTypingTick);
  double _charsPerMs = 0.15;

  // Rotates the thinking line.
  Timer? _thinkingTicker;
  // Pause between thinking and writing, and the completer awaiting it.
  Timer? _pause;
  Completer<void>? _pauseDone;
  // Ticker time of the last typing setState (for the ~30 Hz throttle).
  Duration _lastTypingUpdate = Duration.zero;
  // Generation counter; a stale run stops when this moves on.
  int _run = 0;
  // Ids of expanded insight cards (and the health gauge).
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    // Reads MediaQuery (reduced motion), so it waits for the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _generate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _thinkingTicker?.cancel();
      _cancelPause();
      if (_phase == _Phase.writing) _finish();
    }
  }

  @override
  void dispose() {
    _typing.dispose();
    _thinkingTicker?.cancel();
    _cancelPause();
    super.dispose();
  }

  /// Release waiting runs as well as their timers. A canceled generation
  /// resumes only to fail its run/mounted guard, without leaking a delay.
  void _cancelPause() {
    _pause?.cancel();
    final done = _pauseDone;
    if (done != null && !done.isCompleted) done.complete();
    _pause = null;
    _pauseDone = null;
  }

  /// Cancellable delay; [_cancelPause] completes it early.
  Future<void> _wait(Duration duration) {
    if (duration == Duration.zero) return Future<void>.value();
    final done = Completer<void>();
    _pauseDone = done;
    _pause = Timer(duration, done.complete);
    return done.future;
  }

  /// Thinks, builds a fresh report with a new seed, then types it out.
  /// [quick] shortens the thinking pause (scope change, refresh after action).
  Future<void> _generate({bool quick = false}) async {
    final run = ++_run;
    _typing.stop();
    _thinkingTicker?.cancel();
    _cancelPause();
    _lastTypingUpdate = Duration.zero;
    setState(() {
      _phase = _Phase.thinking;
      _expanded.clear();
      _thinkingLine = _seeds.nextInt(_thinkingLines.length);
    });

    // Rotate the thinking line unless motion is reduced.
    if (!AppMotion.reduced(context)) {
      _thinkingTicker = Timer.periodic(const Duration(milliseconds: 650), (_) {
        if (mounted) {
          setState(
            () => _thinkingLine = (_thinkingLine + 1) % _thinkingLines.length,
          );
        }
      });
    }

    final facts = await SmartFactsLoader.load();
    // Discard superseded scope requests before doing the analysis.
    if (!mounted || run != _run) return;
    final report = InsightEngine(
      facts,
      seed: _seeds.nextInt(1 << 30),
    ).analyze(_scope);
    final pause = AppMotion.reduced(context)
        ? Duration.zero
        : Duration(milliseconds: quick ? 700 : 1500);
    await _wait(pause);
    if (!mounted || run != _run) return;
    _thinkingTicker?.cancel();
    final reduced = AppMotion.reduced(context);

    // Health-score text is not typed: the gauge shows it instead.
    final total =
        report.headline.length +
        report.summary.length +
        report.insights
            .where((item) => item.id != 'health-score')
            .fold<int>(0, (sum, item) => sum + item.body.length);
    setState(() {
      _report = report;
      _total = total;
      // Keep the whole write-out to roughly three seconds.
      _charsPerMs = math.max(0.12, total / 3000);
      _revealed = reduced ? total : 0;
      _phase = reduced ? _Phase.done : _Phase.writing;
    });
    if (reduced) {
      AppHaptics.success();
      return;
    }
    _typing.start();
  }

  /// Advances the typed character count from elapsed ticker time.
  void _onTypingTick(Duration elapsed) {
    final next = math.min(
      _total,
      (elapsed.inMilliseconds * _charsPerMs).round(),
    );
    // Text layout needn't run at the display's 60/120 Hz. Limit writing
    // updates to ~30 Hz while keeping completion tied to elapsed time.
    if (next < _total &&
        elapsed - _lastTypingUpdate < const Duration(milliseconds: 33)) {
      return;
    }
    _lastTypingUpdate = elapsed;
    if (next != _revealed) setState(() => _revealed = next);
    if (_revealed >= _total) _finish();
  }

  /// Stops typing and shows everything.
  void _finish() {
    _typing.stop();
    if (_phase == _Phase.done) return;
    setState(() {
      _revealed = _total;
      _phase = _Phase.done;
    });
    AppHaptics.success();
  }

  /// Scope chip picked: rerun the analysis for that scope.
  void _selectScope(String label) {
    final next = InsightScope.values.firstWhere(
      (scope) => scope.label == label,
    );
    if (next == _scope) return;
    AppHaptics.selection();
    _scope = next;
    _generate(quick: true);
  }

  /// Opens the sheet or screen for an insight's action, then reruns the
  /// analysis if any store changed meanwhile.
  Future<void> _runAction(InsightAction action) async {
    AppHaptics.selection();
    // Rerun the analysis afterwards only if the action changed any data;
    // closing a sheet without saving should not replay the whole reading.
    var changed = false;
    void markChanged() => changed = true;
    final stores = Listenable.merge([
      TransactionStore.instance,
      RecurringExpenseStore.instance,
      ShoppingListStore.instance,
    ])..addListener(markChanged);
    try {
      switch (action) {
        case InsightAction.addExpense:
          await showAddExpenseSheet(context);
        case InsightAction.addIncome:
          await showAddIncomeSheet(context);
        case InsightAction.createGoal:
          await showCreateGoalSheet(context);
        case InsightAction.manualSave:
          await showManualSaveSheet(context);
        case InsightAction.obligations:
          await showObligationsSheet(context);
        case InsightAction.shoppingList:
          await showShoppingListSheet(context);
        case InsightAction.expenseHistory:
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TransactionHistoryScreen.expenses(),
            ),
          );
      }
    } finally {
      // Detach even when a sheet throws, so the stores do not keep it.
      stores.removeListener(markChanged);
    }
    if (!changed || !mounted) return;
    // The data may have changed; refresh the reading quietly.
    _generate(quick: true);
  }

  /// Visible part of a segment that starts at [offset] in the stream.
  String _slice(String text, int offset) {
    final count = (_revealed - offset).clamp(0, text.length);
    return text.substring(0, count);
  }

  /// Whether the typing cursor is currently inside this segment.
  bool _typingAt(String text, int offset) =>
      _phase == _Phase.writing &&
      _revealed > offset &&
      _revealed < offset + text.length;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final generating = _phase != _Phase.done;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // Animated glow behind everything; calmer once done.
          Positioned.fill(
            child: RepaintBoundary(
              child: SmartGlowBackground(intensity: generating ? 1 : 0.4),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              children: [
                // Header, scope chips, then the headline row.
                WaffrBackHeader(title: 'التحليل الذكي'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                  child: SheetChoiceChips(
                    options: [
                      for (final scope in InsightScope.values) scope.label,
                    ],
                    selected: _scope.label,
                    onSelected: _selectScope,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                  child: _headlineRow(palette),
                ),
                Expanded(
                  child: GestureDetector(
                    // Tap while writing to show everything at once.
                    behavior: HitTestBehavior.translucent,
                    onTap: _phase == _Phase.writing ? _finish : null,
                    child: AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.slow),
                      switchInCurve: AppMotion.enter,
                      switchOutCurve: AppMotion.exit,
                      child: _phase == _Phase.thinking || _report == null
                          ? const _ThinkingView(key: ValueKey('thinking'))
                          : _reportView(_report!, palette),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The spark stays in one place across thinking and writing, so the hero
  /// from the button lands on it and there is never a second copy.
  Widget _headlineRow(AppPalette palette) {
    final report = _report;
    final thinking = _phase == _Phase.thinking || report == null;
    final style = TextStyle(
      fontFamily: 'Outfit',
      fontFamilyFallback: const ['Tajawal'],
      fontSize: thinking ? 16 : 20,
      height: 1.4,
      fontWeight: thinking ? FontWeight.w700 : FontWeight.w800,
      color: palette.textPrimary,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: smartSparkHeroTag(widget.scope),
          child: SmartSpark(size: 30, spinning: _phase != _Phase.done),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.medium),
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.topStart,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: thinking
                  ? Text(
                      _thinkingLines[_thinkingLine],
                      key: ValueKey('think-$_thinkingLine'),
                      style: style,
                    )
                  : _TypedText(
                      key: ValueKey('headline-$_run'),
                      text: _slice(report.headline, 0),
                      typing: _typingAt(report.headline, 0),
                      style: style,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// Health gauge, summary and insight cards, each shown once the typing
  /// stream reaches it.
  Widget _reportView(SmartReport report, AppPalette palette) {
    // Stream offsets: headline, then summary, then each card body in order.
    var offset = report.headline.length;
    final summaryAt = offset;
    offset += report.summary.length;
    // The gauge shows the health score and its breakdown, so its card is
    // not repeated in the list.
    final health = report.insights
        .where((item) => item.id == 'health-score')
        .firstOrNull;
    final insights = [
      for (final item in report.insights)
        if (item.id != 'health-score') item,
    ];
    final bodyOffsets = <int>[];
    for (final item in insights) {
      bodyOffsets.add(offset);
      offset += item.body.length;
    }

    return ListView(
      key: ValueKey('report-$_run'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
      children: [
        // Health gauge appears with the summary.
        if (report.healthScore != null && _revealed > summaryAt) ...[
          const SizedBox(height: 8),
          Reveal(
            child: _HealthGauge(
              score: report.healthScore!,
              title: health?.title ?? 'مؤشر الصحة المالية',
              detail: health?.detail,
              expanded: _expanded.contains('health-score'),
              onToggle: () {
                AppHaptics.selection();
                setState(() {
                  if (!_expanded.remove('health-score')) {
                    _expanded.add('health-score');
                  }
                });
              },
            ),
          ),
        ],
        if (report.summary.isNotEmpty && _revealed > summaryAt) ...[
          const SizedBox(height: 10),
          _TypedText(
            text: _slice(report.summary, summaryAt),
            typing: _typingAt(report.summary, summaryAt),
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: const ['Tajawal'],
              fontSize: 14,
              height: 1.6,
              color: palette.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 16),
        // A card appears once typing reaches its body (or at once when it has
        // none).
        for (var i = 0; i < insights.length; i++)
          if (_revealed >= bodyOffsets[i] &&
              (_revealed > bodyOffsets[i] ||
                  insights[i].body.isEmpty ||
                  _phase == _Phase.done))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Reveal(
                key: ValueKey('${_run}_${insights[i].id}'),
                child: _InsightCard(
                  insight: insights[i],
                  body: _slice(insights[i].body, bodyOffsets[i]),
                  typing: _typingAt(insights[i].body, bodyOffsets[i]),
                  expanded: _expanded.contains(insights[i].id),
                  interactive: _phase == _Phase.done,
                  onToggle: () {
                    AppHaptics.selection();
                    setState(() {
                      final id = insights[i].id;
                      if (!_expanded.remove(id)) _expanded.add(id);
                    });
                  },
                  onAction: _runAction,
                ),
              ),
            ),
      ],
    );
  }
}
