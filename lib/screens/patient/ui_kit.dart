import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The resident app's shared design tokens and building blocks. Every screen
/// uses these instead of its own sizes, so the app reads as one thing.

// ---------------------------------------------------------------- tokens

/// Spacing on a 4-point rhythm.
abstract final class Sp {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Side padding of every screen.
  static const double gutter = 20;
}

/// Corner radii: three sizes, no others.
abstract final class Rd {
  /// Buttons and inputs.
  static const double control = 12;

  /// Cards and groups.
  static const double card = 16;

  /// Dialogs and sheets.
  static const double sheet = 20;
}

/// The app font. Named where a widget (a button) replaces the inherited style.
const kFontFamily = 'Roboto';

/// The type scale. Six sizes; weight and color do the rest of the hierarchy.
abstract final class T {
  /// Screen heading on the tabs.
  static const title = TextStyle(
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
  );

  /// Section headings, dialog titles, page titles.
  static const heading = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  /// The first line of a list row or card.
  static const rowTitle = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  /// Running text.
  static const body = TextStyle(
    fontSize: 15,
    height: 1.4,
    color: AppColors.textDark,
  );

  /// Descriptions and supporting lines.
  static const secondary = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: AppColors.textMuted,
  );

  /// Small facts: times, tab labels, footnotes.
  static const meta = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  /// Form labels and statuses.
  static const label = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  static const button = TextStyle(
    // A button's text style replaces the inherited one, so name the font.
    fontFamily: kFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );
}

// ---------------------------------------------------------------- surfaces

/// A flat white card with a hairline border: no shadow anywhere in the app.
BoxDecoration cardDecoration([double radius = Rd.card]) => BoxDecoration(
  color: AppColors.card,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.line),
);

/// A card, optionally tappable (with a pressed ripple).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Sp.lg),
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// For a card that must stand out (an open SOS, a warning).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final decoration = cardDecoration().copyWith(
      border: Border.all(
        color: borderColor ?? AppColors.line,
        width: borderColor == null ? 1 : 1.5,
      ),
    );
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: BorderRadius.circular(Rd.card),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Rows grouped in one card, separated by hairlines.
class CardGroup extends StatelessWidget {
  const CardGroup({super.key, required this.children, this.dividerIndent = 0});

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    // A Material surface (not a painted box), so taps on rows show a ripple.
    return Material(
      color: AppColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rd.card),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: dividerIndent,
                color: AppColors.divider,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row of a [CardGroup]: icon, title, a supporting line, and a chevron
/// when it opens something. 64 dp tall, so it is an easy target.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.color = AppColors.textDark,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Instead of [subtitle], e.g. a skeleton line while a value loads.
  final Widget? subtitleWidget;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sub =
        subtitleWidget ??
        (subtitle == null ? null : Text(subtitle!, style: T.secondary));
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.lg, 14, Sp.md, 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: T.rowTitle),
                    if (sub != null) ...[const SizedBox(height: 2), sub],
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A heading above a group: "Emergency hotlines", "Your health".
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, Sp.sm),
    child: Row(
      children: [
        Expanded(child: Text(text, style: T.heading)),
        ?trailing,
      ],
    ),
  );
}

/// The heading at the top of each tab, so Home, History, Safety and Settings
/// all start at the same place.
class TabHeader extends StatelessWidget {
  const TabHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      Sp.gutter,
      Sp.lg,
      trailing == null ? Sp.gutter : Sp.sm,
      Sp.sm,
    ),
    child: Row(
      children: [
        Expanded(child: Text(title, style: T.title)),
        ?trailing,
      ],
    ),
  );
}

// ---------------------------------------------------------------- app bar

/// The bar of every pushed page: back arrow and a left-aligned title.
PreferredSizeWidget patientAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: AppColors.background,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleSpacing: 0,
    leading: IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
      onPressed: () => Navigator.maybePop(context),
    ),
    title: Text(title, style: T.heading),
  );
}

// ---------------------------------------------------------------- buttons

ButtonStyle _buttonStyle({
  required Color background,
  required Color foreground,
  Color? border,
}) => ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
  elevation: const WidgetStatePropertyAll(0),
  textStyle: const WidgetStatePropertyAll(T.button),
  backgroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.disabled)
        ? background.withValues(alpha: 0.4)
        : background,
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.disabled)
        ? foreground.withValues(alpha: 0.6)
        : foreground,
  ),
  side: border == null
      ? null
      : WidgetStatePropertyAll(BorderSide(color: border)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.control)),
  ),
);

Widget _buttonChild(String label, IconData? icon, bool loading, Color color) {
  if (loading) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
    );
  }
  if (icon == null) return Text(label);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: Sp.sm),
      Flexible(child: Text(label, textAlign: TextAlign.center)),
    ],
  );
}

/// The one main action of a screen. Use at most one per screen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null && !loading,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      style: _buttonStyle(
        background: AppColors.redButton,
        foreground: Colors.white,
      ),
      child: _buttonChild(label, icon, loading, Colors.white),
    ),
  );
}

/// An action that matters but is not the main one. [destructive] is for
/// things like cancelling a request.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.redText : AppColors.textDark;
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: _buttonStyle(
        background: Colors.transparent,
        foreground: color,
        border: destructive
            ? AppColors.redText.withValues(alpha: 0.5)
            : AppColors.textDark.withValues(alpha: 0.25),
      ),
      child: _buttonChild(label, icon, loading, color),
    );
  }
}

/// Legacy helper kept for older call sites.
Widget primaryButton({
  required String label,
  required VoidCallback? onPressed,
  bool loading = false,
}) => PrimaryButton(label: label, onPressed: onPressed, loading: loading);

/// A quiet text action ("Retry", "Clear"). Always a 48-dp target.
class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.textMuted,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: Sp.md),
      textStyle: T.label.copyWith(fontSize: 14, fontFamily: kFontFamily),
    );
    return icon == null
        ? TextButton(onPressed: onPressed, style: style, child: Text(label))
        : TextButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 20),
            label: Text(label),
          );
  }
}

// ---------------------------------------------------------------- dialogs

/// The app's one confirmation dialog. Returns true when confirmed.
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  Color? confirmColor,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rd.sheet),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, Sp.sm),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, Sp.sm),
      actionsPadding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      title: Text(title, style: T.heading),
      content: Text(message, style: T.body),
      actions: [
        QuietButton(
          label: cancelLabel,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        QuietButton(
          label: confirmLabel,
          color:
              confirmColor ??
              (destructive ? AppColors.redText : AppColors.textDark),
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return ok == true;
}

// ---------------------------------------------------------------- states

/// Nothing to show yet: says what will appear and, if useful, what to do.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xxl + Sp.lg, Sp.xl, Sp.xl),
    child: Column(
      children: [
        Text(title, style: T.heading, textAlign: TextAlign.center),
        const SizedBox(height: Sp.xs),
        Text(message, style: T.secondary, textAlign: TextAlign.center),
        if (actionLabel != null) ...[
          const SizedBox(height: Sp.lg),
          QuietButton(
            label: actionLabel!,
            onPressed: onAction,
            color: AppColors.redText,
          ),
        ],
      ],
    ),
  );
}

/// The whole list failed to load: say so and offer to try again.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xxl + Sp.lg, Sp.xl, Sp.xl),
    child: Semantics(
      liveRegion: true,
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 32,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: Sp.md),
          const Text(
            "Couldn't load this",
            style: T.heading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Sp.xs),
          Text(message, style: T.secondary, textAlign: TextAlign.center),
          const SizedBox(height: Sp.lg),
          SizedBox(
            width: 180,
            child: SecondaryButton(label: 'Try again', onPressed: onRetry),
          ),
        ],
      ),
    ),
  );
}

/// A slim notice above content that is already on screen (a refresh failed).
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.actionLabel = 'Retry',
    this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: Sp.md),
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.xs, Sp.xs),
      decoration: BoxDecoration(
        color: AppColors.redSoft,
        borderRadius: BorderRadius.circular(Rd.control),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: T.secondary.copyWith(color: AppColors.textDark),
            ),
          ),
          if (onAction != null)
            QuietButton(
              label: actionLabel,
              onPressed: onAction,
              color: AppColors.redText,
            ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- skeletons

/// Sweeps one soft highlight across the [SkeletonBox] shapes inside it. Only
/// the shapes should be in here: anything opaque (a card's white surface)
/// would be painted by the sweep too, so draw the card outside and the shapes
/// inside (see [SkeletonCard]). The shimmer stops when the phone asks for less
/// motion. Give [label] when this is the only skeleton on the screen; for a
/// page made of several, wrap it in a [SkeletonPage] instead.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child, this.label});

  final Widget child;
  final String? label;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final shimmer = still
        ? widget.child
        : AnimatedBuilder(
            animation: _controller,
            child: widget.child,
            builder: (context, child) => ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [
                  AppColors.skeleton,
                  AppColors.skeletonShine,
                  AppColors.skeleton,
                ],
                stops: const [0.3, 0.5, 0.7],
                transform: _Sweep(_controller.value),
              ).createShader(rect),
              child: child,
            ),
          );
    final label = widget.label;
    if (label == null) return shimmer;
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: shimmer),
    );
  }
}

class _Sweep extends GradientTransform {
  const _Sweep(this.t);
  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// A whole loading page: screen readers hear one [label] instead of every
/// placeholder shape.
class SkeletonPage extends StatelessWidget {
  const SkeletonPage({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: ExcludeSemantics(child: child),
  );
}

/// A card whose surface is drawn normally while the shapes inside shimmer.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: cardDecoration(),
    child: Skeleton(child: child),
  );
}

/// One placeholder shape inside a [Skeleton].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: circle ? height : width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.skeleton,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
    ),
  );
}

/// Fades from the skeleton to the real content once it has loaded, so the
/// page doesn't jump.
class LoadSwitcher extends StatelessWidget {
  const LoadSwitcher({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    child: KeyedSubtree(
      key: ValueKey(loading),
      child: loading ? skeleton : child,
    ),
  );
}

// ---------------------------------------------------------------- inputs

/// Text fields: one look for every form.
InputDecoration inputDecoration(String label, IconData icon, {Widget? suffix}) {
  OutlineInputBorder border(Color c, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Rd.control),
    borderSide: BorderSide(color: c, width: width),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: T.secondary,
    prefixIcon: Icon(icon, color: AppColors.textMuted, size: 22),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: Sp.lg,
      vertical: Sp.lg,
    ),
    border: border(AppColors.line),
    enabledBorder: border(AppColors.line),
    focusedBorder: border(AppColors.textDark, 1.5),
    errorBorder: border(AppColors.redText),
    focusedErrorBorder: border(AppColors.redText, 1.5),
    errorStyle: T.meta.copyWith(color: AppColors.redText),
  );
}
