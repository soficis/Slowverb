/// Building blocks for the Slowverb look: a dark Platinum-style desktop and
/// windows, holding hi-fi faceplates with VFD readouts and hardware keys.
///
/// Every widget here is a real control or container; nothing is decorative
/// chrome that pretends to do something it doesn't.
library;

import 'package:flutter/material.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

// ---------------------------------------------------------------------------
// Desktop
// ---------------------------------------------------------------------------

/// Sunset desktop: violet gradient, a low pink horizon glow and faint
/// scanlines. Static, so it is painted once behind a [RepaintBoundary].
class RetroDesktop extends StatelessWidget {
  final Widget child;
  const RetroDesktop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: CustomPaint(painter: _DesktopPainter())),
        child,
      ],
    );
  }
}

class _DesktopPainter extends CustomPainter {
  const _DesktopPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = SlowverbTokens.backgroundGradient.createShader(rect),
    );
    // Horizon glow, anchored to the bottom edge.
    final glow = RadialGradient(
      center: const Alignment(0, 1.25),
      radius: 1.1,
      colors: [
        SlowverbTokens.desktopGlow.withValues(alpha: 0.28),
        SlowverbTokens.desktopGlow.withValues(alpha: 0.0),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = glow.createShader(rect));
    // Scanlines every 3 px.
    final line = Paint()..color = Colors.black.withValues(alpha: 0.12);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Keeps an animated visualizer behind the UI from overpowering it: caps its
/// brightness and darkens it. Use around any full-bleed visual.
class VisualizerScrim extends StatelessWidget {
  final Widget child;

  /// 0 = invisible, 1 = untouched. 0.55 keeps bright visualizers well below
  /// the window text.
  final double strength;
  const VisualizerScrim({super.key, required this.child, this.strength = 0.55});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: strength,
      child: ColorFiltered(
        // Pull highlights down so a white-out scene reads as pale grey.
        colorFilter: const ColorFilter.matrix(<double>[
          0.8, 0, 0, 0, 0, //
          0, 0.8, 0, 0, 0, //
          0, 0, 0.85, 0, 0, //
          0, 0, 0, 1, 0, //
        ]),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Windows
// ---------------------------------------------------------------------------

/// A dark Platinum window: pinstriped title bar, 1 px black frame, bevel and
/// hard drop shadow. If [onCollapse] is given, the title bar gets a working
/// window-shade box that hides the body.
class RetroWindow extends StatelessWidget {
  final String title;
  final Widget child;
  final bool collapsed;
  final VoidCallback? onCollapse;
  final List<Widget> trailing;
  final EdgeInsetsGeometry padding;

  const RetroWindow({
    super.key,
    required this.title,
    required this.child,
    this.collapsed = false,
    this.onCollapse,
    this.trailing = const [],
    this.padding = const EdgeInsets.all(SlowverbTokens.spacingMd),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SlowverbTokens.windowBody,
        border: Border.fromBorderSide(
          BorderSide(color: SlowverbTokens.windowBorder),
        ),
        boxShadow: [SlowverbTokens.shadowWindow],
      ),
      child: Container(
        // Inner bevel: light top/left, dark bottom/right.
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: SlowverbTokens.windowHighlight),
            left: BorderSide(color: SlowverbTokens.windowHighlight),
            bottom: BorderSide(color: SlowverbTokens.windowShade),
            right: BorderSide(color: SlowverbTokens.windowShade),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(
              title: title,
              collapsed: collapsed,
              onCollapse: onCollapse,
              trailing: trailing,
            ),
            if (!collapsed) Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  final String title;
  final bool collapsed;
  final VoidCallback? onCollapse;
  final List<Widget> trailing;

  const _TitleBar({
    required this.title,
    required this.collapsed,
    required this.onCollapse,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: CustomPaint(
        painter: const _PinstripePainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              // Balance the shade box so the title stays centred.
              SizedBox(width: onCollapse != null ? 18 : 0),
              const Spacer(),
              Container(
                color: SlowverbTokens.windowBody,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: SlowverbTokens.fontDot,
                      fontSize: 13,
                      height: 1.2,
                      color: SlowverbTokens.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              ...trailing,
              if (onCollapse != null)
                _ShadeBox(collapsed: collapsed, onTap: onCollapse!),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinstripePainter extends CustomPainter {
  const _PinstripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = SlowverbTokens.titleStripeB,
    );
    final stripe = Paint()..color = SlowverbTokens.titleStripeA;
    for (double y = 5; y < size.height - 4; y += 2) {
      canvas.drawRect(Rect.fromLTWH(4, y, size.width - 8, 1), stripe);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = SlowverbTokens.windowBorder,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShadeBox extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onTap;
  const _ShadeBox({required this.collapsed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? 'Expand' : 'Collapse',
      child: Semantics(
        button: true,
        label: collapsed ? 'Expand window' : 'Collapse window',
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 16,
            height: 14,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: SlowverbTokens.windowBody,
              border: Border.all(color: SlowverbTokens.textHint),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 10,
              height: 1,
              color: SlowverbTokens.textHint,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Faceplate + VFD
// ---------------------------------------------------------------------------

/// Brushed hi-fi faceplate panel.
class Faceplate extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Faceplate({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SlowverbTokens.spacingMd),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: SlowverbTokens.faceplateGradient,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
        border: const Border(
          top: BorderSide(color: Color(0xFF45455A)),
          bottom: BorderSide(color: Colors.black),
          left: BorderSide(color: Color(0xFF303040)),
          right: BorderSide(color: Color(0xFF15151B)),
        ),
      ),
      child: child,
    );
  }
}

/// Smoked-glass display window for VFD readouts.
class VfdPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const VfdPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: SlowverbTokens.vfdGlass,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x33FFFFFF), offset: Offset(0, 1)),
        ],
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SlowverbTokens.vfdCyan.withValues(alpha: 0.06),
            SlowverbTokens.vfdGlass,
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Dot-matrix VFD text with phosphor glow.
class VfdText extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final int maxLines;
  const VfdText(
    this.text, {
    super.key,
    this.size = 14,
    this.color = SlowverbTokens.vfdCyan,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: SlowverbTokens.fontDot,
        fontSize: size,
        height: 1.25,
        color: color,
        letterSpacing: 0.5,
        shadows: SlowverbTokens.vfdGlow(color),
      ),
    );
  }
}

/// Seven-segment readout with ghosted unlit segments behind it, like a real
/// display. [value] may contain digits, '-', '.', ':' and spaces.
class SegmentReadout extends StatelessWidget {
  final String value;
  final double size;
  final Color color;
  final String? semanticsLabel;
  const SegmentReadout(
    this.value, {
    super.key,
    this.size = 28,
    this.color = SlowverbTokens.vfdCyan,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ghost = value.replaceAll(RegExp(r'[0-9\- ]'), '8');
    TextStyle style(Color c, {bool glow = false}) => TextStyle(
      fontFamily: SlowverbTokens.fontSeg7,
      fontSize: size,
      height: 1.1,
      color: c,
      shadows: glow ? SlowverbTokens.vfdGlow(c) : null,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      label: semanticsLabel ?? value,
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            Text(ghost, style: style(SlowverbTokens.vfdDim)),
            Text(value, style: style(color, glow: true)),
          ],
        ),
      ),
    );
  }
}

/// Small status lamp text that is lit or dim, e.g. "MASTER", "HQ".
class Annunciator extends StatelessWidget {
  final String label;
  final bool lit;
  final Color color;
  const Annunciator(
    this.label, {
    super.key,
    required this.lit,
    this.color = SlowverbTokens.vfdCyan,
  });

  @override
  Widget build(BuildContext context) {
    final c = lit ? color : SlowverbTokens.vfdDim;
    return Semantics(
      label: '$label ${lit ? 'on' : 'off'}',
      child: ExcludeSemantics(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: SlowverbTokens.fontDot,
            fontSize: 11,
            letterSpacing: 1,
            color: c,
            shadows: lit ? SlowverbTokens.vfdGlow(c) : null,
          ),
        ),
      ),
    );
  }
}

/// Engraved faceplate label: small, spaced caps.
class PlateLabel extends StatelessWidget {
  final String text;
  const PlateLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: SlowverbTokens.label,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

enum HwKeyStyle { normal, primary, danger }

/// A hardware key: bevelled, presses in, keyboard-focusable.
/// [isDefault] draws the thick outer ring the classic Mac used for the default
/// button. [lit] shows an LED-style lit state for toggle/selector keys.
class HwKey extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? label;
  final String? tooltip;
  final HwKeyStyle style;
  final bool isDefault;
  final bool lit;
  final double? size;
  final bool loading;

  const HwKey({
    super.key,
    required this.onPressed,
    this.icon,
    this.label,
    this.tooltip,
    this.style = HwKeyStyle.normal,
    this.isDefault = false,
    this.lit = false,
    this.size,
    this.loading = false,
  }) : assert(icon != null || label != null);

  @override
  State<HwKey> createState() => _HwKeyState();
}

class _HwKeyState extends State<HwKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final primary = widget.style == HwKeyStyle.primary;
    final danger = widget.style == HwKeyStyle.danger;
    final fg = !enabled
        ? SlowverbTokens.textHint.withValues(alpha: 0.6)
        : primary
        ? Colors.white
        : danger
        ? SlowverbTokens.error
        : widget.lit
        ? SlowverbTokens.vfdCyan
        : SlowverbTokens.textPrimary;

    final gradient = _down
        ? null
        : primary && enabled
        ? SlowverbTokens.primaryKeyGradient
        : SlowverbTokens.keyGradient;

    final square = widget.label == null && widget.size != null;
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: (widget.size ?? 40) * 0.4,
            height: (widget.size ?? 40) * 0.4,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: square ? widget.size! * 0.5 : 18, color: fg),
        if (widget.icon != null && widget.label != null)
          const SizedBox(width: 6),
        if (widget.label != null)
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: fg,
              shadows: widget.lit && enabled
                  ? SlowverbTokens.vfdGlow(SlowverbTokens.vfdCyan)
                  : null,
            ),
          ),
      ],
    );

    Widget key = AnimatedContainer(
      duration: _reduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 60),
      width: square ? widget.size : null,
      height: widget.size ?? 36,
      padding: square
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _down ? SlowverbTokens.keyPressed : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
        border: Border.all(
          color: widget.lit && enabled
              ? SlowverbTokens.vfdCyan.withValues(alpha: 0.7)
              : Colors.black,
        ),
        boxShadow: _down
            ? null
            : const [
                BoxShadow(color: Color(0x40FFFFFF), offset: Offset(0, -0.5)),
                BoxShadow(color: Color(0x99000000), offset: Offset(0, 2)),
              ],
      ),
      // widthFactor 1: size to the content instead of filling the row.
      child: Align(widthFactor: 1, child: content),
    );

    if (widget.isDefault) {
      key = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
          border: Border.all(color: SlowverbTokens.textSecondary, width: 2),
        ),
        child: key,
      );
    }

    final button = Semantics(
      button: true,
      enabled: enabled,
      toggled: widget.lit ? true : null,
      label: widget.label == null ? widget.tooltip : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? widget.onPressed : null,
          onHighlightChanged: (v) => setState(() => _down = v),
          borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
          splashFactory: NoSplash.splashFactory,
          focusColor: SlowverbTokens.vfdCyan.withValues(alpha: 0.18),
          child: key,
        ),
      ),
    );
    return widget.tooltip != null
        ? Tooltip(message: widget.tooltip, child: button)
        : button;
  }
}

// ---------------------------------------------------------------------------
// Popup select (classic popup-menu control)
// ---------------------------------------------------------------------------

class RetroOption<T> {
  final T value;
  final String label;
  final String? detail;

  /// Optional trailing action inside the menu row (e.g. delete).
  final Widget? trailing;
  const RetroOption(this.value, this.label, {this.detail, this.trailing});
}

/// A popup-menu selector: shows the current choice with a double-arrow, opens
/// a menu with a check mark next to the current item.
class RetroSelect<T> extends StatelessWidget {
  final String semanticLabel;
  final T value;
  final List<RetroOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? fallbackLabel;

  const RetroSelect({
    super.key,
    required this.semanticLabel,
    required this.value,
    required this.options,
    required this.onChanged,
    this.fallbackLabel,
  });

  @override
  Widget build(BuildContext context) {
    final current = options.where((o) => o.value == value).firstOrNull;
    return Semantics(
      label: semanticLabel,
      value: current?.label ?? fallbackLabel,
      button: true,
      child: PopupMenuButton<T>(
        tooltip: semanticLabel,
        onSelected: onChanged,
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
          for (final o in options)
            PopupMenuItem<T>(
              value: o.value,
              height: 36,
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: o.value == value
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: SlowverbTokens.vfdCyan,
                          )
                        : null,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(o.label),
                        if (o.detail != null)
                          Text(
                            o.detail!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: SlowverbTokens.textHint,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?o.trailing,
                ],
              ),
            ),
        ],
        child: ExcludeSemantics(
          child: Container(
            height: 36,
            padding: const EdgeInsets.only(left: 12, right: 6),
            decoration: BoxDecoration(
              gradient: SlowverbTokens.keyGradient,
              borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
              border: Border.all(color: Colors.black),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    current?.label ?? fallbackLabel ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: SlowverbTokens.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.unfold_more,
                  size: 18,
                  color: SlowverbTokens.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Disclosure triangle
// ---------------------------------------------------------------------------

/// Classic disclosure triangle section. Starts closed unless [initiallyOpen].
class RetroDisclosure extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyOpen;
  const RetroDisclosure({
    super.key,
    required this.title,
    required this.child,
    this.initiallyOpen = false,
  });

  @override
  State<RetroDisclosure> createState() => _RetroDisclosureState();
}

class _RetroDisclosureState extends State<RetroDisclosure> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final duration = _reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 150);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: duration,
                    child: const Icon(
                      Icons.play_arrow,
                      size: 16,
                      color: SlowverbTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  PlateLabel(widget.title),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: duration,
          alignment: Alignment.topCenter,
          child: _open ? widget.child : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Menu bar
// ---------------------------------------------------------------------------

/// Top-of-screen menu bar. [leading] sits at the far left (logo / back),
/// [menus] are menu titles, [trailing] sits at the right (status, actions).
class RetroMenuBar extends StatelessWidget {
  final Widget? leading;
  final List<Widget> menus;
  final List<Widget> trailing;
  const RetroMenuBar({
    super.key,
    this.leading,
    this.menus = const [],
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C2C38), Color(0xFF1F1F28)],
        ),
        border: Border(bottom: BorderSide(color: Colors.black)),
        boxShadow: [BoxShadow(color: Color(0x66000000), offset: Offset(0, 2))],
      ),
      child: Row(children: [?leading, ...menus, const Spacer(), ...trailing]),
    );
  }
}

/// A menu title in a [RetroMenuBar] that opens a dropdown of [items]
/// (MenuItemButton / SubmenuButton). Keyboard and screen-reader accessible
/// via [MenuAnchor].
class RetroMenu extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> items;
  const RetroMenu({
    super.key,
    required this.title,
    required this.items,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: items,
      builder: (context, controller, _) => TextButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
        label: Text(title),
        style: TextButton.styleFrom(
          foregroundColor: SlowverbTokens.textPrimary,
          backgroundColor: controller.isOpen
              ? SlowverbTokens.sunsetViolet.withValues(alpha: 0.35)
              : null,
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// The Slowverb wordmark for menu bars: dot-matrix, sunset pink.
class SlowverbWordmark extends StatelessWidget {
  final double size;
  const SlowverbWordmark({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Text(
      'SLOWVERB',
      semanticsLabel: 'Slowverb',
      style: TextStyle(
        fontFamily: SlowverbTokens.fontDot,
        fontSize: size,
        letterSpacing: size * 0.25,
        color: SlowverbTokens.sunsetPink,
        shadows: SlowverbTokens.vfdGlow(SlowverbTokens.sunsetPink),
      ),
    );
  }
}
