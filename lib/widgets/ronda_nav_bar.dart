import 'package:flutter/material.dart';

import '../screens/patient/app_colors.dart';

/// One tab of a [RondaNavBar].
class RondaNavItem {
  const RondaNavItem({
    required this.label,
    this.icon,
    this.selectedIcon,
    this.iconBuilder,
    this.badge = 0,
    this.badgeColor,
    this.semanticLabel,
  }) : assert(icon != null || iconBuilder != null);

  final String label;
  final IconData? icon;

  /// The filled version shown while the tab is selected; [icon] when null.
  final IconData? selectedIcon;

  /// For an icon that isn't a glyph (the profile photo).
  final Widget Function(bool selected)? iconBuilder;

  /// A count shown on the icon (new answers, open SOS requests); none when 0.
  final int badge;

  /// The count's color: the emergency red when null.
  final Color? badgeColor;

  /// What a screen reader says instead of [label], e.g. "History, 2 new updates".
  final String? semanticLabel;
}

/// The bottom bar of both home screens, GoBiker and resident.
///
/// The selected tab gets a pale brand pill behind its icon, a brand-blue label, and
/// the orange dot from the RondaGo logo at the pill's corner. A count badge takes the
/// dot's place.
class RondaNavBar extends StatelessWidget {
  const RondaNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.bottomInset = 0,
  });

  final List<RondaNavItem> items;

  /// Null when no tab is selected (a panel is open over the screen).
  final int? selectedIndex;
  final ValueChanged<int> onTap;

  /// Extra room below the tabs for the phone's own navigation area.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: EdgeInsets.only(top: 6, bottom: 6 + bottomInset),
      decoration: BoxDecoration(
        color: pal.card,
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _Tab(
                item: items[i],
                selected: i == selectedIndex,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final RondaNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final color = selected ? pal.brand : pal.muted;
    final still = MediaQuery.disableAnimationsOf(context);
    final duration = still ? Duration.zero : const Duration(milliseconds: 200);

    final glyph =
        item.iconBuilder?.call(selected) ??
        Icon(
          selected ? (item.selectedIcon ?? item.icon) : item.icon,
          size: 24,
          color: color,
        );

    return Semantics(
      button: true,
      selected: selected,
      label: item.semanticLabel ?? item.label,
      // The tab's own label replaces the parts inside it, so the tap is given here.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    width: 56,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? pal.brandSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: glyph,
                  ),
                  if (item.badge > 0)
                    Positioned(
                      top: -2,
                      right: 6,
                      child: Badge(
                        label: Text(item.badge > 9 ? '9+' : '${item.badge}'),
                        backgroundColor: item.badgeColor ?? AppColors.redButton,
                        textColor: Colors.white,
                      ),
                    )
                  else if (selected)
                    Positioned(
                      top: 3,
                      right: 9,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: pal.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: pal.brandSoft, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                // Labels grow with the phone's text size, up to a point, so four
                // still fit side by side.
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: 1.3),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
