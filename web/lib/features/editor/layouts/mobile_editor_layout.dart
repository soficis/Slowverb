import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/router.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/parameter_definitions.dart';
import 'package:slowverb_web/providers/audio_editor_provider.dart';
import 'package:slowverb_web/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mobile-optimized layout with floating controls and bottom sheet effects.
///
/// This layout provides a fullscreen visualizer experience with:
/// - Minimal top bar with back and export buttons
/// - Floating mini transport bar at bottom
/// - Expandable bottom sheet for effect controls
class MobileEditorLayout extends ConsumerStatefulWidget {
  final String projectName;
  final String presetName;
  final AudioEditorNotifier notifier;
  final String projectId;
  final VoidCallback onBack;
  final bool masteringEnabled;
  final bool previewMasteringApplied;

  // Flattened state props
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isGeneratingPreview;
  final String selectedPresetId;
  final Map<String, double> parameters;

  const MobileEditorLayout({
    super.key,
    required this.projectName,
    required this.presetName,
    required this.notifier,
    required this.projectId,
    required this.onBack,
    required this.masteringEnabled,
    required this.previewMasteringApplied,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isGeneratingPreview,
    required this.selectedPresetId,
    required this.parameters,
  });

  @override
  ConsumerState<MobileEditorLayout> createState() => _MobileEditorLayoutState();
}

class _MobileEditorLayoutState extends ConsumerState<MobileEditorLayout> {
  bool _showEffectsSheet = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Slim top bar: back + export only
        Positioned(
          top: SlowverbTokens.spacingSm,
          left: SlowverbTokens.spacingSm,
          right: SlowverbTokens.spacingSm,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button
              _MiniChromeButton(icon: Icons.arrow_back, onTap: widget.onBack),
              // Export button
              _MiniChromeButton(
                icon: Icons.download,
                onTap: () =>
                    context.push(AppRoutes.export, extra: widget.projectId),
              ),
            ],
          ),
        ),

        // Floating mini transport bar at bottom
        Positioned(
          bottom: _showEffectsSheet ? 300 : SlowverbTokens.spacingMd,
          left: SlowverbTokens.spacingSm,
          right: SlowverbTokens.spacingSm,
          child: _MiniTransportBar(
            projectName: widget.projectName,
            position: widget.position,
            duration: widget.duration,
            isPlaying: widget.isPlaying,
            onPlayPause: widget.notifier.togglePlayback,
            onSeek: (pos) => widget.notifier.seek(
              widget.duration.inMilliseconds > 0
                  ? pos / widget.duration.inMilliseconds
                  : 0.0,
            ),
            onExpandEffects: () =>
                setState(() => _showEffectsSheet = !_showEffectsSheet),
            isEffectsExpanded: _showEffectsSheet,
            presetName: widget.presetName,
            masteringEnabled: widget.masteringEnabled,
          ),
        ),

        // Bottom sheet for effects (collapsed by default)
        if (_showEffectsSheet)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _MobileEffectsSheet(
              selectedPresetId: widget.selectedPresetId,
              parameters: widget.parameters,
              notifier: widget.notifier,
              onClose: () => setState(() => _showEffectsSheet = false),
            ),
          ),
      ],
    );
  }
}

/// Compact chrome button for mobile.
class _MiniChromeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniChromeButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Floating mini transport bar with slim progress and play/pause.
class _MiniTransportBar extends StatelessWidget {
  final String projectName;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final void Function(int) onSeek;
  final VoidCallback onExpandEffects;
  final bool isEffectsExpanded;
  final String presetName;
  final bool masteringEnabled;

  const _MiniTransportBar({
    required this.projectName,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeek,
    required this.onExpandEffects,
    required this.isEffectsExpanded,
    required this.presetName,
    required this.masteringEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(SlowverbTokens.spacingSm),
      decoration: BoxDecoration(
        color: SlowverbColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
        boxShadow: [SlowverbTokens.shadowCard],
        border: Border.all(color: SlowverbColors.surfaceVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title and time
          Row(
            children: [
              Expanded(
                child: Text(
                  projectName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SlowverbColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: SlowverbColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Slim progress bar
          GestureDetector(
            onTapDown: (details) {
              final width = context.size?.width ?? 1;
              final percent = details.localPosition.dx / width;
              onSeek((duration.inMilliseconds * percent).toInt());
            },
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: SlowverbColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [SlowverbColors.hotPink, SlowverbColors.neonCyan],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Controls row: effects toggle, play/pause, preset badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Effects toggle
              IconButton(
                onPressed: onExpandEffects,
                icon: Icon(
                  isEffectsExpanded ? Icons.expand_more : Icons.tune,
                  color: isEffectsExpanded
                      ? SlowverbColors.neonCyan
                      : SlowverbColors.textSecondary,
                ),
                iconSize: 22,
                visualDensity: VisualDensity.compact,
                tooltip: 'Effects',
              ),

              // Play/pause button
              Material(
                color: SlowverbColors.accentGradient.colors.first,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPlayPause,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),

              // Preset badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SlowverbColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(
                    SlowverbTokens.radiusPill,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      presetName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: SlowverbColors.hotPink,
                      ),
                    ),
                    if (masteringEnabled) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: SlowverbColors.neonCyan,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}

/// Bottom sheet for effect controls on mobile.
class _MobileEffectsSheet extends ConsumerWidget {
  final String selectedPresetId;
  final Map<String, double> parameters;
  final AudioEditorNotifier notifier;
  final VoidCallback onClose;

  const _MobileEffectsSheet({
    required this.selectedPresetId,
    required this.parameters,
    required this.notifier,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetId = selectedPresetId;
    final masteringSettings = ref.watch(masteringSettingsProvider);
    final masteringOn = masteringSettings.masteringEnabled;

    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SlowverbTokens.radiusLg),
        ),
        boxShadow: [SlowverbTokens.shadowCard],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: SlowverbColors.surfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Preset selector
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SlowverbTokens.spacingMd,
              vertical: SlowverbTokens.spacingSm,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: Presets.all.map((p) {
                  final isSelected = p.id == presetId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) notifier.applyPreset(p);
                      },
                      selectedColor: SlowverbColors.hotPink.withValues(
                        alpha: 0.3,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? SlowverbColors.hotPink : null,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SlowverbTokens.spacingMd,
              vertical: SlowverbTokens.spacingSm,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SlowverbColors.surfaceVariant,
                borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mastering',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Adds final peak safety + polish.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: SlowverbColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: masteringOn,
                        onChanged: (v) {
                          ref
                              .read(masteringSettingsProvider.notifier)
                              .setMasteringEnabled(v);
                        },
                        activeThumbColor: SlowverbColors.hotPink,
                        activeTrackColor: SlowverbColors.hotPink.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ],
                  ),
                  if (masteringOn) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Colors.white10),
                    const SizedBox(height: 8),
                    _CompactSlider(
                      label: 'Quality',
                      value: (parameters['masteringAlgorithm'] ?? 0.0).clamp(
                        0.0,
                        2.0,
                      ),
                      min: 0.0,
                      max: 2.0,
                      divisions: 2,
                      formatValue: (v) {
                        if (v < 0.5) return 'Simple';
                        if (v < 1.5) return 'Lite';
                        return 'Pro';
                      },
                      onChanged: (v) =>
                          notifier.updateParameter('masteringAlgorithm', v),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Higher quality = longer rendering times.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SlowverbColors.textSecondary.withValues(
                          alpha: 0.7,
                        ),
                        fontStyle: FontStyle.italic,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Parameter sliders (scrollable)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: SlowverbTokens.spacingMd,
                vertical: SlowverbTokens.spacingSm,
              ),
              children: [
                ...effectParameterDefinitions.map((param) {
                  final value = parameters[param.id] ?? param.defaultValue;
                  return _CompactSlider(
                    label: param.label,
                    value: value,
                    min: param.min,
                    max: param.max,
                    formatValue: (v) => _formatEffectValue(param.id, v),
                    onChanged: (v) => notifier.updateParameter(param.id, v),
                  );
                }),
                if (advancedReverbParameterDefinitions.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Advanced Reverb'),
                    children: advancedReverbParameterDefinitions
                        .map((param) {
                          final value =
                              parameters[param.id] ?? param.defaultValue;
                          return _CompactSlider(
                            label: param.label,
                            value: value,
                            min: param.min,
                            max: param.max,
                            formatValue: (v) =>
                                _formatEffectValue(param.id, v),
                            onChanged: (v) =>
                                notifier.updateParameter(param.id, v),
                          );
                        })
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact slider for mobile effects sheet.
class _CompactSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) formatValue;
  final ValueChanged<double> onChanged;

  const _CompactSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.formatValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SlowverbColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                activeColor: SlowverbColors.neonCyan,
                inactiveColor: SlowverbColors.surfaceVariant,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              formatValue(value),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: SlowverbColors.neonCyan),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatEffectValue(String paramId, double value) {
  switch (paramId) {
    case 'tempo':
      return '${(value * 100).toInt()}%';
    case 'pitch':
      return '${value.toStringAsFixed(1)} st';
    case 'preDelayMs':
      return '${value.toStringAsFixed(0)} ms';
    case 'stereoWidth':
      return '${value.toStringAsFixed(2)}x';
    default:
      return '${(value * 100).toInt()}%';
  }
}
