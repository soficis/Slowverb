import 'package:flutter/material.dart';
import 'package:slowverb_web/app/colors.dart';

class EffectSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final String Function(double)? formatValue;
  final ValueChanged<double> onChanged;

  const EffectSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    this.formatValue,
    required this.onChanged,
  });

  String _format(double v) =>
      formatValue != null ? formatValue!(v) : '${v.toStringAsFixed(1)}$unit';

  /// Parses typed input (tolerates a trailing unit/suffix) and clamps to range.
  /// Returns null when no number can be read.
  double? _parse(String raw) {
    final match = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(raw.trim());
    final parsed = match == null
        ? null
        : double.tryParse(match.group(0)!.replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite) return null;
    return parsed.clamp(min, max).toDouble();
  }

  Future<void> _editValue(BuildContext context) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _ValueDialog(
        label: label,
        hint: 'Value (${_format(min)} to ${_format(max)})',
        initial: value.clamp(min, max).toStringAsFixed(1),
        parse: _parse,
        invalidMessage: 'Enter a number between $min and $max',
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ExcludeSemantics(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SlowverbColors.textSecondary,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Type a value for $label',
              child: InkWell(
                onTap: () => _editValue(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ExcludeSemantics(
                    child: Text(
                      _format(value),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SlowverbColors.neonCyan,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: SlowverbColors.neonCyan,
            inactiveTrackColor: SlowverbColors.surfaceVariant,
            thumbColor: Colors.white,
            overlayColor: SlowverbColors.neonCyan.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: MergeSemantics(
            child: Semantics(
              label: label,
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                label: _format(value),
                semanticFormatterCallback: _format,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ValueDialog extends StatefulWidget {
  final String label;
  final String hint;
  final String initial;
  final double? Function(String) parse;
  final String invalidMessage;

  const _ValueDialog({
    required this.label,
    required this.hint,
    required this.initial,
    required this.parse,
    required this.invalidMessage,
  });

  @override
  State<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<_ValueDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = widget.parse(_controller.text);
    if (parsed == null) {
      setState(() => _error = widget.invalidMessage);
    } else {
      Navigator.of(context).pop(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(labelText: widget.hint, errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Set')),
      ],
    );
  }
}
