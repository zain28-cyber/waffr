// Online exchange-rate card: the base-currency menu, rate rows and their
// formatting.

part of 'online_screen.dart';

/// Grouped rate figure with up to two decimals, in Western digits.
final NumberFormat _rateFormat = NumberFormat('#,##0.##', 'en');

/// Buy/sell rates for the selected FX asset, with an overlay currency picker.
/// The parent owns the selection and receives picks through `onSelected`.
class _ExchangeRateCard extends StatefulWidget {
  final ExchangeRate rate;
  final ValueChanged<String> onSelected;

  const _ExchangeRateCard({required this.rate, required this.onSelected});

  @override
  State<_ExchangeRateCard> createState() => _ExchangeRateCardState();
}

/// State of [_ExchangeRateCard]. Owns the overlay entry of the currency
/// menu and removes it on dispose.
class _ExchangeRateCardState extends State<_ExchangeRateCard> {
  /// Ties the overlay menu's position to the pair label.
  final LayerLink _menuLink = LayerLink();

  /// Reaches the menu's state to play its collapse animation.
  final GlobalKey<_CurrencyMenuLayerState> _menuKey = GlobalKey();
  OverlayEntry? _menuEntry;

  /// Drives the chevron rotation.
  bool _menuOpen = false;

  /// True while the collapse animation runs; blocks re-entry.
  bool _closingMenu = false;

  @override
  void dispose() {
    _menuEntry?.remove();
    _menuEntry = null;
    super.dispose();
  }

  void _toggleMenu() {
    if (_menuOpen) {
      _hideMenu();
    } else {
      _showMenu();
    }
  }

  /// Anchors an animated overlay menu under the pair label.
  void _showMenu() {
    if (_menuOpen || _closingMenu) return;

    final colors = AppPalette.of(context);
    final overlay = Overlay.of(context);
    final direction = Directionality.of(context);

    _menuEntry = OverlayEntry(
      builder: (context) {
        return _CurrencyMenuLayer(
          key: _menuKey,
          link: _menuLink,
          direction: direction,
          colors: colors,
          selected: widget.rate.code,
          onDismiss: _hideMenu,
          onSelected: (asset) {
            widget.onSelected(asset);
            _hideMenu();
          },
        );
      },
    );

    overlay.insert(_menuEntry!);
    setState(() => _menuOpen = true);
  }

  /// Plays the collapse animation, then removes the overlay entry.
  Future<void> _hideMenu() async {
    if (!_menuOpen || _closingMenu) return;
    _closingMenu = true;
    await _menuKey.currentState?.collapse();
    _menuEntry?.remove();
    _menuEntry = null;
    _closingMenu = false;
    if (mounted) {
      setState(() => _menuOpen = false);
    } else {
      _menuOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final rate = widget.rate;

    return GlassContainer(
      colorType: GlassColorType.surface,
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'سعر الصرف',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          // Tappable pair label (menu anchor) with a rotating chevron.
          CompositedTransformTarget(
            link: _menuLink,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleMenu,
              child: Row(
                children: [
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.medium),
                      switchInCurve: AppMotion.enter,
                      switchOutCurve: AppMotion.exit,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.18),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        'الليرة السورية · ${rate.pairLabel}',
                        key: ValueKey(rate.code),
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: ['Tajawal'],
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _menuOpen ? 0.5 : 0,
                    duration: AppMotion.of(context, AppMotion.medium),
                    curve: AppMotion.overshoot,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Buy and sell figures side by side.
          Row(
            children: [
              Expanded(
                child: _RateValue(
                  label: 'شراء',
                  value: rate.buy,
                  colors: colors,
                  valueKey: '${rate.code}-buy',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RateValue(
                  label: 'بيع',
                  value: rate.sell,
                  colors: colors,
                  valueKey: '${rate.code}-sell',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Overlay dropdown listing available exchange assets
/// ([OnlineFeedService.rates]). Taps outside the menu call `onDismiss`.
class _CurrencyMenuLayer extends StatefulWidget {
  final LayerLink link;
  final TextDirection direction;
  final AppPalette colors;
  final String selected;
  final VoidCallback onDismiss;
  final ValueChanged<String> onSelected;

  const _CurrencyMenuLayer({
    super.key,
    required this.link,
    required this.direction,
    required this.colors,
    required this.selected,
    required this.onDismiss,
    required this.onSelected,
  });

  @override
  State<_CurrencyMenuLayer> createState() => _CurrencyMenuLayerState();
}

/// State of [_CurrencyMenuLayer]. Owns the open/close controller and the
/// per-row stagger curves.
class _CurrencyMenuLayerState extends State<_CurrencyMenuLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;
  late final CurvedAnimation _curve;

  /// One staggered curve per row, made once and disposed with the menu.
  /// Building them in itemBuilder left a status listener on the controller
  /// for every row on every rebuild.
  late final List<CurvedAnimation> _rowCurves;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
      reverseDuration: AppMotion.fast,
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
    _fade = _curve;
    _scale = Tween<double>(begin: 0.92, end: 1).animate(_curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(_curve);

    final count = OnlineFeedService.rates.length;
    _rowCurves = [
      for (var i = 0; i < count; i++)
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            i / count * 0.35,
            (i / count * 0.35 + 0.65).clamp(0.0, 1.0).toDouble(),
            curve: AppMotion.enter,
          ),
        ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else if (_controller.isDismissed) {
      _controller.forward();
    }
  }

  /// Plays the closing animation (instant with reduced motion).
  Future<void> collapse() async {
    if (AppMotion.reduced(context)) {
      _controller.value = 0;
    } else {
      await _controller.reverse();
    }
  }

  @override
  void dispose() {
    for (final curve in _rowCurves) {
      curve.dispose();
    }
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen catcher: a tap outside the menu closes it.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        // The menu itself, pinned under the pair label and animated open.
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          targetAnchor: AlignmentDirectional.bottomStart.resolve(
            widget.direction,
          ),
          followerAnchor: AlignmentDirectional.topStart.resolve(
            widget.direction,
          ),
          offset: const Offset(0, 8),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: ScaleTransition(
                scale: _scale,
                alignment: AlignmentDirectional.topStart.resolve(
                  widget.direction,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 220,
                      maxWidth: 280,
                      maxHeight: 360,
                    ),
                    child: GlassContainer(
                      colorType: GlassColorType.surface,
                      tintOpacity: 1,
                      borderRadius: 22,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: OnlineFeedService.rates.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          thickness: 1,
                          indent: 14,
                          endIndent: 14,
                          color: widget.colors.textSecondary.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        itemBuilder: (context, i) {
                          return _CurrencyOption(
                            option: OnlineFeedService.rates[i],
                            selected:
                                OnlineFeedService.rates[i].code ==
                                widget.selected,
                            colors: widget.colors,
                            animation: _rowCurves[i],
                            onTap: () => widget.onSelected(
                              OnlineFeedService.rates[i].code,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One currency row inside the exchange-rate overlay menu.
class _CurrencyOption extends StatelessWidget {
  final ExchangeRate option;
  final bool selected;
  final AppPalette colors;
  final Animation<double> animation;
  final VoidCallback onTap;

  const _CurrencyOption({
    required this.option,
    required this.selected,
    required this.colors,
    required this.animation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(animation),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.code.length == 3
                        ? '${option.pairLabel} · ${option.code}'
                        : option.pairLabel,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: ['Tajawal'],
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? colors.accent : colors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded, size: 18, color: colors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Buy or sell figure with a crossfade when the selected asset changes.
/// A null value shows [ExchangeRate.unavailable].
class _RateValue extends StatelessWidget {
  final String label;
  final double? value;
  final AppPalette colors;
  final String valueKey;

  const _RateValue({
    required this.label,
    required this.value,
    required this.colors,
    required this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: sheetFieldColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.medium),
              switchInCurve: AppMotion.enter,
              switchOutCurve: AppMotion.exit,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.22),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                value == null
                    ? ExchangeRate.unavailable
                    : _rateFormat.format(value),
                key: ValueKey(valueKey),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sypCurrencyLabel,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
