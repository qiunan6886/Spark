import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/models/song.dart';
import 'package:spark/widgets/online_track_row.dart';
import 'package:spark/widgets/swipe_actions.dart';

/// One action offered while a list is in multi-select mode.
class SelectionAction {
  const SelectionAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final void Function(List<Song> selected) onPressed;
  final bool destructive;
}

/// Height of the floating mini player + nav bar.
///
/// The shell uses `extendBody: true` and paints those two as an overlay, so the
/// bottom of every screen is covered. Lists already clear them with this much
/// bottom padding; the selection bar has to sit above them for the same reason,
/// otherwise it renders underneath and is invisible.
const double kFloatingChromeHeight = 140;

/// A song list with left-swipe actions and long-press multi-select.
///
/// Selection lives here rather than in a provider so two lists can never share
/// a selection by accident, and so leaving the pane drops it.
class SelectableSongList extends StatefulWidget {
  const SelectableSongList({
    super.key,
    required this.songs,
    required this.onPlay,
    required this.swipeActionsFor,
    required this.selectionActions,
    this.header,
    this.trailingFor,
    this.emptyState,
    this.shrinkWrap = false,
  });

  final List<Song> songs;

  /// Called with the tapped song and the list it belongs to.
  final void Function(Song song, List<Song> queue) onPlay;

  final List<SwipeAction> Function(Song song) swipeActionsFor;
  final List<SelectionAction> selectionActions;

  /// Rendered above the list, outside the scroll view.
  final Widget? header;

  final Widget? Function(Song song)? trailingFor;

  /// Shown in place of the list when there is nothing to show.
  final Widget? emptyState;

  /// Set when the list sits inside another scroll view, where there is no bounded
  /// height for it to expand into. The list then sizes to its content and the
  /// parent keeps the scrolling.
  ///
  /// Without this the internal `Expanded` throws "non-zero flex but incoming
  /// height constraints are unbounded" -- which is what putting this widget in a
  /// sliver does.
  final bool shrinkWrap;

  @override
  State<SelectableSongList> createState() => _SelectableSongListState();
}

class _SelectableSongListState extends State<SelectableSongList> {
  final Set<String> _selected = {};

  bool get _active => _selected.isNotEmpty;

  /// The songs currently picked, in list order rather than tap order.
  List<Song> get _selectedSongs => [
    for (final song in widget.songs)
      if (_selected.contains(song.id)) song,
  ];

  void _toggle(Song song) {
    setState(() {
      if (!_selected.remove(song.id)) _selected.add(song.id);
    });
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == widget.songs.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(widget.songs.map((song) => song.id));
      }
    });
  }

  void _clear() => setState(_selected.clear);

  /// Runs an action and leaves selection mode, unless the action says
  /// otherwise by keeping the list open (nothing does today, but the shape is
  /// here so an "add to several playlists" could).
  void _run(SelectionAction action) {
    final songs = _selectedSongs;
    _clear();
    action.onPressed(songs);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) {
      return widget.emptyState ?? const SizedBox.shrink();
    }

    final list = ListView.builder(
      // Clears the floating mini player and nav bar. When shrink-wrapped the
      // parent scroll view already reserves that room, so adding it here too
      // would push the following section off screen.
      padding: widget.shrinkWrap
          ? EdgeInsets.zero
          : EdgeInsets.only(
              bottom: _active
                  ? kFloatingChromeHeight * 1.5
                  : kFloatingChromeHeight,
            ),
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: widget.songs.length,
      itemBuilder: (context, i) {
        final song = widget.songs[i];
        final isSelected = _selected.contains(song.id);

        return SwipeActions(
          // Swiping a row out from under a selection would be confusing, so
          // gestures are off while a selection is active.
          enabled: !_active,
          actions: widget.swipeActionsFor(song),
          child: OnlineTrackRow(
            song: song,
            showSelectionMark: _active,
            selected: isSelected,
            onTap: () => _active
                ? _toggle(song)
                : widget.onPlay(song, widget.songs),
            onLongPress: () => _toggle(song),
            trailing: widget.trailingFor?.call(song),
          ),
        );
      },
    );

    return Column(
      // Shrink-wrapping inside a parent scroll view; expanding when we own the
      // scrolling.
      mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (widget.header != null) widget.header!,
        if (widget.shrinkWrap) list else Expanded(child: list),
        if (_active)
          Padding(
            padding: widget.shrinkWrap
                ? EdgeInsets.zero
                : const EdgeInsets.only(bottom: kFloatingChromeHeight),
            child: _SelectionBar(
              count: _selected.length,
              total: widget.songs.length,
              actions: widget.selectionActions,
              onToggleAll: _toggleAll,
              onCancel: _clear,
              onRun: _run,
            ),
          ),
      ],
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.total,
    required this.actions,
    required this.onToggleAll,
    required this.onCancel,
    required this.onRun,
  });

  final int count;
  final int total;
  final List<SelectionAction> actions;
  final VoidCallback onToggleAll;
  final VoidCallback onCancel;
  final void Function(SelectionAction action) onRun;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allSelected = count == total;

    return Padding(
      // Floats above the mini player rather than butting against it, matching
      // how the mini player itself sits over the content.
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Material(
        color: SparkColors.surfaceHigh,
        borderRadius: BorderRadius.circular(SparkRadius.pill),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: onCancel,
                icon: const Icon(LucideIcons.x, size: 20),
                color: SparkColors.textSecondary,
                tooltip: l10n.cancel,
                // Compact: the default Material 3 tap target is 48x48, and a
                // few of those plus the label and Select all overflow a 320dp
                // row -- which pushed the trailing actions off screen and made
                // the download button look missing.
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                visualDensity: VisualDensity.compact,
              ),
              // Expanded rather than a plain Text plus Spacer: the actions on
              // the right are what must never be pushed off, so the label takes
              // the leftover width and ellipsizes.
              Expanded(
                child: Text(
                  l10n.selectedCount(count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SparkColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: onToggleAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  allSelected ? l10n.selectNone : l10n.selectAll,
                  style: TextStyle(fontSize: 13, color: SparkColors.accent),
                ),
              ),
              for (final action in actions)
                IconButton(
                  onPressed: () => onRun(action),
                  icon: Icon(action.icon, size: 20),
                  color: action.destructive
                      ? Theme.of(context).colorScheme.error
                      : SparkColors.accent,
                  tooltip: action.label,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
