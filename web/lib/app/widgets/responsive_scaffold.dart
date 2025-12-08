import 'package:flutter/material.dart';
import 'package:slowverb_web/app/responsive_layout.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';

/// Scaffold that centers content with responsive padding and layered backgrounds.
class ResponsiveScaffold extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? background;

  const ResponsiveScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final size = ResponsiveLayout.of(context);
    return Scaffold(
      appBar: appBar,
      backgroundColor: Colors.transparent,
      body: _buildBody(context, size),
    );
  }

  Widget _buildBody(BuildContext context, ScreenSize size) {
    final maxWidth = ResponsiveLayout.maxContentWidth(size);
    final padding = ResponsiveLayout.contentPadding(size);

    return Container(
      decoration: const BoxDecoration(
        gradient: SlowverbTokens.backgroundGradient,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            if (background != null) Positioned.fill(child: background!),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
