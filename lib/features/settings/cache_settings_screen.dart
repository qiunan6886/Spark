import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/features/library/downloads_pane.dart' show formatBytes;
import 'package:spark/providers/providers.dart';
import 'package:spark/services/online_cache_service.dart';

/// Cache size, cap and clearing.
///
/// The cache grows on its own as tracks are played, so it needs somewhere to
/// see and bound that growth -- and a way to take the space back.
class CacheSettingsScreen extends ConsumerWidget {
  const CacheSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final used = ref.watch(cacheSizeProvider);
    final count = ref.watch(cacheCountProvider);
    final limit = ref.watch(cacheLimitProvider);

    return Scaffold(
      backgroundColor: SparkColors.background,
      appBar: AppBar(
        backgroundColor: SparkColors.background,
        foregroundColor: SparkColors.textPrimary,
        title: Text(l10n.cacheSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SparkSpacing.page,
              8,
              SparkSpacing.page,
              20,
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: SparkColors.surface,
                borderRadius: BorderRadius.circular(SparkRadius.card),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.hardDrive, color: SparkColors.accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.cacheUsage(formatBytes(used)),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: SparkColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          limit <= OnlineCacheService.noLimit
                              ? l10n.cacheUnlimited
                              : l10n.cacheDetail(
                                  formatBytes(limit),
                                  count,
                                ),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: SparkColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(SparkSpacing.page, 0, 0, 6),
            child: Text(
              l10n.cacheLimit,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SparkColors.textTertiary,
              ),
            ),
          ),
          for (final choice in OnlineCacheService.kLimitChoices)
            _LimitRow(
              label: choice <= OnlineCacheService.noLimit
                  ? l10n.cacheUnlimited
                  : formatBytes(choice),
              selected: limit == choice,
              onTap: () =>
                  ref.read(cacheLimitProvider.notifier).setLimit(choice),
            ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SparkSpacing.page),
            child: OutlinedButton.icon(
              onPressed: count == 0 ? null : () => _confirmClear(context, ref),
              icon: const Icon(LucideIcons.trash2, size: 18),
              label: Text(l10n.cacheClear),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.4),
                ),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SparkRadius.pill),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SparkColors.surface,
        title: Text(
          l10n.cacheClear,
          style: TextStyle(color: SparkColors.textPrimary),
        ),
        content: Text(
          l10n.cacheClearConfirm,
          style: TextStyle(color: SparkColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: SparkColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.cacheClear,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(clearCacheProvider)();
    messenger.showSnackBar(SnackBar(content: Text(l10n.cacheCleared)));
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SparkSpacing.page,
          vertical: 14,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? SparkColors.accent
                      : SparkColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              Icon(LucideIcons.check, size: 20, color: SparkColors.accent),
          ],
        ),
      ),
    );
  }
}
