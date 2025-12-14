import 'package:flutter/material.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/responsive_layout.dart';

class ResponsiveScaffold extends StatelessWidget {
  final Widget child;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;

  const ResponsiveScaffold({
    super.key,
    required this.child,
    this.floatingActionButton,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    final size = ResponsiveLayout.of(context);
    final maxContentWidth = ResponsiveLayout.maxContentWidth(size);

    return Scaffold(
      appBar: appBar,
      backgroundColor: SlowverbColors.backgroundDark,
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
