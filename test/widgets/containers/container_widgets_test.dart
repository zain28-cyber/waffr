// Smoke tests for the shared containers: glass surfaces, list tiles, empty
// states, sheet fields and buttons, sheet transitions and the period selector.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/containers/app_empty_state.dart';
import 'package:waffr/widgets/containers/app_list_tile.dart';
import 'package:waffr/widgets/containers/floating_glass.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/widgets/containers/pinned_period_scroll_view.dart';

import '../../helpers/widget_harness.dart';

void main() {
  for (final type in GlassColorType.values) {
    smokeTestWidget(
      GlassContainer,
      () => GlassContainer(colorType: type, child: const Text('glass')),
      name: 'GlassContainer (${type.name})',
    );
  }
  smokeTestWidget(
    FloatingGlass,
    () => const FloatingGlass(child: SizedBox(height: 60, width: 200)),
  );
  smokeTestWidget(
    AppListTile,
    () => AppListTile(
      icon: Icons.lock_outline_rounded,
      title: 'title',
      subtitle: 'subtitle',
      status: 'on',
      statusOn: true,
      onTap: () {},
    ),
  );
  smokeTestWidget(
    AppListTile,
    () => const AppListTile(
      icon: Icons.delete_outline_rounded,
      title: 'title',
      busy: true,
      destructive: true,
    ),
    name: 'AppListTile (busy, destructive)',
  );
  smokeTestWidget(
    AppSectionTitle,
    () => const AppSectionTitle(title: 'section'),
  );
  smokeTestWidget(
    AppEmptyState,
    () => const AppEmptyState(
      icon: Icons.inbox_rounded,
      title: 'title',
      message: 'message',
    ),
  );
  smokeTestWidget(
    AppEmptyState,
    () => const AppEmptyState(
      icon: Icons.inbox_rounded,
      title: 'title',
      compact: true,
    ),
    name: 'AppEmptyState (compact)',
  );
  smokeTestWidget(
    SheetFieldLabel,
    () => const SheetFieldLabel(
      text: 'label',
      optional: true,
      action: SheetInfoButton(title: 'title', message: 'message'),
    ),
  );
  smokeTestWidget(
    SheetOptionTile,
    () => SheetOptionTile(
      icon: Icons.edit_rounded,
      label: 'edit',
      hint: 'hint',
      onTap: () {},
    ),
  );
  smokeTestWidget(
    SheetTextField,
    () => SheetTextField(controller: TextEditingController(), hint: 'hint'),
  );
  smokeTestWidget(
    SheetChoiceChips,
    () => SheetChoiceChips(
      options: const ['a', 'b', 'c'],
      selected: 'b',
      onSelected: (_) {},
    ),
  );
  smokeTestWidget(
    SheetAmountField,
    () => SheetAmountField(
      label: 'amount',
      controller: TextEditingController(text: '125000'),
      helper: 'helper',
      onCurrencyChanged: (_) {},
    ),
  );
  smokeTestWidget(
    SheetCurrencySelector,
    () => SheetCurrencySelector(onChanged: (_) {}),
  );
  smokeTestWidget(
    SheetCircleButton,
    () => SheetCircleButton(icon: Icons.close_rounded, onTap: () {}),
  );
  smokeTestWidget(
    SheetSaveButton,
    () => SheetSaveButton(label: 'save', onTap: () {}),
  );
  smokeTestWidget(
    SheetDestructiveButton,
    () => SheetDestructiveButton(label: 'delete', onTap: () {}),
  );
  smokeTestWidget(
    SheetExpand,
    () => const SheetExpand(visible: true, child: Text('shown')),
  );
  smokeTestWidget(
    SheetSwap,
    () => const SheetSwap(switchKey: 1, child: Text('one')),
  );
  smokeTestWidget(
    GlassSheetHeader,
    () => GlassSheetHeader(title: 'title', subtitle: 'subtitle', onNext: () {}),
  );
  smokeTestWidget(
    GlassSheetBody,
    () => const GlassSheetBody(children: [Text('row'), Text('row')]),
    wrap: false,
  );
  smokeTestWidget(
    FloatingPeriodSelector,
    () => FloatingPeriodSelector(
      options: const ['week', 'month', 'year'],
      selected: 'month',
      onSelected: (_) {},
    ),
  );
}
