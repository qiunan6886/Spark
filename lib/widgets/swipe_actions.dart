import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:spark/app/theme/spark_theme.dart';

/// One button revealed by swiping a row.
class SwipeAction {
  const SwipeAction({
    required this.icon,
    required this.onPressed,
    this.label,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// Optional caption under the icon. Omitted for an icon-only button, which is
  /// what the library rows use -- the icons are unambiguous there and the text
  /// crowded the row.
  final String? label;

  /// Defaults to the accent colour.
  final Color? color;
}

/// Wraps a row so swiping it left reveals up to a few action buttons.
///
/// Revealing buttons rather than dismissing on swipe is deliberate: these rows
/// carry destructive actions next to reversible ones, and a full swipe that
/// deletes is the wrong default for a music library.
class SwipeActions extends StatelessWidget {
  const SwipeActions({
    super.key,
    required this.child,
    required this.actions,
    this.enabled = true,
  });

  final Widget child;
  final List<SwipeAction> actions;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || actions.isEmpty) return child;

    return Slidable(
      // Width scales with the number of buttons. An icon-only button needs less
      // room than one with a caption.
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio:
            ((actionWidth * actions.length) / 360).clamp(0.18, 0.78),
        children: [
          for (final action in actions)
            SlidableAction(
              onPressed: (_) => action.onPressed(),
              backgroundColor: action.color ?? SparkColors.accent,
              foregroundColor: action.color == null
                  ? SparkColors.background
                  : Colors.white,
              icon: action.icon,
              label: action.label,
              borderRadius: BorderRadius.zero,
            ),
        ],
      ),
      child: child,
    );
  }

  /// Roughly how much room one button wants, in logical pixels.
  static double get actionWidth => 96;
}
