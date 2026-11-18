import 'package:flutter/material.dart';

import '../screens/patient/app_colors.dart';

/// The blue of the Go Bike icon (sampled from the designer's artwork).
const Color kGoBikeBlue = AppColors.blue;

/// The orange of the dot in the icon and of "Go" in the wordmark.
const Color kGoBikeOrange = AppColors.orange;

const String kGoBikeIconAsset = 'assets/images/GoBike-icon.png';

/// The Go Bike app icon: a rounded blue square with the loop, the R and the orange dot.
/// It is its own background, so it reads the same on light and dark pages.
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

/// "Go Bike" set as in the brand video: "Go" in blue, "Bike" in orange italic, Poppins
/// bold. In dark mode "Go" turns white so it stays readable.
class GoBikeWordmark extends StatelessWidget {
  const GoBikeWordmark({super.key, this.fontSize = 32});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          height: 1.15,
          color: dark ? Colors.white : kGoBikeBlue,
        ),
        children: const [
          TextSpan(text: 'Go'),
          TextSpan(
            text: 'Bike',
            style: TextStyle(fontStyle: FontStyle.italic, color: kGoBikeOrange),
          ),
        ],
      ),
      // A logo keeps its proportions: it does not grow with the phone's text size.
      textScaler: TextScaler.noScaling,
      semanticsLabel: 'Go Bike',
    );
  }
}