import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'ui_kit.dart';

/// Loading placeholders that copy the shape of the real content, so the page
/// doesn't jump when the data arrives. Cards are drawn normally and only the
/// shapes inside them shimmer.

/// One list row: icon, two lines, and (optionally) a time on the right.
class _RowShape extends StatelessWidget {
  const _RowShape({this.trailing = true});
  final bool trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Sp.lg, 14, Sp.lg, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonBox(height: 22, circle: true),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 140, height: 15),
              SizedBox(height: 8),
              SkeletonBox(height: 12),
              SizedBox(height: 6),
              SkeletonBox(width: 90, height: 12),
            ],
          ),
        ),
        if (trailing) ...[
          const SizedBox(width: Sp.sm),
          const SkeletonBox(width: 44, height: 12),
        ],
      ],
    ),
  );
}

/// [count] rows in one card, with hairlines between them.
class _RowsCard extends StatelessWidget {
  const _RowsCard(this.count, {this.trailing = true});
  final int count;
  final bool trailing;

  @override
  Widget build(BuildContext context) => SkeletonCard(
    child: Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0)
            const Divider(height: 1, indent: 52, color: AppColors.divider),
          _RowShape(trailing: trailing),
        ],
      ],
    ),
  );
}

/// "Your health" on Home: two rows.
class HealthListSkeleton extends StatelessWidget {
  const HealthListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SkeletonPage(
    label: 'Loading your health summary',
    child: _RowsCard(2, trailing: false),
  );
}

/// History: a day label and a card of rows, twice.
class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SkeletonPage(
    label: 'Loading your history',
    child: Padding(
      padding: EdgeInsets.fromLTRB(Sp.gutter, Sp.sm, Sp.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4, Sp.md, 4, Sp.sm),
            child: Skeleton(child: SkeletonBox(width: 64, height: 13)),
          ),
          _RowsCard(3),
          Padding(
            padding: EdgeInsets.fromLTRB(4, Sp.lg, 4, Sp.sm),
            child: Skeleton(child: SkeletonBox(width: 88, height: 13)),
          ),
          _RowsCard(2),
        ],
      ),
    ),
  );
}

/// Medical History: the latest-vitals card and a card of earlier visits.
class MedicalHistorySkeleton extends StatelessWidget {
  const MedicalHistorySkeleton({super.key});

  Widget _stat() => const Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 70, height: 12),
        SizedBox(height: 8),
        SkeletonBox(width: 90, height: 24),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => SkeletonPage(
    label: 'Loading your medical history',
    child: Padding(
      padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.sm, Sp.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonCard(
            padding: const EdgeInsets.all(Sp.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 130, height: 15),
                const SizedBox(height: Sp.xs),
                const SkeletonBox(width: 200, height: 12),
                const SizedBox(height: Sp.lg),
                Row(children: [_stat(), _stat()]),
                const SizedBox(height: Sp.lg),
                Row(children: [_stat(), _stat()]),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, Sp.xl, 4, Sp.sm),
            child: Skeleton(child: SkeletonBox(width: 110, height: 17)),
          ),
          const _RowsCard(2),
        ],
      ),
    ),
  );
}

/// Home Visit: the status card.
class VisitCardSkeleton extends StatelessWidget {
  const VisitCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SkeletonPage(
    label: 'Loading your home visit',
    child: SkeletonCard(
      padding: EdgeInsets.all(Sp.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 150, height: 17),
          SizedBox(height: Sp.md),
          SkeletonBox(height: 13),
          SizedBox(height: Sp.sm),
          SkeletonBox(width: 200, height: 13),
          SizedBox(height: Sp.xl),
          SkeletonBox(height: 52, radius: Rd.control),
        ],
      ),
    ),
  );
}

/// A single line of text, for a value that loads on its own (the app version).
class LineSkeleton extends StatelessWidget {
  const LineSkeleton({super.key, this.width = 90});
  final double width;

  @override
  Widget build(BuildContext context) => SkeletonPage(
    label: 'Loading',
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Skeleton(child: SkeletonBox(width: width, height: 12)),
    ),
  );
}
