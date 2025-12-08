import 'package:flutter/material.dart';
import 'package:slowverb/app/responsive_layout.dart';
import 'package:slowverb/app/slowverb_design_tokens.dart';
import 'package:slowverb/app/widgets/vaporwave_widgets.dart';

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbTokens.backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const GridPattern(),
              const ScanLines(),
              if (background != null) Positioned.fill(child: background!),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: ResponsiveLayout.maxContentWidth(size),
                  ),
                  child: Padding(
                    padding: ResponsiveLayout.contentPadding(size),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
