// Brand mark asset and the splash screen that shows it while startup resolves.
import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_color.dart';

/// Official Waffr mark. The wallet square is centered; flap and clasp sit
/// outside that square. Edges stay transparent.
class WaffrLogo extends StatelessWidget {
  /// The logo image asset.
  static const assetPath = 'assets/brand/waffr_logo.png';

  /// Width and height.
  final double size;

  /// Creates a [WaffrLogo].
  const WaffrLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    // Decode at display size; the asset is 1440 px square.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      cacheWidth: pixels,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      gaplessPlayback: true,
      semanticLabel: 'شعار وفّر',
    );
  }
}

/// Shown while theme and auth settle; matches the app background color.
class WaffrSplash extends StatelessWidget {
  /// Use the system brightness (before the app theme is known).
  final bool followPlatformBrightness;

  /// Creates a [WaffrSplash].
  const WaffrSplash({super.key, this.followPlatformBrightness = false});

  @override
  Widget build(BuildContext context) {
    final isDark = followPlatformBrightness
        ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
        : Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: background,
      body: const SafeArea(child: Center(child: WaffrLogo(size: 84))),
    );
  }
}
