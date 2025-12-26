import 'package:flutter/material.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/features/editor/widgets/chrome_button.dart';
import 'package:slowverb_web/features/editor/widgets/visualizer_selector.dart';

/// Editor title bar with back, fullscreen, visualizer, preset badge, and export.
///
/// Displays a gradient background with app title and responsive layout
/// that adapts for narrow screens.
class EditorTitleBar extends StatelessWidget {
  final String presetName;
  final bool masteringEnabled;
  final bool previewMasteringApplied;
  final VoidCallback onBack;
  final VoidCallback onExport;
  final VoidCallback onFullscreen;

  const EditorTitleBar({
    super.key,
    required this.presetName,
    required this.masteringEnabled,
    required this.previewMasteringApplied,
    required this.onBack,
    required this.onExport,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow
            ? SlowverbTokens.spacingSm
            : SlowverbTokens.spacingLg,
        vertical: SlowverbTokens.spacingSm,
      ),
      decoration: BoxDecoration(
        gradient: SlowverbTokens.titleBarGradient,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
        boxShadow: [SlowverbTokens.shadowCard],
      ),
      child: Row(
        children: [
          // Left: Back button
          ChromeButton(icon: Icons.arrow_back, onTap: onBack),
          const SizedBox(width: SlowverbTokens.spacingSm),

          // Left: Fullscreen button (prominent position)
          ChromeButton(icon: Icons.fullscreen, onTap: onFullscreen),
          const SizedBox(width: SlowverbTokens.spacingMd),

          // Left: Compact visualizer selector
          const VisualizerSelector(),

          // Center: Slowverb title with Roboto font
          Expanded(
            child: Center(
              child: Text(
                'Slowverb',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: isNarrow ? 20 : 28,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right: Preset badge (if not narrow)
          if (!isNarrow) ...[
            PresetBadge(presetName: presetName),
            const SizedBox(width: SlowverbTokens.spacingMd),
          ],

          // Show mastering indicator only if preview was rendered with mastering
          if (previewMasteringApplied) ...[
            Icon(
              Icons.auto_awesome,
              // Gray out if mastering was applied but is now disabled
              color: masteringEnabled
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.3),
              size: 18,
            ),
            if (!isNarrow) ...[
              const SizedBox(width: 6),
              Text(
                'Mastering On',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  // Gray out if mastering was applied but is now disabled
                  color: masteringEnabled
                      ? Colors.white.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
            const SizedBox(width: SlowverbTokens.spacingSm),
          ],

          // Right: Export button
          isNarrow
              ? IconButton(
                  onPressed: onExport,
                  icon: const Icon(Icons.download),
                  tooltip: 'Export',
                )
              : ElevatedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                ),
        ],
      ),
    );
  }
}
