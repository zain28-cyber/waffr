// Smoke tests for the brand widgets: avatar, logo, splash, page headers and
// the rolling streak number.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/brand/profile_avatar.dart';
import 'package:waffr/widgets/brand/streak_celebration.dart';
import 'package:waffr/widgets/brand/waffr_logo.dart';
import 'package:waffr/widgets/brand/waffr_page_header.dart';

import '../../helpers/widget_harness.dart';

void main() {
  smokeTestWidget(
    ProfileAvatar,
    () => const ProfileAvatar(accent: Colors.teal, signedIn: true),
  );
  smokeTestWidget(
    ProfileAvatar,
    () => const ProfileAvatar(accent: Colors.teal, signedIn: false),
    name: 'ProfileAvatar (guest)',
  );
  smokeTestWidget(WaffrLogo, () => const WaffrLogo());
  smokeTestWidget(WaffrSplash, () => const WaffrSplash(), wrap: false);
  smokeTestWidget(
    WaffrPageHeader,
    () => WaffrPageHeader(
      title: const Text('title'),
      elevated: ValueNotifier(true),
    ),
  );
  smokeTestWidget(
    WaffrBackHeader,
    () => WaffrBackHeader(title: 'title', elevated: ValueNotifier(false)),
  );
  smokeTestWidget(
    RollingNumber,
    () => const RollingNumber(
      from: 9,
      to: 10,
      progress: 0.5,
      style: TextStyle(fontSize: 40),
    ),
  );
}
