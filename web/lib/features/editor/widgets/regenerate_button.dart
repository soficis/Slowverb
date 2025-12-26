import 'package:flutter/material.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';

/// Button to regenerate the audio preview with current settings.
///
/// Only visible after initial preview has been generated.
/// Includes a checkbox to resume playback at previous position.
class RegenerateButton extends StatefulWidget {
  final void Function(bool resumeAtPosition) onRegenerate;
  final bool isProcessing;

  const RegenerateButton({
    super.key,
    required this.onRegenerate,
    required this.isProcessing,
  });

  @override
  State<RegenerateButton> createState() => _RegenerateButtonState();
}

class _RegenerateButtonState extends State<RegenerateButton> {
  bool _resumeAtPosition = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRegenerateButton(),
        const SizedBox(height: 4),
        _buildResumeCheckbox(),
      ],
    );
  }

  Widget _buildRegenerateButton() {
    return Tooltip(
      message: 'Regenerate with current settings',
      child: ElevatedButton.icon(
        onPressed: widget.isProcessing
            ? null
            : () => widget.onRegenerate(_resumeAtPosition),
        style: ElevatedButton.styleFrom(
          backgroundColor: SlowverbColors.neonCyan.withValues(alpha: 0.2),
          foregroundColor: SlowverbColors.neonCyan,
          padding: const EdgeInsets.symmetric(
            horizontal: SlowverbTokens.spacingMd,
            vertical: SlowverbTokens.spacingSm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SlowverbTokens.radiusPill),
            side: BorderSide(
              color: SlowverbColors.neonCyan.withValues(alpha: 0.5),
            ),
          ),
        ),
        icon: widget.isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SlowverbColors.neonCyan,
                ),
              )
            : const Icon(Icons.refresh, size: 18),
        label: Text(widget.isProcessing ? 'Generating...' : 'Regenerate'),
      ),
    );
  }

  Widget _buildResumeCheckbox() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Checkbox(
            value: _resumeAtPosition,
            onChanged: widget.isProcessing
                ? null
                : (value) {
                    setState(() => _resumeAtPosition = value ?? false);
                  },
            activeColor: SlowverbColors.neonCyan,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Resume at position',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: SlowverbColors.textSecondary),
        ),
      ],
    );
  }
}
