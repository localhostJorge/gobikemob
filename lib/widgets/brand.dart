import 'package:flutter/material.dart';

import '../screens/patient/app_colors.dart';

/// The blue of the RondaGo icon (sampled from the designer's artwork).
const Color kRondaBlue = AppColors.blue;

/// The orange of the dot in the icon and of "Go" in the wordmark.
const Color kRondaOrange = AppColors.orange;

const String kRondaGoIconAsset = 'assets/images/rondago_icon.png';

/// The RondaGo app icon: a rounded blue square with the loop, the R and the orange dot.
/// It is its own background, so it reads the same on light and dark pages.
class RondaGoIcon extends StatelessWidget {
  const RondaGoIcon({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kRondaGoIconAsset,
      width: size,
      height: size,
      semanticLabel: 'RondaGo',
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          SizedBox.square(dimension: size),
    );
  }
}

/// "RondaGo" set as in the brand video: "Ronda" in blue, "Go" in orange italic, Poppins
/// bold. In dark mode "Ronda" turns white so it stays readable.
class RondaGoWordmark extends StatelessWidget {
  const RondaGoWordmark({super.key, this.fontSize = 32});

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
          color: dark ? Colors.white : kRondaBlue,
        ),
        children: const [
          TextSpan(text: 'Ronda'),
          TextSpan(
            text: 'Go',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: kRondaOrange,
            ),
          ),
        ],
      ),
      // A logo keeps its proportions: it does not grow with the phone's text size.
      textScaler: TextScaler.noScaling,
      semanticsLabel: 'RondaGo',
    );
  }
}
