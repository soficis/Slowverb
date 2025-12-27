import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/providers/processing_progress_provider.dart';

/// Visual indicator for processing progress with time estimation.
/// Designed specifically for Level 5 mastering which takes significantly longer.
class ProcessingIndicator extends ConsumerWidget {
  const ProcessingIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressState = ref.watch(processingProgressProvider);

    if (!progressState.isActive) {
      return const SizedBox.shrink();
    }

    final progressPercent = (progressState.progress * 100).round();
    final hasTimeEstimate =
        progressState.estimatedRemaining != null &&
        progressState.progress > 0.05;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SlowverbTokens.spacingMd,
        vertical: SlowverbTokens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: SlowverbColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
        border: Border.all(
          color: SlowverbColors.primaryPurple.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: SlowverbColors.primaryPurple.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular progress indicator
          SizedBox(
            width: 24,
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progressState.progress,
                  strokeWidth: 3,
                  backgroundColor: SlowverbColors.surfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressState.isLevel5
                        ? SlowverbColors.accentPink
                        : SlowverbColors.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SlowverbTokens.spacingSm),

          // Progress info column
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stage and percentage
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatStage(progressState.stage),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: SlowverbColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$progressPercent%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: progressState.isLevel5
                          ? SlowverbColors.accentPink
                          : SlowverbColors.primaryPurple,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),

              // Time estimate (only for Level 5 or when available)
              if (hasTimeEstimate && progressState.isLevel5)
                Text(
                  progressState.estimatedRemainingText,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: SlowverbColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatStage(String stage) {
    // Make stage names more user-friendly
    switch (stage.toLowerCase()) {
      case 'decoding':
        return 'Preparing...';
      case 'mastering':
      case 'phaselimiter':
      case 'phaselimiter_pro':
        return 'Mastering';
      case 'level5':
      case 'pro':
        return 'Level 5';
      case 'encoding':
        return 'Encoding';
      case 'filtering':
        return 'Processing';
      case 'reverb':
        return 'Reverb';
      case 'complete':
        return 'Almost done';
      default:
        if (stage.isEmpty) return 'Processing';
        // Capitalize first letter
        return '${stage[0].toUpperCase()}${stage.substring(1)}';
    }
  }
}

/// Compact version of the indicator for tight spaces (e.g., mobile)
class CompactProcessingIndicator extends ConsumerWidget {
  const CompactProcessingIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressState = ref.watch(processingProgressProvider);

    if (!progressState.isActive) {
      return const SizedBox.shrink();
    }

    final progressPercent = (progressState.progress * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SlowverbColors.surfaceVariant.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              value: progressState.progress,
              strokeWidth: 2,
              backgroundColor: SlowverbColors.surface.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(
                progressState.isLevel5
                    ? SlowverbColors.accentPink
                    : SlowverbColors.primaryPurple,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$progressPercent%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: SlowverbColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
