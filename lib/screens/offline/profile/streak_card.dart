// Streak card on the profile tab: the day count, a ring that fills toward the
// next milestone with the Waffr mark inside, and this week's days lighting
// up one after another. Plays when the tab opens.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/core/usage/streak_math.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/widgets/brand/waffr_logo.dart';
import 'package:waffr/widgets/containers/glass.dart';

/// Usage streak card for the profile tab. Animates on first build and again
/// whenever [replayToken] changes; with reduced motion it shows the final
/// state directly.
class StreakCard extends StatefulWidget {
  /// Consecutive days the app has been opened (at least 1).
  final int count;

  /// Last day counted in the streak; today when null.
  final DateTime? lastDay;

  /// A new value replays the animation.
  final int replayToken;

  /// Creates a [StreakCard].
  const StreakCard({
    super.key,
    required this.count,
    required this.lastDay,
    required this.replayToken,
  });

  @override
  State<StreakCard> createState() => _StreakCardState();
}

/// State of [StreakCard]. Owns the single animation controller that drives
/// the count-up, the ring and the week strip.
class _StreakCardState extends State<StreakCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  /// Count-up phase of the controller.
  late final Animation<double> _count = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.55, curve: AppMotion.enter),
  );

  /// Ring fill phase of the controller.
  late final Animation<double> _ring = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.08, 0.75, curve: AppMotion.enter),
  );

  /// Ensures the first play happens once, when context is available.
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  @override
  void didUpdateWidget(covariant StreakCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Replay only for a real revisit. A count that changes while shown
    // (e.g. the streak service finishing its load) updates in place.
    if (oldWidget.replayToken != widget.replayToken) _play();
  }

  /// Plays from the start, or jumps to the end with reduced motion.
  void _play() {
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // Streak window: from `start` to `last`, counted back from the last day.
    final count = widget.count;
    final milestone = nextStreakMilestone(count);
    final left = milestone - count;
    final today = DateTime.now();
    final lastDay = widget.lastDay ?? today;
    final last = DateTime(lastDay.year, lastDay.month, lastDay.day);
    final start = last.subtract(Duration(days: count - 1));

    return RepaintBoundary(
      child: GlassContainer(
        colorType: GlassColorType.surface,
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final shown = (count * _count.value).round().clamp(
              count > 1 ? 1 : count,
              count,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Count, "since" date and days left, beside the milestone ring.
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'أيامك المتواصلة',
                            style: _style(
                              size: 13.5,
                              weight: FontWeight.w700,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$shown',
                                style: _style(
                                  size: 44,
                                  weight: FontWeight.w800,
                                  color: palette.accent,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _daysWord(count),
                                style: _style(
                                  size: 16,
                                  weight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            count <= 1
                                ? 'افتح وفّر غداً لتبدأ سلسلتك'
                                : 'منذ ${formatDate(start)}',
                            style: _style(
                              size: 12.5,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_remaining(left)} للوصول إلى '
                            '$milestone ${_daysWord(milestone)}',
                            style: _style(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: palette.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StreakRing(
                      progress: (count / milestone) * _ring.value,
                      palette: palette,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // This week, Saturday to Friday.
                _WeekStrip(
                  today: DateTime(today.year, today.month, today.day),
                  start: start,
                  last: last,
                  animation: _controller,
                  palette: palette,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Arabic "N days left" phrase with the right number agreement, as in
/// the examples below.
// "بقي يوم واحد" / "بقي يومان" / "بقي 5 أيام".
String _remaining(int left) {
  if (left == 1) return 'بقي يوم واحد';
  if (left == 2) return 'بقي يومان';
  return 'بقي $left ${_daysWord(left)}';
}

/// Arabic counted noun for "day" after [count], per the rule below.
// Counted noun after a number: 1 يوم, 2-10 أيام, 11+ يوماً.
String _daysWord(int count) {
  if (count == 1) return 'يوم';
  if (count <= 10) return 'أيام';
  return 'يوماً';
}

/// Outfit/Tajawal text style shared by the card's labels.
TextStyle _style({
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w500,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Outfit',
    fontFamilyFallback: const ['Tajawal'],
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
  );
}

/// Progress ring toward the next milestone with a soft head and the logo.
class _StreakRing extends StatelessWidget {
  final double progress;
  final AppPalette palette;

  const _StreakRing({required this.progress, required this.palette});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          track: palette.accent.withValues(alpha: 0.12),
          fill: palette.accent,
        ),
        child: const Center(child: WaffrLogo(size: 46)),
      ),
    );
  }
}

/// Paints the ring track, a gradient arc for [progress] and a glowing head.
class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color fill;

  const _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  /// Ring stroke width.
  static const double _stroke = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - _stroke / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = track,
    );

    if (progress <= 0) return;
    const start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;

    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + 2 * math.pi,
          colors: [fill.withValues(alpha: 0.55), fill],
          stops: [0, progress.clamp(0.01, 1.0)],
          transform: const GradientRotation(start),
        ).createShader(rect),
    );

    // Soft light at the head of the arc.
    final head = Offset(
      center.dx + radius * math.cos(start + sweep),
      center.dy + radius * math.sin(start + sweep),
    );
    canvas.drawCircle(
      head,
      _stroke * 0.95,
      Paint()
        ..color = fill.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(head, _stroke * 0.32, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.track != track ||
        oldDelegate.fill != fill;
  }
}

/// The current week, Saturday to Friday, starting on the right. Days inside
/// the streak light up in order; days still ahead stay faded.
class _WeekStrip extends StatelessWidget {
  final DateTime today;
  final DateTime start;
  final DateTime last;
  final Animation<double> animation;
  final AppPalette palette;

  const _WeekStrip({
    required this.today,
    required this.start,
    required this.last,
    required this.animation,
    required this.palette,
  });

  /// Weekday initials shown above each day.
  static const Map<int, String> _initials = {
    DateTime.saturday: 'س',
    DateTime.sunday: 'ح',
    DateTime.monday: 'ن',
    DateTime.tuesday: 'ث',
    DateTime.wednesday: 'ر',
    DateTime.thursday: 'خ',
    DateTime.friday: 'ج',
  };

  @override
  Widget build(BuildContext context) {
    // Days since Saturday (DateTime.weekday: Monday = 1 ... Sunday = 7).
    final sinceSaturday = (today.weekday + 1) % 7;
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(today.year, today.month, today.day - sinceSaturday + i),
    ];

    return Row(
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: _DayMark(
              label: _initials[days[i].weekday] ?? '',
              active: !days[i].isBefore(start) && !days[i].isAfter(last),
              isToday: days[i] == today,
              isFuture: days[i].isAfter(today),
              reveal: AppMotion.overshoot.transform(
                ((animation.value - 0.30 - i * 0.07) / 0.28).clamp(0.0, 1.0),
              ),
              palette: palette,
            ),
          ),
      ],
    );
  }
}

/// One day in the week strip: initial plus a circle that fills and shows a
/// check when the day is in the streak; today gets a ring when it is not.
class _DayMark extends StatelessWidget {
  final String label;
  final bool active;
  final bool isToday;
  final bool isFuture;
  final double reveal;
  final AppPalette palette;

  const _DayMark({
    required this.label,
    required this.active,
    required this.isToday,
    required this.isFuture,
    required this.reveal,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final lit = active ? reveal : 0.0;
    final fill = Color.lerp(
      palette.accent.withValues(alpha: 0.10),
      palette.accent,
      lit.clamp(0.0, 1.0),
    )!;

    final mark = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: _style(
            size: 11.5,
            weight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday ? palette.textPrimary : palette.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Transform.scale(
          scale: active ? 0.85 + 0.15 * reveal : 1,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: isToday && !active
                  ? Border.all(color: palette.accent, width: 1.4)
                  : null,
            ),
            child: active
                ? Opacity(
                    opacity: reveal.clamp(0.0, 1.0),
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: palette.onAccent,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
    return isFuture ? Opacity(opacity: 0.45, child: mark) : mark;
  }
}
