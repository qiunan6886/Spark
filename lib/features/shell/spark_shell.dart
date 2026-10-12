import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/features/home/home_screen.dart';
import 'package:spark/features/library/library_screen.dart';
import 'package:spark/features/player/now_playing_screen.dart';
import 'package:spark/features/search/search_screen.dart';
import 'package:spark/features/settings/settings_screen.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/widgets/spark_mini_player.dart';

/// The app frame: four tabs, a floating mini player, and the Now Playing screen
/// pushed on top of everything.
///
/// The tab set is fixed. Flick let users reorder and hide nav items; Spark
/// deliberately does not -- that configuration surface is exactly the kind of
/// page-level setting this app drops.
class SparkShell extends ConsumerStatefulWidget {
  const SparkShell({super.key});

  @override
  ConsumerState<SparkShell> createState() => _SparkShellState();
}

class _SparkShellState extends ConsumerState<SparkShell> {
  static const _destinations = <_Destination>[
    _Destination(icon: LucideIcons.house, label: '首页'),
    _Destination(icon: LucideIcons.libraryBig, label: '曲库'),
    _Destination(icon: LucideIcons.search, label: '搜索'),
    _Destination(icon: LucideIcons.settings, label: '设置'),
  ];

  void _openNowPlaying() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => const NowPlayingScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Held in a provider, not local State, so screens can send the user to
    // another tab (the home header's search and heart buttons do exactly that).
    final index = ref.watch(navigationIndexProvider);

    return Scaffold(
      backgroundColor: SparkColors.background,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: index,
            children: const [
              HomeScreen(),
              LibraryScreen(),
              SearchScreen(),
              SettingsScreen(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SparkMiniPlayer(onTap: _openNowPlaying),
                _SparkNavBar(
                  index: index,
                  destinations: _destinations,
                  onSelect: (next) =>
                      ref.read(navigationIndexProvider.notifier).setIndex(next),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _SparkNavBar extends StatelessWidget {
  const _SparkNavBar({
    required this.index,
    required this.destinations,
    required this.onSelect,
  });

  final int index;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset * 0.5),
      decoration: BoxDecoration(
        color: SparkColors.background,
        border: Border(top: BorderSide(color: SparkColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < destinations.length; i++)
            _NavItem(
              destination: destinations[i],
              selected: i == index,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SparkRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? SparkColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(SparkRadius.pill),
          ),
          child: Icon(
            destination.icon,
            size: 22,
            color: selected ? SparkColors.onAccent : SparkColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
