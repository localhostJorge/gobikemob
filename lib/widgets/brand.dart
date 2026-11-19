import 'package:flutter/material.dart';

import '../screens/patient/app_colors.dart';

/// The blue of the Go Bike icon (sampled from the designer's artwork).
const Color kGoBikeBlue = AppColors.blue;

/// The orange of the dot in the icon and of "Go" in the wordmark.
const Color kGoBikeOrange = AppColors.orange;

const String kGoBikeIconAsset = 'assets/images/GoBike-icon.png';

/// The Go Bike logo (bike, heartbeat and GO BIKE) on its white square. It is its own
/// background, so it reads the same on light and dark pages.
class GoBikeIcon extends StatelessWidget {
  const GoBikeIcon({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kGoBikeIconAsset,
      width: size,
      height: size,
      semanticLabel: 'Go Bike',
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          SizedBox.square(dimension: size),
    );
  }
}

/// "About Go Bike": the app icon, the wordmark and the installed version, as on the
/// profile pages of both apps. [version] is null while it loads; [pending] shows then.
class GoBikeAbout extends StatelessWidget {
  const GoBikeAbout({super.key, this.version, this.pending, this.padding});

  final String? version;
  final Widget? pending;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final muted = context.pal.muted;
    return Semantics(
      container: true,
      label: version == null ? 'Go Bike' : 'Go Bike, version $version',
      excludeSemantics: true,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Row(
          children: [
            const GoBikeIcon(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: GoBikeWordmark(fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  if (version != null)
                    Text(
                      'Version $version',
                      style: TextStyle(fontSize: 13, color: muted),
                    )
                  else
                    pending ??
                        Text(
                          'Version …',
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Go Bike" set as in the logo: "Go" in orange italic, "Bike" in the logo blue,
/// Poppins bold, in light and dark mode alike (the logo blue is 3.3:1 on the dark
/// page, enough for a big bold wordmark).
///
/// Only on the navy home band ([onNavy]) does "Bike" take a lighter blue: the logo
/// blue is 1.9:1 there and all but disappears.
class GoBikeWordmark extends StatelessWidget {
  const GoBikeWordmark({super.key, this.fontSize = 32, this.onNavy = false});

  final double fontSize;

  /// Set on the navy home band.
  final bool onNavy;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          height: 1.15,
        ),
        children: [
          const TextSpan(
            text: 'Go ',
            style: TextStyle(fontStyle: FontStyle.italic, color: kGoBikeOrange),
          ),
          TextSpan(
            text: 'Bike',
            // On navy: the dark palette's brand, the blue lifted so it reads there.
            style: TextStyle(color: onNavy ? AppPalette.dark.brand : kGoBikeBlue),
          ),
        ],
      ),
      // A logo keeps its proportions: it does not grow with the phone's text size.
      textScaler: TextScaler.noScaling,
      semanticsLabel: 'Go Bike',
    );
  }
}