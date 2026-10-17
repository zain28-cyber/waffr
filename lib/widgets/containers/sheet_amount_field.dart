// The large amount entry used by every money sheet: thousands formatting,
// the currency picker and the ×1–×10 multiplier, each opening a short list
// under the row.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/widgets/containers/sheet_fields.dart';

/// Which inline menu under the amount row is open.
enum _AmountMenu {
  /// No menu.
  none,

  /// The currency list.
  currency,

  /// The ×1–×10 list.
  multiplier,
}

/// Large centered amount entry with currency selector and optional helper text.
/// New money sheets should reuse this instead of rolling a custom amount row.
///
/// Currency and the × multiplier open a scrollable list over the sheet,
/// narrower than the sheet, dropping down from the control that was tapped.
class SheetAmountField extends StatefulWidget {
  /// Caption above the amount.
  final String label;

  /// Holds the typed amount (formatted with separators).
  final TextEditingController controller;

  /// Line under the amount (a total, or why it is too big).
  final String? helper;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Optional widget in the left slot when there is no [onMultiplierChanged].
  final Widget? leading;

  /// Displayed currency; defaults to the home-screen active currency.
  final String? currencyCode;

  /// Called with the picked currency; null hides the picker.
  final ValueChanged<String>? onCurrencyChanged;

  /// When set, the left slot is ×1–×10 and opens the same downward list.
  final int? multiplier;

  /// Called with the picked multiplier.
  final ValueChanged<int>? onMultiplierChanged;

  /// Optional control stacked above the × button in the same column.
  final Widget? multiplierAccessory;

  /// Creates a [SheetAmountField].
  const SheetAmountField({
    super.key,
    required this.label,
    required this.controller,
    this.helper,
    this.onChanged,
    this.leading,
    this.currencyCode,
    this.onCurrencyChanged,
    this.multiplier,
    this.onMultiplierChanged,
    this.multiplierAccessory,
  });

  @override
  State<SheetAmountField> createState() => _SheetAmountFieldState();
}

/// State of [SheetAmountField].
class _SheetAmountFieldState extends State<SheetAmountField> {
  static const List<int> _multipliers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  final GlobalKey _currencyKey = GlobalKey();
  final GlobalKey _multiplierKey = GlobalKey();

  _AmountMenu _menu = _AmountMenu.none;
  OverlayEntry? _entry;

  String get _code {
    return Currencies.normalize(
      widget.currencyCode ?? CurrencyStore.instance.activeCode,
    );
  }

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  void _close() {
    _removeEntry();
    if (_menu == _AmountMenu.none || !mounted) return;
    setState(() => _menu = _AmountMenu.none);
  }

  void _toggle(_AmountMenu menu) {
    if (_menu == menu) {
      _close();
      return;
    }
    _removeEntry();
    setState(() => _menu = menu);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _menu == menu) _showMenu(menu);
    });
  }

  /// Drops a scrollable list over the sheet, narrower than the sheet itself.
  void _showMenu(_AmountMenu menu) {
    // Place the list under the tapped control, inside the screen edges.
    final anchorKey = menu == _AmountMenu.currency
        ? _currencyKey
        : _multiplierKey;
    final anchor = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (anchor == null || !anchor.hasSize) return;

    final origin = anchor.localToGlobal(Offset.zero);
    final anchorSize = anchor.size;
    final screen = MediaQuery.sizeOf(context);
    final isMultiplier = menu == _AmountMenu.multiplier;
    // ×1–×10 is a short label; keep that list a tight column on the button.
    final menuWidth = isMultiplier
        ? 64.0
        : (screen.width * 0.62).clamp(180.0, 260.0);
    var left = isMultiplier
        ? origin.dx + (anchorSize.width - menuWidth) / 2
        : origin.dx;
    left = left.clamp(16.0, screen.width - menuWidth - 16);
    final top = origin.dy + anchorSize.height + 6;
    final maxHeight = (screen.height - top - 16).clamp(120.0, 220.0);

    final palette = AppPalette.of(context);
    final surface = palette.surface;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;
    final accent = palette.accent;

    // One row per enabled currency, or ×1–×10.
    final tiles = menu == _AmountMenu.currency
        ? [
            for (final item in CurrencyStore.instance.enabledCurrencies)
              _AmountMenuTile(
                title: item.arabicName,
                leading: item.symbol,
                selected: item.code == _code,
                accent: accent,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {
                  widget.onCurrencyChanged?.call(item.code);
                  _close();
                },
              ),
          ]
        : [
            for (final value in _multipliers)
              _AmountMenuTile(
                title: '×$value',
                centered: true,
                selected: value == (widget.multiplier ?? 1),
                accent: accent,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {
                  widget.onMultiplierChanged?.call(value);
                  _close();
                },
              ),
          ];

    // A full-screen tap target closes the list; the list drops in on top.
    _entry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: _AmountMenuDrop(
                child: Material(
                  color: surface,
                  elevation: 10,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      children: tiles,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;

    return ListenableBuilder(
      listenable: CurrencyStore.instance,
      builder: (context, _) {
        final options = CurrencyStore.instance.enabledCurrencies;
        final selectable =
            widget.onCurrencyChanged != null && options.length > 1;
        final showMultiplier = widget.onMultiplierChanged != null;
        final symbol = Currencies.symbolOf(_code);

        return Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          decoration: BoxDecoration(
            color: sheetFieldColor(context),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: 13,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              // Multiplier slot, the amount itself, and the currency symbol.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 46,
                    child: showMultiplier
                        ? _MultiplierColumn(
                            accessory: widget.multiplierAccessory,
                            button: KeyedSubtree(
                              key: _multiplierKey,
                              child: _AmountSlotButton(
                                label: '×${widget.multiplier ?? 1}',
                                color: textSecondary,
                                open: _menu == _AmountMenu.multiplier,
                                onTap: () => _toggle(_AmountMenu.multiplier),
                              ),
                            ),
                          )
                        : KeyedSubtree(
                            key: _multiplierKey,
                            child: widget.leading ?? const SizedBox.shrink(),
                          ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      onChanged: widget.onChanged,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsInputFormatter()],
                      cursorColor: textPrimary,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: ['Tajawal'],
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: ['Tajawal'],
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: textSecondary.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                  KeyedSubtree(
                    key: _currencyKey,
                    child: _AmountSlotButton(
                      label: symbol,
                      color: textSecondary,
                      open: selectable && _menu == _AmountMenu.currency,
                      showChevron: selectable,
                      onTap: selectable
                          ? () => _toggle(_AmountMenu.currency)
                          : null,
                    ),
                  ),
                ],
              ),
              // Total after the multiplier, or the balance warning.
              if (widget.helper != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.helper!,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                    fontSize: 11.5,
                    color: textSecondary.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// × button alone, or with an accessory above it. Both share the row height
/// evenly so the amount text keeps its place.
class _MultiplierColumn extends StatelessWidget {
  final Widget? accessory;
  final Widget button;

  const _MultiplierColumn({required this.accessory, required this.button});

  @override
  Widget build(BuildContext context) {
    final top = accessory;
    if (top == null) return button;
    return SizedBox(
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [top, button],
      ),
    );
  }
}

/// Fade + short drop so the currency / × lists do not pop in fully formed.
class _AmountMenuDrop extends StatefulWidget {
  final Widget child;

  const _AmountMenuDrop({required this.child});

  @override
  State<_AmountMenuDrop> createState() => _AmountMenuDropState();
}

/// State of [_AmountMenuDrop].
class _AmountMenuDropState extends State<_AmountMenuDrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.fast,
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enter,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else if (_controller.isDismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.08),
    end: Offset.zero,
  ).animate(_curved);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Symbol or ×N control. Chevron means a list will open under the row.
class _AmountSlotButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool open;
  final bool showChevron;
  final VoidCallback? onTap;

  const _AmountSlotButton({
    required this.label,
    required this.color,
    this.open = false,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (showChevron)
              Icon(
                open
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                size: 18,
                color: color,
              ),
          ],
        ),
      ),
    );
  }
}

/// Scrollable list that grows downward from the amount row, capped so the
/// sheet does not dump every choice on screen at once.
class _AmountMenuList extends StatelessWidget {
  final List<Widget> children;

  const _AmountMenuList({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 180),
        child: ListView(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          children: children,
        ),
      ),
    );
  }
}

/// One row of the currency or multiplier list.
class _AmountMenuTile extends StatelessWidget {
  final String title;
  final String? leading;
  final bool selected;
  final bool centered;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _AmountMenuTile({
    required this.title,
    required this.selected,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
    this.leading,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : textPrimary;
    final label = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontFamilyFallback: ['Tajawal'],
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: selected ? accent : textSecondary,
      ),
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: centered ? 0 : 4,
          vertical: centered ? 8 : 10,
        ),
        child: centered
            ? Center(child: label)
            : Row(
                children: [
                  if (leading != null) ...[
                    SizedBox(
                      width: 42,
                      child: Text(
                        leading!,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: ['Tajawal'],
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                  Expanded(child: label),
                ],
              ),
      ),
    );
  }
}

/// Compact currency control beside an amount; stays static when only one currency is enabled.
class SheetCurrencySelector extends StatefulWidget {
  /// The selected currency; defaults to the active one.
  final String? currencyCode;

  /// Called with the picked currency; null makes it static.
  final ValueChanged<String>? onChanged;

  /// A smaller control for tight rows.
  final bool dense;

  /// Creates a [SheetCurrencySelector].
  const SheetCurrencySelector({
    super.key,
    this.currencyCode,
    this.onChanged,
    this.dense = false,
  });

  @override
  State<SheetCurrencySelector> createState() => _SheetCurrencySelectorState();
}

/// State of [SheetCurrencySelector].
class _SheetCurrencySelectorState extends State<SheetCurrencySelector> {
  bool _open = false;

  String get _code {
    return Currencies.normalize(
      widget.currencyCode ?? CurrencyStore.instance.activeCode,
    );
  }

  /// Opens the currency list under the symbol. One currency stays a label.
  void _toggle() {
    final options = CurrencyStore.instance.enabledCurrencies;
    if (widget.onChanged == null || options.length < 2) return;
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CurrencyStore.instance,
      builder: (context, _) {
        final palette = AppPalette.of(context);
        final textPrimary = palette.textPrimary;
        final textSecondary = palette.textSecondary;
        final accent = palette.accent;
        final options = CurrencyStore.instance.enabledCurrencies;
        final selectable = widget.onChanged != null && options.length > 1;
        final symbol = Currencies.symbolOf(_code);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: selectable ? _toggle : null,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    symbol,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: ['Tajawal'],
                      fontSize: widget.dense ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  if (selectable)
                    Icon(
                      _open
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      size: widget.dense ? 16 : 18,
                      color: textSecondary,
                    ),
                ],
              ),
            ),
            if (_open)
              _AmountMenuList(
                children: [
                  for (final item in options)
                    _AmountMenuTile(
                      title: item.arabicName,
                      leading: item.symbol,
                      selected: item.code == _code,
                      accent: accent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () {
                        widget.onChanged?.call(item.code);
                        setState(() => _open = false);
                      },
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Formats amount text with thousand separators while typing (max 9 digits).
class ThousandsInputFormatter extends TextInputFormatter {
  /// Longest amount, in digits.
  static const int maxDigits = 9;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) return const TextEditingValue();

    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (trimmed.length > maxDigits) return oldValue;

    final formatted = formatMoney(int.parse(trimmed));

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Parses a formatted amount string after stripping commas.
double parseAmount(String text) {
  return double.tryParse(text.replaceAll(',', '').trim()) ?? 0;
}
